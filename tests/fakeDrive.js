/**
 * A small in-memory imitation of the Google Drive v3 REST API — just the parts SPECACT uses —
 * including users, permission inheritance, sharedWithMe, `properties has` queries and multipart uploads.
 */
const FOLDER = 'application/vnd.google-apps.folder';

// byte <-> binary-string helpers that behave the same in Node and in a browser (no Buffer)
const toBinary = (u8) => { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000)); return s; };
const fromBinary = (s) => { const u8 = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u8[i] = s.charCodeAt(i) & 0xff; return u8; };

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
const err = (status, reason, message) => json(status, { error: { code: status, message: message || reason, status: reason, errors: [{ reason }] } });

function splitAnd(q) {
  const parts = [];
  let cur = '';
  let quote = false;
  let depth = 0;
  for (let i = 0; i < q.length; i++) {
    const c = q[i];
    if (c === '\\' && quote) { cur += c + q[++i]; continue; }
    if (c === "'") quote = !quote;
    if (!quote && c === '{') depth++;
    if (!quote && c === '}') depth--;
    if (!quote && depth === 0 && /^\s+and\s+/.test(q.slice(i))) {
      parts.push(cur.trim());
      i += q.slice(i).match(/^\s+and\s+/)[0].length - 1;
      cur = '';
      continue;
    }
    cur += c;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}
const unq = (s) => s.replace(/^'|'$/g, '').replace(/\\(.)/g, '$1');

export class FakeDrive {
  constructor() {
    this.files = new Map();
    this.n = 0;
    this.users = new Map(); // token -> { email, name }
    this.log = [];
    this.forbidWrites = false;
  }

  addUser(email, name) {
    const token = `tok-${email}`;
    this.users.set(token, { email, name: name || email.split('@')[0] });
    const rootId = `root:${email}`;
    this.files.set(rootId, this.#blank({ id: rootId, name: 'My Drive', mimeType: FOLDER, owner: email, parents: [] }));
    return token;
  }

  #id() { return `f${++this.n}`; }
  #blank(o) {
    const now = new Date(Date.now() + this.n).toISOString();
    return { properties: {}, content: null, trashed: false, createdTime: now, modifiedTime: now, version: 1, perms: new Map(), parents: [], ...o };
  }

  #role(file, user) {
    if (file.owner === user.email) return 'owner';
    const rank = { reader: 1, commenter: 2, writer: 3, owner: 4 };
    let best = null;
    const consider = (f) => {
      for (const p of f.perms.values()) {
        if ((p.type === 'user' && p.email === user.email) || p.type === 'anyone') if (!best || rank[p.role] > rank[best]) best = p.role;
      }
    };
    let f = file;
    const seen = new Set();
    while (f && !seen.has(f.id)) { seen.add(f.id); consider(f); f = this.files.get(f.parents[0]); }
    return best;
  }

  #effectivePerms(file) {
    const out = new Map();
    const rank = { reader: 1, commenter: 2, writer: 3, owner: 4 };
    let f = file;
    const seen = new Set();
    while (f && !seen.has(f.id)) {
      seen.add(f.id);
      for (const p of f.perms.values()) {
        const k = p.type === 'anyone' ? 'anyone' : p.email;
        if (!out.has(k) || rank[p.role] > rank[out.get(k).role]) out.set(k, { ...p, inherited: f !== file });
      }
      f = this.files.get(f.parents[0]);
    }
    const owner = this.users && [...this.users.values()].find((u) => u.email === file.owner);
    out.set(file.owner, { id: `perm-${file.owner}`, type: 'user', role: 'owner', email: file.owner, name: owner?.name });
    return out;
  }

  #view(file, user) {
    const o = this.users && [...this.users.values()].find((u) => u.email === file.owner);
    return {
      id: file.id, name: file.name, mimeType: file.mimeType, properties: { ...file.properties }, trashed: file.trashed,
      createdTime: file.createdTime, modifiedTime: file.modifiedTime, version: String(file.version),
      parents: file.parents.filter((p) => !p.startsWith('root:')),
      owners: [{ emailAddress: file.owner, displayName: o?.name || file.owner }],
      shortcutDetails: file.shortcutDetails,
      capabilities: { canEdit: ['writer', 'owner'].includes(this.#role(file, user)) },
    };
  }

  #match(file, user, terms) {
    const role = this.#role(file, user);
    if (!role) return false;
    for (const t of terms) {
      let m;
      if ((m = /^('(?:\\.|[^'])*')\s+in\s+parents$/.exec(t))) {
        let pid = unq(m[1]);
        if (pid === 'root') pid = `root:${user.email}`;
        if (!file.parents.includes(pid)) return false;
      } else if ((m = /^name\s*=\s*('(?:\\.|[^'])*')$/.exec(t))) { if (file.name !== unq(m[1])) return false; }
      else if ((m = /^mimeType\s*=\s*('(?:\\.|[^'])*')$/.exec(t))) { if (file.mimeType !== unq(m[1])) return false; }
      else if (/^trashed\s*=\s*false$/.test(t)) { if (file.trashed) return false; }
      else if (/^sharedWithMe\s*=\s*true$/.test(t)) {
        if (file.owner === user.email) return false;
        const direct = [...file.perms.values()].some((p) => p.type === 'user' && p.email === user.email);
        if (!direct) return false;
      } else if ((m = /^properties\s+has\s*\{\s*key='([^']*)'\s+and\s+value='([^']*)'\s*\}$/.exec(t))) { if (file.properties[m[1]] !== m[2]) return false; }
      else throw new Error(`FakeDrive: unsupported query term: ${t}`);
    }
    return true;
  }

  async #parseMultipart(req) {
    const ct = req.headers['content-type'];
    const boundary = /boundary=(.+)$/.exec(ct)[1];
    const text = toBinary(new Uint8Array(await req.body.arrayBuffer()));
    const parts = text.split(`--${boundary}`).slice(1, -1);
    const [metaPart, dataPart] = parts;
    const meta = JSON.parse(new TextDecoder().decode(fromBinary(metaPart.split('\r\n\r\n')[1].replace(/\r\n$/, ''))));
    const head = dataPart.indexOf('\r\n\r\n');
    return { meta, data: fromBinary(dataPart.slice(head + 4).replace(/\r\n$/, '')) };
  }

  fetch = async (url, init = {}) => {
    const u = new URL(url);
    const method = (init.method || 'GET').toUpperCase();
    const headers = Object.fromEntries(Object.entries(init.headers || {}).map(([k, v]) => [k.toLowerCase(), v]));
    this.log.push(`${method} ${u.pathname}${u.search.includes('alt=media') ? '?alt=media' : ''}`);
    const user = this.users.get((headers.authorization || '').replace('Bearer ', ''));
    if (!user) return err(401, 'authError', 'Invalid Credentials');
    const path = u.pathname;
    let m;

    if (path === '/drive/v3/about') return json(200, { user: { displayName: user.name, emailAddress: user.email }, storageQuota: { usage: '1048576', limit: '16106127360' } });

    if (path === '/drive/v3/files' && method === 'GET') {
      const terms = splitAnd(u.searchParams.get('q') || '');
      const list = [...this.files.values()].filter((f) => !f.id.startsWith('root:') && this.#match(f, user, terms)).map((f) => this.#view(f, user));
      return json(200, { files: list });
    }
    if (path === '/drive/v3/files' && method === 'POST') {
      const body = JSON.parse(init.body);
      const parent = body.parents?.[0] === 'root' || !body.parents ? `root:${user.email}` : body.parents[0];
      const pf = this.files.get(parent);
      if (!pf || !['owner', 'writer'].includes(this.#role(pf, user))) return err(403, 'insufficientFilePermissions');
      const f = this.#blank({ id: this.#id(), name: body.name, mimeType: body.mimeType, owner: user.email, parents: [parent], properties: body.properties || {}, shortcutDetails: body.shortcutDetails });
      this.files.set(f.id, f);
      return json(200, this.#view(f, user));
    }
    if (path === '/upload/drive/v3/files' && method === 'POST') {
      const { meta, data } = await this.#parseMultipart({ headers, body: init.body });
      const parent = meta.parents?.[0] || `root:${user.email}`;
      const pf = this.files.get(parent);
      if (!pf || !['owner', 'writer'].includes(this.#role(pf, user))) return err(403, 'insufficientFilePermissions');
      const f = this.#blank({ id: this.#id(), name: meta.name, mimeType: meta.mimeType || 'application/octet-stream', owner: user.email, parents: [parent], content: data, properties: meta.properties || {} });
      this.files.set(f.id, f);
      return json(200, this.#view(f, user));
    }
    if ((m = /^\/upload\/drive\/v3\/files\/([^/]+)$/.exec(path)) && method === 'PATCH') {
      const f = this.files.get(decodeURIComponent(m[1]));
      if (!f) return err(404, 'notFound');
      if (!['owner', 'writer'].includes(this.#role(f, user)) || this.forbidWrites) return err(403, 'insufficientFilePermissions');
      const b = init.body;
      f.content = typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(await new Response(b).arrayBuffer());
      f.version++; f.modifiedTime = new Date(Date.now() + ++this.n).toISOString();
      return json(200, this.#view(f, user));
    }
    if ((m = /^\/drive\/v3\/files\/([^/]+)$/.exec(path))) {
      const f = this.files.get(decodeURIComponent(m[1]));
      if (!f || (!this.#role(f, user))) return err(f ? 403 : 404, f ? 'forbidden' : 'notFound');
      if (method === 'GET') {
        if (u.searchParams.get('alt') === 'media') return new Response(f.content, { status: 200, headers: { 'Content-Type': f.mimeType } });
        return json(200, this.#view(f, user));
      }
      if (method === 'PATCH') {
        if (!['owner', 'writer'].includes(this.#role(f, user))) return err(403, 'insufficientFilePermissions');
        const body = JSON.parse(init.body);
        if (body.properties) f.properties = { ...f.properties, ...body.properties };
        if (body.name) f.name = body.name;
        if (body.trashed !== undefined) f.trashed = body.trashed;
        f.modifiedTime = new Date(Date.now() + ++this.n).toISOString();
        return json(200, this.#view(f, user));
      }
      if (method === 'DELETE') {
        if (f.owner !== user.email) return err(403, 'forbidden');
        const drop = (id) => { for (const x of [...this.files.values()]) if (x.parents.includes(id)) drop(x.id); this.files.delete(id); };
        drop(f.id);
        return new Response(null, { status: 204 });
      }
    }
    if ((m = /^\/drive\/v3\/files\/([^/]+)\/permissions(?:\/([^/]+))?$/.exec(path))) {
      const f = this.files.get(decodeURIComponent(m[1]));
      if (!f) return err(404, 'notFound');
      const role = this.#role(f, user);
      if (method === 'GET') {
        if (!role) return err(403, 'forbidden');
        return json(200, { permissions: [...this.#effectivePerms(f).values()].map((p) => ({ id: p.id, type: p.type, role: p.role, emailAddress: p.email, displayName: p.name })) });
      }
      if (f.owner !== user.email) return err(403, 'insufficientFilePermissions');
      if (method === 'POST') {
        const body = JSON.parse(init.body);
        if (body.type === 'user' && !/@/.test(body.emailAddress || '')) return err(400, 'invalid');
        const id = `perm-${this.#id()}`;
        const email = body.emailAddress?.toLowerCase();
        const p = { id, type: body.type, role: body.role, email };
        // like Drive: a direct permission for the same user is replaced
        for (const [k, v] of f.perms) if (v.type === p.type && v.email === p.email) f.perms.delete(k);
        f.perms.set(id, p);
        this.lastShare = { fileId: f.id, notify: u.searchParams.get('sendNotificationEmail') };
        return json(200, { id, type: p.type, role: p.role, emailAddress: email });
      }
      const pid = decodeURIComponent(m[2] || '');
      if (method === 'PATCH') {
        const eff = [...this.#effectivePerms(f).values()].find((p) => p.id === pid);
        if (!eff) return err(404, 'notFound');
        if (eff.inherited) return err(403, 'cannotModifyInheritedPermission');
        f.perms.get(pid).role = JSON.parse(init.body).role;
        return json(200, { id: pid, role: f.perms.get(pid).role });
      }
      if (method === 'DELETE') {
        if (!f.perms.has(pid)) return err([...this.#effectivePerms(f).values()].some((p) => p.id === pid) ? 403 : 404, 'cannotDeleteInheritedPermission');
        f.perms.delete(pid);
        return new Response(null, { status: 204 });
      }
    }
    return err(404, 'notFound', `FakeDrive: no route for ${method} ${path}`);
  };

  /* test helpers */
  find(pred) { return [...this.files.values()].filter(pred); }
  text(file) { return file.content ? new TextDecoder().decode(file.content) : ''; }
  allBytesContain(needle) {
    return [...this.files.values()].some((f) => (f.content && toBinary(f.content).includes(toBinary(new TextEncoder().encode(needle)))) || f.name.includes(needle));
  }
}
