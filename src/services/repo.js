/**
 * DriveRepo — the domain layer. Turns "posts, comments, sharing" into Drive folders, files and permissions.
 * See postModel.js for the on-disk layout.
 *
 * Access control is Google's: whoever has no Drive permission on a post folder cannot read it, period.
 * Password protection adds a client-side encryption layer on top (even a leaked Drive link stays unreadable).
 */
import { config } from '../config';
import { b64d, b64e, createProtection, decryptBytes, decryptJson, encryptBytes, encryptJson, importRawKey, randomId, rewrapProtection, unlockProtection } from './crypto';
import { DriveError, MIME_FOLDER, qs } from './drive';
import { normEmail, extractMentions, prettyName } from './mentions';
import { ROLE_COMMENT, ROLE_VIEW, buildPostDoc, byNewest, cleanAudience, emptyIndex, folderNameFor, openPostDoc, toEntry } from './postModel';
import { prepareImage } from './image';
import { debounce, mapLimit } from './util';

export class RepoError extends Error {
  constructor(code, extra = {}) { super(code); this.name = 'RepoError'; this.code = code; Object.assign(this, extra); }
}

const FOLDER_FIELDS = 'id,name,createdTime,modifiedTime,trashed,properties,owners(emailAddress,displayName)';
const isPostFolder = (f) => f?.properties?.specact === 'post';
const stable = (idx) => JSON.stringify({ ...idx, updatedAt: 0, syncedAt: 0 });

export class DriveRepo {
  /**
   * @param {{ drive: import('./drive').DriveClient, me: {email:string,name:string}, vault: any }} deps
   */
  constructor({ drive, me, vault }) {
    this.drive = drive;
    this.vault = vault;
    this.me = { email: normEmail(me.email), name: me.name || prettyName(me.email) };
    this.layout = null;
    this.index = null;
    this.contacts = null;
    this.keys = new Map(); // folderId -> CryptoKey for unlocked protected posts
    this.rawKeys = null; // folderId -> b64 raw key persisted for posts I own
    this.blobs = new Map(); // fileId -> object URL
    this.inflight = new Map();
    this.remoteIndexJson = '';
    this.pushIndex = debounce(() => this.#pushIndex().catch(() => {}), 1500);
  }

  /* ================= layout ================= */
  async ensureLayout() {
    if (this.layout) return this.layout;
    const d = this.drive;
    const root = await this.#findOrCreateFolder(config.rootFolder, 'root', { specact: 'root', v: '1' });
    const posts = await this.#findOrCreateFolder(config.postsFolder, root.id, { specact: 'posts', v: '1' });
    const [indexFile, contactsFile] = await Promise.all([this.#findChild(root.id, 'index.json'), this.#findChild(root.id, 'contacts.json')]);
    this.layout = { rootId: root.id, postsId: posts.id, indexId: indexFile?.id || null, contactsId: contactsFile?.id || null };
    void d;
    return this.layout;
  }

  async #findOrCreateFolder(name, parentId, properties) {
    const found = await this.drive.list({
      q: `name = ${qs(name)} and ${qs(parentId)} in parents and mimeType = ${qs(MIME_FOLDER)} and trashed = false`,
      fields: 'id,name,properties,createdTime', orderBy: 'createdTime', pageSize: 10,
    });
    const hit = found.find((f) => f.properties?.specact) || found[0];
    if (hit) {
      if (!hit.properties?.specact) await this.drive.updateMeta(hit.id, { properties });
      return hit;
    }
    return this.drive.createFolder(name, parentId, properties);
  }

  async #findChild(parentId, name) {
    const r = await this.drive.list({ q: `name = ${qs(name)} and ${qs(parentId)} in parents and trashed = false`, fields: 'id,name,modifiedTime', pageSize: 5 });
    return r[0] || null;
  }

  /* ================= index (fast "what's new" document) ================= */
  async loadIndex() {
    if (this.index) return this.index;
    let idx = await this.vault.get(`index:${this.me.email}`);
    if (!idx || idx.v !== 1) {
      idx = null;
      try {
        const L = await this.ensureLayout();
        if (L.indexId) {
          idx = await this.drive.downloadJson(L.indexId);
          this.remoteIndexJson = stable(idx);
        }
      } catch { idx = null; }
    }
    this.index = idx && idx.v === 1 ? idx : emptyIndex(this.me.email);
    return this.index;
  }

  async #saveLocalIndex() {
    this.index.updatedAt = Date.now();
    await this.vault.set(`index:${this.me.email}`, this.index);
  }

