/**
 * Local vault for everything sensitive that lives on the device
 * (Google client id/secret, refresh token, cached index, post keys).
 *
 * Two independent encryption layers, both required to read any record:
 *   inner : AES-256-GCM with a random, NON-EXTRACTABLE device key that never leaves this browser profile
 *   outer : AES-256-GCM with a key derived from the user's numeric PIN (PBKDF2-SHA256, many iterations)
 * Each record is bound to its own name through AES-GCM additional data, so records cannot be swapped.
 * Wrong PIN attempts are counted persistently, back off exponentially and finally wipe the vault.
 */
import { config } from '../config';
import { b64d, b64e, decryptBytes, deriveKey, encryptBytes, fromUtf8, generateDeviceKey, randomBytes, utf8 } from './crypto';

const DB_NAME = 'specact-vault';
const DB_VERSION = 1;
const META = 'meta';
const RECORDS = 'records';
const PREFIX = 'v1.';
const CHECK = '__check__';

export class VaultError extends Error {
  constructor(code, extra = {}) { super(code); this.name = 'VaultError'; this.code = code; Object.assign(this, extra); }
}

/* ---------- tiny promise wrapper around IndexedDB ---------- */
let dbPromise = null;
function openDb() {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(META)) db.createObjectStore(META);
        if (!db.objectStoreNames.contains(RECORDS)) db.createObjectStore(RECORDS);
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => { dbPromise = null; reject(req.error); };
    });
  }
  return dbPromise;
}
const tx = async (store, mode, fn) => {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const t = db.transaction(store, mode);
    const s = Array.isArray(store) ? null : t.objectStore(store);
    let result;
    Promise.resolve(fn(s, t)).then((r) => { result = r; }, reject);
    t.oncomplete = () => resolve(result);
    t.onerror = () => reject(t.error);
    t.onabort = () => reject(t.error || new Error('aborted'));
  });
};
const req = (r) => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
const idbGet = (store, key) => tx(store, 'readonly', (s) => req(s.get(key)));
const idbPut = (store, key, value) => tx(store, 'readwrite', (s) => req(s.put(value, key)));
const idbDel = (store, key) => tx(store, 'readwrite', (s) => req(s.delete(key)));
const idbAll = (store) => tx(store, 'readonly', async (s) => {
  const keys = await req(s.getAllKeys());
  const vals = await req(s.getAll());
  return keys.map((k, i) => [k, vals[i]]);
});

/* ---------- the vault ---------- */
class SecureStore {
  constructor() { this.pinKey = null; this.devKey = null; }

  get unlocked() { return !!(this.pinKey && this.devKey); }

  async exists() { return !!(await idbGet(META, 'vault')); }

  async status() {
    const meta = await idbGet(META, 'vault');
    return {
      exists: !!meta,
      attempts: meta?.attempts || 0,
      lockedUntil: meta?.lockedUntil || 0,
      maxAttempts: config.pinMaxAttempts,
    };
  }

