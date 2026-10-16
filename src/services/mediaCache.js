/**
 * Photos are downloaded once per device: the bytes (the sealed bytes, for password-protected posts) are kept in the
 * browser's Cache Storage, encrypted with a key that lives in the PIN vault — so nothing readable sits on the disk
 * and a locked app cannot read it. Drive media files never change (an edit uploads a new file), so the file id is a
 * safe cache key.
 */
import { vault } from './secureStore';
import { b64d, b64e, decryptBytes, encryptBytes, importRawKey, newRawKey } from './crypto';

const NAME = 'specact-media-v1';
const MAX_ENTRIES = 600;
const MAX_BYTES = 12 * 1024 * 1024; // documents and videos are not worth keeping twice
let puts = 0;

const supported = () => typeof caches !== 'undefined' && vault.unlocked;
const req = (id) => new Request(`https://specact.invalid/media/${encodeURIComponent(id)}`);

async function key() {
  const stored = await vault.get('mediakey');
  if (stored) return importRawKey(b64d(stored));
  const raw = newRawKey();
  await vault.set('mediakey', b64e(raw));
  return importRawKey(raw);
}

export async function cacheGet(id) {
  try {
    if (!supported()) return null;
    const hit = await (await caches.open(NAME)).match(req(id));
    if (!hit) return null;
    return await decryptBytes(await key(), new Uint8Array(await hit.arrayBuffer()), `cache:${id}`);
  } catch { return null; }
}

export async function cachePut(id, bytes) {
  try {
    if (!supported() || bytes.length > MAX_BYTES) return;
    const store = await caches.open(NAME);
    await store.put(req(id), new Response(await encryptBytes(await key(), bytes, `cache:${id}`)));
    if (++puts % 25 === 0) { // oldest entries go first
      const all = await store.keys();
      for (const k of all.slice(0, Math.max(0, all.length - MAX_ENTRIES))) await store.delete(k);
    }
  } catch { /* the cache is only an optimisation */ }
}

export async function cacheClear() {
  try { if (typeof caches !== 'undefined') await caches.delete(NAME); } catch { /* idem */ }
}
