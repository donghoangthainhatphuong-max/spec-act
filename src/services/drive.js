/**
 * Minimal Google Drive v3 REST client. Browser <-> Google only.
 * Handles bearer auth, one transparent token refresh, retries with back-off and a small concurrency cap.
 */
export const MIME_FOLDER = 'application/vnd.google-apps.folder';
export const MIME_SHORTCUT = 'application/vnd.google-apps.shortcut';
const API = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';

export class DriveError extends Error {
  constructor(status, reason, message) {
    super(message || reason || `HTTP ${status}`);
    this.name = 'DriveError';
    this.status = status;
    this.reason = reason;
  }
  get notFound() { return this.status === 404; }
  get forbidden() { return this.status === 403 || this.status === 401; }
}

/** Escape a literal for a Drive `q` expression. */
export const qs = (v) => `'${String(v).replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class Limiter {
  constructor(max) { this.max = max; this.active = 0; this.queue = []; }
  async run(fn) {
    while (this.active >= this.max) await new Promise((r) => this.queue.push(r));
    this.active++;
    try { return await fn(); } finally { this.active--; this.queue.shift()?.(); }
  }
}

export class DriveClient {
  /**
   * @param {{ getToken: () => Promise<string>, onUnauthorized?: () => Promise<string>, concurrency?: number }} opts
   */
  constructor({ getToken, onUnauthorized, concurrency = 6 }) {
    this.getToken = getToken;
    this.onUnauthorized = onUnauthorized;
    this.limiter = new Limiter(concurrency);
  }

  async request(url, { method = 'GET', headers = {}, body, raw = false, retries = 3 } = {}) {
    return this.limiter.run(async () => {
      let token = await this.getToken();
      let refreshed = false;
      for (let attempt = 0; ; attempt++) {
        let res;
        try {
          res = await fetch(url, { method, body, headers: { ...headers, Authorization: `Bearer ${token}` } });
        } catch (e) {
          if (attempt < retries) { await sleep(400 * 2 ** attempt); continue; }
          throw new DriveError(0, 'network', 'network error');
        }
        if (res.status === 401 && !refreshed && this.onUnauthorized) {
          refreshed = true;
          token = await this.onUnauthorized();
          continue;
        }
        const retryable = res.status === 429 || res.status >= 500;
        let reasonRetry = false;
        if (res.status === 403 && attempt < retries) {
          const j = await res.clone().json().catch(() => null);
          reasonRetry = /rateLimitExceeded|userRateLimitExceeded/.test(j?.error?.errors?.[0]?.reason || '');
        }
        if ((retryable || reasonRetry) && attempt < retries) {
          await sleep(500 * 2 ** attempt + Math.random() * 250);
          continue;
        }
        if (!res.ok) {
          const j = await res.json().catch(() => null);
          throw new DriveError(res.status, j?.error?.errors?.[0]?.reason || j?.error?.status, j?.error?.message);
        }
        if (raw) return res;
        if (res.status === 204) return null;
        const ct = res.headers.get('content-type') || '';
        return ct.includes('json') ? res.json() : res.text();
      }
    });
  }

  /* ---------- account ---------- */
  about() {
    return this.request(`${API}/about?fields=${encodeURIComponent('user(displayName,emailAddress,photoLink),storageQuota(limit,usage,usageInDrive)')}`);
  }

  /* ---------- files ---------- */
  async list({ q, fields = 'id,name,mimeType,modifiedTime,properties', pageSize = 200, orderBy, all = true } = {}) {
    const out = [];
    let pageToken;
    do {
      const p = new URLSearchParams({ q, pageSize: String(pageSize), fields: `nextPageToken,files(${fields})`, spaces: 'drive' });
      if (orderBy) p.set('orderBy', orderBy);
      if (pageToken) p.set('pageToken', pageToken);
      const j = await this.request(`${API}/files?${p}`);
      out.push(...(j.files || []));
      pageToken = all ? j.nextPageToken : undefined;
    } while (pageToken);
    return out;
  }

  get(id, fields = 'id,name,mimeType,modifiedTime,properties') {
    return this.request(`${API}/files/${encodeURIComponent(id)}?fields=${encodeURIComponent(fields)}`);
  }

  createFolder(name, parentId, properties) {
    return this.request(`${API}/files?fields=${encodeURIComponent('id,name,properties')}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, mimeType: MIME_FOLDER, parents: parentId ? [parentId] : undefined, properties }),
    });
  }

  /** A Drive shortcut (a link inside my own Drive) to a folder shared with me. */
  createShortcut(name, parentId, targetId) {
    return this.request(`${API}/files?fields=${encodeURIComponent('id,name,shortcutDetails')}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, mimeType: MIME_SHORTCUT, parents: [parentId], shortcutDetails: { targetId } }),
    });
  }

  updateMeta(id, body, { fields = 'id,name,properties,modifiedTime', addParents, removeParents } = {}) {
    const p = new URLSearchParams({ fields });
    if (addParents) p.set('addParents', addParents);
    if (removeParents) p.set('removeParents', removeParents);
    return this.request(`${API}/files/${encodeURIComponent(id)}?${p}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  }

  trash(id) { return this.updateMeta(id, { trashed: true }); }
  remove(id) { return this.request(`${API}/files/${encodeURIComponent(id)}`, { method: 'DELETE' }); }

  /** Create a file with a body in one multipart request. */
  createFile({ name, parentId, mimeType, data, properties }) {
    const meta = { name, parents: parentId ? [parentId] : undefined, mimeType, properties };
    const boundary = `specact${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`;
    const body = new Blob([
      `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n`,
      `--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`,
      data,
      `\r\n--${boundary}--`,
    ]);
    return this.request(`${UPLOAD}/files?uploadType=multipart&fields=${encodeURIComponent('id,name,mimeType,modifiedTime,version')}`, {
      method: 'POST',
      headers: { 'Content-Type': `multipart/related; boundary=${boundary}` },
      body,
    });
  }

  /**
   * Large files (videos): resumable upload, one PUT of the whole body. Falls back to multipart when the browser
   * is not allowed to read the session address from the response.
   */
  async createFileLarge({ name, parentId, mimeType, data, properties }) {
    if ((data.size ?? data.length) <= 4 * 1024 * 1024) return this.createFile({ name, parentId, mimeType, data, properties });
    const init = await this.request(`${UPLOAD}/files?uploadType=resumable&fields=${encodeURIComponent('id,name,mimeType,modifiedTime,version')}`, {
      method: 'POST', raw: true,
      headers: { 'Content-Type': 'application/json; charset=UTF-8', 'X-Upload-Content-Type': mimeType },
      body: JSON.stringify({ name, parents: parentId ? [parentId] : undefined, mimeType, properties }),
    });
    const session = init.headers.get('Location');
    if (!session) return this.createFile({ name, parentId, mimeType, data, properties });
    const res = await this.request(session, { method: 'PUT', raw: true, retries: 1, headers: { 'Content-Type': mimeType }, body: data });
    return res.json();
  }

  createJson(name, parentId, value, properties) {
    return this.createFile({ name, parentId, mimeType: 'application/json', data: JSON.stringify(value), properties });
  }

  /** Replace the content of an existing file. */
  updateContent(id, data, mimeType = 'application/json') {
    return this.request(`${UPLOAD}/files/${encodeURIComponent(id)}?uploadType=media&fields=${encodeURIComponent('id,modifiedTime,version')}`, {
      method: 'PATCH',
      headers: { 'Content-Type': mimeType },
      body: typeof data === 'string' ? data : data,
    });
  }
  updateJson(id, value) { return this.updateContent(id, JSON.stringify(value)); }

  async downloadJson(id) {
    const res = await this.request(`${API}/files/${encodeURIComponent(id)}?alt=media`, { raw: true });
    return JSON.parse(await res.text());
  }
  async downloadBytes(id) {
    const res = await this.request(`${API}/files/${encodeURIComponent(id)}?alt=media`, { raw: true });
    return new Uint8Array(await res.arrayBuffer());
  }

  /* ---------- permissions ---------- */
  async listPermissions(fileId) {
    const j = await this.request(`${API}/files/${encodeURIComponent(fileId)}/permissions?fields=${encodeURIComponent('permissions(id,type,role,emailAddress,displayName)')}&pageSize=100`);
    return j.permissions || [];
  }

  async addPermission(fileId, { email, role, type = 'user', notify = false, message }) {
    const attempt = (sendNotificationEmail) => {
      const p = new URLSearchParams({ sendNotificationEmail: String(sendNotificationEmail), fields: 'id,type,role,emailAddress,displayName' });
      if (sendNotificationEmail && message) p.set('emailMessage', message);
      const body = type === 'anyone' ? { type, role, allowFileDiscovery: false } : { type, role, emailAddress: email };
      return this.request(`${API}/files/${encodeURIComponent(fileId)}/permissions?${p}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    };
    try {
      return await attempt(notify);
    } catch (e) {
      // Addresses without a Google account can only be invited by e-mail.
      if (!notify && e.status === 400 && /notif|invalid.*sharing|invalidSharingRequest/i.test(`${e.reason} ${e.message}`)) return attempt(true);
      throw e;
    }
  }

  updatePermission(fileId, permissionId, role) {
    return this.request(`${API}/files/${encodeURIComponent(fileId)}/permissions/${encodeURIComponent(permissionId)}?fields=id,role`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ role }),
    });
  }

  removePermission(fileId, permissionId) {
    return this.request(`${API}/files/${encodeURIComponent(fileId)}/permissions/${encodeURIComponent(permissionId)}`, { method: 'DELETE' });
  }
}