  /* -- record sealing -- */
  async #seal(name, value, pinKey = this.pinKey, devKey = this.devKey) {
    const inner = await encryptBytes(devKey, utf8(JSON.stringify(value)), `dev:${name}`);
    const outer = await encryptBytes(pinKey, inner, `pin:${name}`);
    return PREFIX + b64e(outer);
  }
  async #open(name, sealed, pinKey = this.pinKey, devKey = this.devKey) {
    if (typeof sealed !== 'string' || !sealed.startsWith(PREFIX)) throw new VaultError('corrupt');
    const inner = await decryptBytes(pinKey, b64d(sealed.slice(PREFIX.length)), `pin:${name}`);
    return JSON.parse(fromUtf8(await decryptBytes(devKey, inner, `dev:${name}`)));
  }

  /** First-time setup. Replaces any existing vault. */
  async create(pin) {
    await this.wipe();
    const salt = randomBytes(16);
    const iter = config.pbkdf2Iterations;
    const devKey = await generateDeviceKey();
    const pinKey = await deriveKey(pin, salt, iter);
    await idbPut(META, 'device-key', devKey);
    await idbPut(RECORDS, CHECK, await this.#seal(CHECK, 'specact-ok', pinKey, devKey));
    await idbPut(META, 'vault', { v: 1, salt: b64e(salt), iter, attempts: 0, lockedUntil: 0, createdAt: Date.now() });
    this.pinKey = pinKey;
    this.devKey = devKey;
  }

  /**
   * Derive the PIN key and prove it is right. Failures are counted persistently, throttled and finally
   * wipe the vault — the same rules whether the caller is unlocking or confirming the PIN for a change.
   */
  async #checkPin(pin) {
    const meta = await idbGet(META, 'vault');
    const devKey = await idbGet(META, 'device-key');
    if (!meta || !devKey) throw new VaultError('no-vault');
    const wait = (meta.lockedUntil || 0) - Date.now();
    if (wait > 0) throw new VaultError('throttled', { retryInMs: wait });

    const pinKey = await deriveKey(pin, b64d(meta.salt), meta.iter);
    try {
      const check = await this.#open(CHECK, await idbGet(RECORDS, CHECK), pinKey, devKey);
      if (check !== 'specact-ok') throw new Error('bad check');
    } catch {
      const attempts = (meta.attempts || 0) + 1;
      if (attempts >= config.pinMaxAttempts) {
        await this.wipe();
        throw new VaultError('wiped');
      }
      // 3 free tries, then 5s, 10s, 20s ... capped at 15 minutes
      const delay = attempts < 3 ? 0 : Math.min(15 * 60_000, 5_000 * 2 ** (attempts - 3));
      await idbPut(META, 'vault', { ...meta, attempts, lockedUntil: delay ? Date.now() + delay : 0 });
      throw new VaultError('bad-pin', { attempts, remaining: config.pinMaxAttempts - attempts, retryInMs: delay });
    }
    if (meta.attempts || meta.lockedUntil) await idbPut(META, 'vault', { ...meta, attempts: 0, lockedUntil: 0 });
    return { pinKey, devKey, meta };
  }

  async unlock(pin) {
    const { pinKey, devKey } = await this.#checkPin(pin);
    this.pinKey = pinKey;
    this.devKey = devKey;
  }

  /** Confirm the PIN of an unlocked vault (used before sensitive changes). */
  async verify(pin) {
    this.#need();
    await this.#checkPin(pin);
  }

  /** Forget the keys held in memory. Data stays encrypted on disk. */
  lock() { this.pinKey = null; this.devKey = null; }

  #need() { if (!this.unlocked) throw new VaultError('locked'); }

  async get(name, fallback = null) {
    this.#need();
    if (name === CHECK) throw new VaultError('reserved');
    const sealed = await idbGet(RECORDS, name);
    if (sealed == null) return fallback;
    try { return await this.#open(name, sealed); } catch { return fallback; }
  }

  async set(name, value) {
    this.#need();
    if (name === CHECK) throw new VaultError('reserved');
    await idbPut(RECORDS, name, await this.#seal(name, value));
  }

  async remove(name) { this.#need(); await idbDel(RECORDS, name); }

  /** Re-encrypt every record under a new PIN (and a fresh salt). */
  async changePin(oldPin, newPin) {
    this.#need();
    const { pinKey: oldKey, meta } = await this.#checkPin(oldPin);

    const rows = (await idbAll(RECORDS)).filter(([k]) => k !== CHECK);
    const plain = [];
    for (const [k, v] of rows) { try { plain.push([k, await this.#open(k, v, oldKey, this.devKey)]); } catch { /* drop unreadable */ } }

    const salt = randomBytes(16);
    const iter = config.pbkdf2Iterations;
    const newKey = await deriveKey(newPin, salt, iter);
    const sealed = [[CHECK, await this.#seal(CHECK, 'specact-ok', newKey, this.devKey)]];
    for (const [k, v] of plain) sealed.push([k, await this.#seal(k, v, newKey, this.devKey)]);

    await tx([RECORDS, META], 'readwrite', async (_s, t) => {
      const recs = t.objectStore(RECORDS);
      await req(recs.clear());
      for (const [k, v] of sealed) await req(recs.put(v, k));
      await req(t.objectStore(META).put({ v: 1, salt: b64e(salt), iter, attempts: 0, lockedUntil: 0, createdAt: meta.createdAt, changedAt: Date.now() }, 'vault'));
    });
    this.pinKey = newKey;
  }

  /** Delete the vault and everything in it. */
  async wipe() {
    this.lock();
    try { if (typeof caches !== 'undefined') await caches.delete('specact-media-v1'); } catch { /* nothing cached */ }
    const db = await openDb();
    await new Promise((resolve, reject) => {
      const t = db.transaction([META, RECORDS], 'readwrite');
      t.objectStore(META).clear();
      t.objectStore(RECORDS).clear();
      t.oncomplete = resolve;
      t.onerror = () => reject(t.error);
    });
  }
}

export const vault = new SecureStore();
export const _internals = { openDb };