  async #pushIndex() {
    const L = await this.ensureLayout();
    const json = stable(this.index);
    if (json === this.remoteIndexJson) return;
    if (L.indexId) await this.drive.updateContent(L.indexId, JSON.stringify(this.index));
    else L.indexId = (await this.drive.createJson('index.json', L.rootId, this.index)).id;
    this.remoteIndexJson = json;
  }

  async #commitIndex() {
    await this.#saveLocalIndex();
    this.pushIndex();
  }

  /**
   * Refresh the index. Only folder *metadata* is listed (one request per ~200 posts); post.json is
   * downloaded solely for posts whose `rev` changed since the last sync.
   */
  async syncIndex() {
    const L = await this.ensureLayout();
    const idx = await this.loadIndex();
    const [mineFolders, sharedFolders] = await Promise.all([
      this.drive.list({ q: `${qs(L.postsId)} in parents and mimeType = ${qs(MIME_FOLDER)} and trashed = false`, fields: FOLDER_FIELDS }),
      this.drive.list({ q: `sharedWithMe = true and mimeType = ${qs(MIME_FOLDER)} and trashed = false and properties has { key='specact' and value='post' }`, fields: FOLDER_FIELDS }),
    ]);
    const mine = await this.#reconcile(idx.mine, mineFolders.filter(isPostFolder));
    const sharedIds = new Set(sharedFolders.map((f) => f.id));
    const shared = await this.#reconcile(idx.shared, sharedFolders.filter(isPostFolder));
    // posts opened through a link are not in "shared with me"; keep them for as long as they still resolve
    const links = idx.shared.filter((e) => e.via === 'link' && !sharedIds.has(e.id));
    const alive = await mapLimit(links, 4, async (e) => {
      try { const m = await this.drive.get(e.id, 'id,trashed'); return m.trashed ? null : e; } catch (err) { return err instanceof DriveError && (err.notFound || err.forbidden) ? null : e; }
    });
    shared.push(...alive.filter(Boolean));
    idx.mine = mine.sort(byNewest);
    idx.shared = shared.sort(byNewest);
    idx.syncedAt = Date.now();
    await this.#saveLocalIndex();
    this.pushIndex();
    return idx;
  }

  async #reconcile(existing, folders) {
    const byId = new Map(existing.map((e) => [e.id, e]));
    const keep = [];
    const todo = [];
    for (const f of folders) {
      const old = byId.get(f.id);
      const rev = f.properties?.rev || f.modifiedTime;
      if (old && String(old.rev) === String(rev)) keep.push(old);
      else todo.push(f);
    }
    const fresh = await mapLimit(todo, 4, async (f) => {
      try {
        return await this.#entryFromFolder(f);
      } catch (e) {
        if (e instanceof DriveError && (e.notFound || e.forbidden)) return null; // lost access meanwhile
        return byId.get(f.id) || null; // transient trouble: keep what we know
      }
    });
    return [...keep, ...fresh.filter(Boolean)];
  }

  async #entryFromFolder(f) {
    const ids = await this.#idsOf(f);
    const doc = await this.drive.downloadJson(ids.pj);
    const post = await openPostDoc(doc, this.#keyFor(f.id));
    if (!post.owner.email) post.owner.email = normEmail(f.owners?.[0]?.emailAddress);
    if (!post.owner.name) post.owner.name = f.owners?.[0]?.displayName || prettyName(post.owner.email);
    return toEntry(post, { id: f.id, ids, rev: f.properties?.rev || f.modifiedTime });
  }

  async #idsOf(f) {
    const p = f.properties || {};
    if (p.pj && p.cj) return { pj: p.pj, cj: p.cj, mf: p.mf || null };
    const kids = await this.drive.list({ q: `${qs(f.id)} in parents and trashed = false`, fields: 'id,name,mimeType' });
    const find = (n) => kids.find((k) => k.name === n)?.id || null;
    const pj = find('post.json');
    if (!pj) throw new RepoError('not-a-post');
    return { pj, cj: find('comments.json'), mf: find('media') };
  }

  #upsertEntry(entry, { link = false } = {}) {
    const idx = this.index;
    const list = entry.owner.email === this.me.email ? idx.mine : idx.shared;
    const i = list.findIndex((e) => e.id === entry.id);
    if (link && i < 0) entry.via = 'link';
    if (i >= 0) { if (list[i].via) entry.via = list[i].via; list[i] = entry; } else list.push(entry);
    list.sort(byNewest);
  }

  /* ================= contacts ================= */
  async loadContacts() {
    if (this.contacts) return this.contacts;
    let doc = await this.vault.get(`contacts:${this.me.email}`);
    if (!doc) {
      try {
        const L = await this.ensureLayout();
        if (L.contactsId) doc = await this.drive.downloadJson(L.contactsId);
      } catch { /* offline: start empty */ }
    }
    this.contacts = Array.isArray(doc?.contacts) ? doc.contacts : [];
    return this.contacts;
  }

  async refreshContacts() {
    const L = await this.ensureLayout();
    if (!L.contactsId) return this.loadContacts();
    const doc = await this.drive.downloadJson(L.contactsId);
    this.contacts = Array.isArray(doc?.contacts) ? doc.contacts : [];
    await this.vault.set(`contacts:${this.me.email}`, { contacts: this.contacts });
    return this.contacts;
  }

  async saveContacts(list) {
    this.contacts = list;
    await this.vault.set(`contacts:${this.me.email}`, { contacts: list });
    const L = await this.ensureLayout();
    const doc = { v: 1, contacts: list };
    if (L.contactsId) await this.drive.updateJson(L.contactsId, doc);
    else L.contactsId = (await this.drive.createJson('contacts.json', L.rootId, doc)).id;
  }

  /* ================= keys ================= */
  async #loadRawKeys() {
    if (!this.rawKeys) this.rawKeys = (await this.vault.get(`postkeys:${this.me.email}`)) || {};
    return this.rawKeys;
  }
  #keyFor(folderId) { return this.keys.get(folderId) || null; }
  hasKey(folderId) { return this.keys.has(folderId); }

  async #rememberKey(folderId, raw, persist) {
    this.keys.set(folderId, await importRawKey(raw));
    if (persist) {
      const store = await this.#loadRawKeys();
      store[folderId] = b64e(raw);
      await this.vault.set(`postkeys:${this.me.email}`, store);
    }
  }

  /** Make keys of my own protected posts (and ones I chose to remember) usable after unlocking the app. */
  async restoreKeys() {
    const store = await this.#loadRawKeys();
    for (const [id, b64] of Object.entries(store)) { try { this.keys.set(id, await importRawKey(b64d(b64))); } catch { /* ignore */ } }
  }

  async unlockPost(folderId, doc, password, { remember = false } = {}) {
    if (!doc?.protection) return;
    const { raw } = await unlockProtection(doc.protection, password).catch((e) => { throw new RepoError(e.code === 'wrong-password' ? 'wrong-password' : 'crypto', {}); });
    await this.#rememberKey(folderId, raw, remember);
  }

  /* ================= reading a post ================= */
  /** Open one post (full content). `id` is the Drive folder id. */
  async openPost(id) {
    let meta;
    try { meta = await this.drive.get(id, FOLDER_FIELDS); } catch (e) { throw this.#mapErr(e); }
    if (meta.trashed) throw new RepoError('not-found');
    if (!isPostFolder(meta)) throw new RepoError('not-a-post');
    const ids = await this.#idsOf(meta);
    let doc;
    try { doc = await this.drive.downloadJson(ids.pj); } catch (e) { throw this.#mapErr(e); }
    const post = await openPostDoc(doc, this.#keyFor(id));
    const ownerEmail = post.owner.email || normEmail(meta.owners?.[0]?.emailAddress);
    post.owner = { email: ownerEmail, name: post.owner.name || meta.owners?.[0]?.displayName || prettyName(ownerEmail) };
    const mine = ownerEmail === this.me.email;
    let role = 'owner';
    if (!mine) {
      role = ROLE_VIEW;
      if (ids.cj) { try { const c = await this.drive.get(ids.cj, 'capabilities(canEdit)'); if (c.capabilities?.canEdit) role = ROLE_COMMENT; } catch { /* view only */ } }
    }
    const full = { ...post, id, mine, role, ids, doc, rev: meta.properties?.rev || String(post.updatedAt) };
    await this.loadIndex();
    this.#upsertEntry(toEntry(post, { id, ids, rev: full.rev }), { link: !mine });
    this.#commitIndex().catch(() => {});
    return full;
  }

  /** Unlock a protected post with its password and return it with the content opened. */
  async unlockAndOpen(id, password, opts) {
    const first = await this.openPost(id);
    if (!first.protected) return first;
    await this.unlockPost(id, first.doc, password, { ...opts, remember: !!(opts?.remember || first.mine) });
    const opened = await openPostDoc(first.doc, this.#keyFor(id));
    return { ...first, ...opened, owner: first.owner };
  }

  #mapErr(e) {
    if (e instanceof RepoError) return e;
    if (e instanceof DriveError) {
      if (e.notFound) return new RepoError('not-found');
      if (e.forbidden) return new RepoError('forbidden');
      if (e.status === 0) return new RepoError('offline');
    }
    return e;
  }

  /* ================= media ================= */
  async #uploadImage(file, mediaFolderId, key, pid) {
    const img = await prepareImage(file);
    const base = randomId(5);
    const put = async (blob, stem) => {
      if (!key) return this.drive.createFile({ name: `${stem}.jpg`, parentId: mediaFolderId, mimeType: 'image/jpeg', data: blob });
      // Protected posts: bytes are sealed before upload and carry an opaque name.
      const sealed = await encryptBytes(key, new Uint8Array(await blob.arrayBuffer()), `media:${pid}`);
      return this.drive.createFile({ name: `${stem}.bin`, parentId: mediaFolderId, mimeType: 'application/octet-stream', data: sealed });
    };
    const stem = key ? base : `${base}_${img.name.replace(/\.jpg$/, '')}`;
    const main = await put(img.main.blob, stem);
    const thumb = await put(img.thumb.blob, `${base}_t`);
    return { id: main.id, thumb: thumb.id, name: img.name, mime: 'image/jpeg', w: img.main.w, h: img.main.h, size: img.main.blob.size };
  }

  /** Object URL for a media file (decrypted when the post is protected). */
  async mediaUrl(post, item, { thumb = false } = {}) {
    const fileId = thumb ? (item.thumb || item.id) : item.id;
    if (this.blobs.has(fileId)) return this.blobs.get(fileId);
    if (this.inflight.has(fileId)) return this.inflight.get(fileId);
    const job = (async () => {
      let bytes = await this.drive.downloadBytes(fileId);
      if (post?.protected) {
        const key = this.#keyFor(post.id);
        if (!key) throw new RepoError('locked');
        bytes = await decryptBytes(key, bytes, `media:${post.pid}`);
      }
      const url = URL.createObjectURL(new Blob([bytes], { type: item.mime || 'image/jpeg' }));
      this.blobs.set(fileId, url);
      this.#trimBlobs();
      return url;
    })().finally(() => this.inflight.delete(fileId));
    this.inflight.set(fileId, job);
    return job;
  }

  #trimBlobs(max = 220) {
    while (this.blobs.size > max) {
      const [oldest, url] = this.blobs.entries().next().value;
      URL.revokeObjectURL(url);
      this.blobs.delete(oldest);
    }
  }

  /* ================= create / update / delete ================= */
  /**
   * @param {{ text:string, files:File[], audience:Record<string,'view'|'comment'>, password?:string, linkShare?:boolean }} input
   */
  async createPost(input, onProgress = () => {}) {
    const L = await this.ensureLayout();
    const files = input.files || [];
    if (files.length > config.maxImagesPerPost) throw new RepoError('too-many-images');
    const id = randomId(5);
    const createdAt = Date.now();
    const prot = input.password ? await createProtection(input.password, config.postKdfIterations) : null;
    const text = input.text || '';
    const mentions = extractMentions(text);
    const audience = cleanAudience(input.audience, this.me.email);

    onProgress({ stage: 'prepare' });
    const folder = await this.drive.createFolder(folderNameFor(createdAt, id), L.postsId, { specact: 'post', v: '1', rev: String(createdAt) });
    const warnings = [];
    try {
      const mf = await this.drive.createFolder('media', folder.id);
      const media = [];
      for (let i = 0; i < files.length; i++) {
        onProgress({ stage: 'upload', done: i, total: files.length });
        media.push(await this.#uploadImage(files[i], mf.id, prot?.key, id));
      }
      onProgress({ stage: 'save', done: files.length, total: files.length });
      const cj = await this.drive.createJson('comments.json', folder.id, { v: 1, comments: [], likes: [] });
      const doc = await buildPostDoc({
        id, owner: this.me, createdAt, updatedAt: createdAt, text, media, mentions, audience,
        linkShare: !!(input.linkShare && prot), protection: prot?.protection || null, key: prot?.key,
      });
      const pj = await this.drive.createJson('post.json', folder.id, doc);
      await this.drive.updateMeta(folder.id, { properties: { specact: 'post', v: '1', rev: String(createdAt), pj: pj.id, cj: cj.id, mf: mf.id } });
      const ids = { pj: pj.id, cj: cj.id, mf: mf.id };

      // Nothing is shared until the content is complete.
      onProgress({ stage: 'share' });
      for (const [email, role] of Object.entries(audience)) {
        try { await this.#grant(folder.id, cj.id, email, role); } catch (e) { warnings.push({ email, error: e }); delete doc.audience[email]; }
      }
      if (doc.linkShare) {
        try { await this.drive.addPermission(folder.id, { type: 'anyone', role: 'reader' }); } catch (e) { doc.linkShare = false; warnings.push({ email: '*', error: e }); }
      }
      if (warnings.length) await this.drive.updateJson(pj.id, doc);
      if (prot) await this.#rememberKey(folder.id, prot.raw, true);

      await this.loadIndex();
      const post = await openPostDoc(doc, prot?.key);
      this.#upsertEntry(toEntry(post, { id: folder.id, ids, rev: createdAt }));
      await this.#commitIndex();
      return { post: { ...post, id: folder.id, mine: true, role: 'owner', ids, doc, rev: String(createdAt) }, warnings };
    } catch (e) {
      try { await this.drive.trash(folder.id); } catch { /* best effort rollback */ }
      throw this.#mapErr(e);
    }
  }

  /**
   * @param {object} post an opened post (mine, unlocked)
   * @param {{ text:string, keepMedia:string[], files:File[], audience:Record<string,string>, newPassword?:string, linkShare?:boolean }} input
   */
  async updatePost(post, input, onProgress = () => {}) {
    if (!post.mine) throw new RepoError('forbidden');
    if (post.locked) throw new RepoError('locked');
    const files = input.files || [];
    const keepIds = new Set(input.keepMedia || post.media.map((m) => m.id));
    const kept = post.media.filter((m) => keepIds.has(m.id));
    if (kept.length + files.length > config.maxImagesPerPost) throw new RepoError('too-many-images');
    const key = post.protected ? this.#keyFor(post.id) : null;
    if (post.protected && !key) throw new RepoError('locked');

    const added = [];
    for (let i = 0; i < files.length; i++) {
      onProgress({ stage: 'upload', done: i, total: files.length });
      added.push(await this.#uploadImage(files[i], post.ids.mf, key, post.pid));
    }
    onProgress({ stage: 'save' });
    const updatedAt = Date.now();
    const text = input.text ?? post.text;
    const audience = cleanAudience(input.audience ?? post.audience, this.me.email);
    let protection = post.protection;
    if (post.protected && input.newPassword) {
      const store = await this.#loadRawKeys();
      const raw = store[post.id] ? b64d(store[post.id]) : null;
      if (!raw) throw new RepoError('locked');
      protection = await rewrapProtection(raw, input.newPassword, config.postKdfIterations);
    }
    const linkShare = post.protected ? (input.linkShare ?? post.linkShare) : false;
    const doc = await buildPostDoc({
      id: post.pid, owner: post.owner, createdAt: post.createdAt, updatedAt,
      text, media: [...kept, ...added], mentions: extractMentions(text), audience, linkShare, protection, key,
    });
    await this.drive.updateJson(post.ids.pj, doc);
    await this.drive.updateMeta(post.id, { properties: { rev: String(updatedAt) } });

    // drop files that are no longer referenced
    const dropped = post.media.filter((m) => !keepIds.has(m.id));
    for (const m of dropped) for (const fid of [m.id, m.thumb]) if (fid) { try { await this.drive.remove(fid); } catch { /* already gone */ } this.#forgetBlob(fid); }

    const warnings = await this.#applyAudience(post, audience);
    if (post.protected && linkShare !== post.linkShare) {
      try { await this.#applyLink(post.id, linkShare); } catch (e) { doc.linkShare = post.linkShare; warnings.push({ email: '*', error: e }); }
    }
    if (warnings.length) {
      // never claim access in post.json that Drive did not actually grant
      for (const w of warnings) if (w.email !== '*') { if (post.audience?.[w.email]) doc.audience[w.email] = post.audience[w.email]; else delete doc.audience[w.email]; }
      await this.drive.updateJson(post.ids.pj, doc);
    }

    const next = await openPostDoc(doc, key);
    await this.loadIndex();
    this.#upsertEntry(toEntry(next, { id: post.id, ids: post.ids, rev: updatedAt }));
    await this.#commitIndex();
    return { post: { ...next, id: post.id, mine: true, role: 'owner', ids: post.ids, doc, rev: String(updatedAt) }, warnings };
  }

  #forgetBlob(fid) {
    const u = this.blobs.get(fid);
    if (u) { URL.revokeObjectURL(u); this.blobs.delete(fid); }
  }

  async deletePost(post) {
    if (normEmail(post.owner?.email) !== this.me.email) throw new RepoError('forbidden');
    if (config.deleteMode === 'permanent') await this.drive.remove(post.id);
    else await this.drive.trash(post.id);
    await this.loadIndex();
    this.index.mine = this.index.mine.filter((e) => e.id !== post.id);
    this.keys.delete(post.id);
    const store = await this.#loadRawKeys();
    if (store[post.id]) { delete store[post.id]; await this.vault.set(`postkeys:${this.me.email}`, store); }
    await this.#commitIndex();
  }

  /** Forget a post that is shared with me (it only disappears from my index; the owner's data is untouched). */
  async forgetShared(id) {
    await this.loadIndex();
    this.index.shared = this.index.shared.filter((e) => e.id !== id);
    await this.#commitIndex();
  }

  /* ================= sharing ================= */
  async #permsByEmail(fileId) {
    const perms = await this.drive.listPermissions(fileId);
    const map = new Map();
    for (const p of perms) if (p.type === 'user' && p.emailAddress) map.set(normEmail(p.emailAddress), p);
    return { perms, map };
  }

  /**
   * view    -> reader on the folder
   * comment -> reader on the folder + writer on comments.json only (so a commenter can never edit the post itself)
   */
  async #grant(folderId, cjId, email, role) {
    const notify = config.notifyEmail;
    const folder = await this.#permsByEmail(folderId);
    if (!folder.map.has(email)) await this.drive.addPermission(folderId, { email, role: 'reader', notify });
    if (cjId) await this.#setCommentAccess(cjId, email, role === ROLE_COMMENT);
  }

  async #setCommentAccess(cjId, email, allow) {
    const { map } = await this.#permsByEmail(cjId);
    const have = map.get(email);
    if (allow) {
      if (have && (have.role === 'writer' || have.role === 'owner')) return;
      try { await this.drive.addPermission(cjId, { email, role: 'writer' }); } catch (e) {
        if (!have) throw e;
        await this.drive.updatePermission(cjId, have.id, 'writer');
      }
    } else if (have && have.role === 'writer') {
      try { await this.drive.removePermission(cjId, have.id); } catch { await this.drive.updatePermission(cjId, have.id, 'reader'); }
    }
  }

  async #revoke(folderId, cjId, email) {
    if (cjId) { try { await this.#setCommentAccess(cjId, email, false); } catch { /* the folder permission removal below is what matters */ } }
    const { map } = await this.#permsByEmail(folderId);
    const p = map.get(email);
    if (p && p.role !== 'owner') await this.drive.removePermission(folderId, p.id);
  }

  async #applyAudience(post, wanted) {
    const warnings = [];
    // trust Drive over the mirror: sharing may also have been changed from the Drive UI
    const current = (await this.readAudience(post).catch(() => ({ audience: post.audience || {} }))).audience;
    for (const email of Object.keys(current)) if (!wanted[email]) { try { await this.#revoke(post.id, post.ids.cj, email); } catch (e) { warnings.push({ email, error: e }); } }
    for (const [email, role] of Object.entries(wanted)) if (current[email] !== role) { try { await this.#grant(post.id, post.ids.cj, email, role); } catch (e) { warnings.push({ email, error: e }); } }
    return warnings;
  }

  async #applyLink(folderId, enabled) {
    const { perms } = await this.#permsByEmail(folderId);
    const any = perms.find((p) => p.type === 'anyone');
    if (enabled && !any) await this.drive.addPermission(folderId, { type: 'anyone', role: 'reader' });
    if (!enabled && any) await this.drive.removePermission(folderId, any.id);
  }

  /** Share (or change the role of) one person and persist the mirror kept in post.json. */
  async setAccess(post, email, role) {
    email = normEmail(email);
    if (!post.mine) throw new RepoError('forbidden');
    // start from what Drive really has, so people added through the Drive UI are not silently revoked
    const truth = await this.readAudience(post).catch(() => ({ audience: post.audience }));
    const audience = { ...truth.audience };
    if (role) audience[email] = role; else delete audience[email];
    const { post: next, warnings } = await this.updatePost(post, { audience, keepMedia: post.media.map((m) => m.id), files: [] });
    return { post: next, warnings };
  }

  async setLinkShare(post, enabled) {
    const { post: next } = await this.updatePost(post, { linkShare: enabled, keepMedia: post.media.map((m) => m.id), files: [] });
    return next;
  }

  /** Authoritative list of who really has access, straight from Drive (catches changes made in the Drive UI). */
  async readAudience(post) {
    const folder = await this.#permsByEmail(post.id);
    const file = post.ids.cj ? await this.#permsByEmail(post.ids.cj) : { map: new Map() };
    const audience = {};
    for (const [email, p] of folder.map) {
      if (p.role === 'owner' || email === this.me.email) continue;
      const f = file.map.get(email);
      audience[email] = p.role === 'writer' || f?.role === 'writer' ? ROLE_COMMENT : ROLE_VIEW;
    }
    const names = {};
    for (const p of folder.perms) if (p.emailAddress && p.displayName) names[normEmail(p.emailAddress)] = p.displayName;
    return { audience, linkShare: folder.perms.some((p) => p.type === 'anyone'), names };
  }

  /* ================= comments & likes ================= */
  async loadComments(post) {
    if (!post.ids?.cj) return { comments: [], likes: [] };
    const data = await this.drive.downloadJson(post.ids.cj).catch((e) => { throw this.#mapErr(e); });
    return this.#openComments(post, data);
  }

  async #openComments(post, data) {
    const key = post.protected ? this.#keyFor(post.id) : null;
    const comments = [];
    for (const c of data.comments || []) {
      if (c.enc) {
        if (!key) continue;
        try { comments.push({ id: c.id, by: c.by, name: c.name, at: c.at, text: (await decryptJson(key, c.enc, `comment:${c.id}`)).text }); } catch { /* skip undecryptable */ }
      } else comments.push({ id: c.id, by: c.by, name: c.name, at: c.at, text: c.text });
    }
    return { comments, likes: (data.likes || []).map(normEmail) };
  }

  async #mutateComments(post, fn) {
    if (!post.ids?.cj) throw new RepoError('forbidden');
    const data = await this.drive.downloadJson(post.ids.cj);
    data.comments ||= [];
    data.likes ||= [];
    await fn(data);
    try { await this.drive.updateJson(post.ids.cj, data); } catch (e) { throw this.#mapErr(e); }
    return this.#openComments(post, data);
  }

  async addComment(post, text) {
    const value = String(text || '').trim();
    if (!value) return null;
    if (post.locked) throw new RepoError('locked');
    const id = randomId(5);
    const entry = { id, by: this.me.email, name: this.me.name, at: Date.now() };
    const key = post.protected ? this.#keyFor(post.id) : null;
    if (post.protected) entry.enc = await encryptJson(key, { text: value }, `comment:${id}`); else entry.text = value;
    return this.#mutateComments(post, (d) => { d.comments.push(entry); });
  }

  deleteComment(post, commentId) {
    return this.#mutateComments(post, (d) => {
      const c = d.comments.find((x) => x.id === commentId);
      if (!c) return;
      if (c.by !== this.me.email && !post.mine) throw new RepoError('forbidden');
      d.comments = d.comments.filter((x) => x.id !== commentId);
    });
  }

  toggleLike(post) {
    return this.#mutateComments(post, (d) => {
      const me = this.me.email;
      d.likes = d.likes.map(normEmail);
      d.likes = d.likes.includes(me) ? d.likes.filter((x) => x !== me) : [...d.likes, me];
    });
  }

  /* ================= account ================= */
  async quota() {
    const a = await this.drive.about();
    const q = a.storageQuota || {};
    return { used: Number(q.usage || 0), limit: q.limit ? Number(q.limit) : null };
  }

  dispose() {
    this.pushIndex.cancel();
    for (const u of this.blobs.values()) URL.revokeObjectURL(u);
    this.blobs.clear();
    this.keys.clear();
    this.index = null;
    this.contacts = null;
    this.rawKeys = null;
  }

  /** Push any pending index changes right now (before locking / signing out). */
  async flush() {
    this.pushIndex.cancel();
    try { await this.#pushIndex(); } catch { /* offline */ }
  }
}
