/**
 * Thin helpers over WebCrypto. Everything here runs in the browser; nothing is sent anywhere.
 * Binary layout for every ciphertext produced by this module: iv(12 bytes) || AES-GCM(ciphertext + tag).
 */
const subtle = () => globalThis.crypto.subtle;
const enc = new TextEncoder();
const dec = new TextDecoder();

export class CryptoError extends Error {
  constructor(code, message) { super(message || code); this.name = 'CryptoError'; this.code = code; }
}

/* ---------- encoding ---------- */
export function b64e(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(s);
}
export function b64d(str) {
  const s = atob(str);
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}
export const b64urlEncode = (bytes) => b64e(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export const utf8 = (s) => enc.encode(s);
export const fromUtf8 = (b) => dec.decode(b);

/* ---------- randomness ---------- */
export function randomBytes(n) {
  const out = new Uint8Array(n);
  for (let i = 0; i < n; i += 65536) globalThis.crypto.getRandomValues(out.subarray(i, Math.min(n, i + 65536)));
  return out;
}
export function randomId(bytes = 8) {
  return Array.from(randomBytes(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
}

/* ---------- hashing ---------- */
export async function sha256Hex(input) {
  const data = typeof input === 'string' ? utf8(input) : input;
  return Array.from(new Uint8Array(await subtle().digest('SHA-256', data)), (b) => b.toString(16).padStart(2, '0')).join('');
}

/* ---------- keys ---------- */
/** PBKDF2-SHA256 -> AES-GCM-256 key (non-extractable). */
export async function deriveKey(secret, salt, iterations, usages = ['encrypt', 'decrypt']) {
  const base = await subtle().importKey('raw', utf8(secret), 'PBKDF2', false, ['deriveKey']);
  return subtle().deriveKey(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    usages,
  );
}

/** Random non-extractable AES-GCM key (used as the per-device layer). */
export function generateDeviceKey() {
  return subtle().generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
}

export const newRawKey = () => randomBytes(32);
export function importRawKey(raw, usages = ['encrypt', 'decrypt']) {
  return subtle().importKey('raw', raw, { name: 'AES-GCM', length: 256 }, false, usages);
}

/* ---------- AES-GCM ---------- */
export async function encryptBytes(key, bytes, aad) {
  const iv = randomBytes(12);
  const params = { name: 'AES-GCM', iv };
  if (aad) params.additionalData = typeof aad === 'string' ? utf8(aad) : aad;
  const ct = new Uint8Array(await subtle().encrypt(params, key, bytes));
  const out = new Uint8Array(12 + ct.length);
  out.set(iv, 0);
  out.set(ct, 12);
  return out;
}

export async function decryptBytes(key, packed, aad) {
  const u8 = packed instanceof Uint8Array ? packed : new Uint8Array(packed);
  if (u8.length < 12 + 16) throw new CryptoError('malformed', 'ciphertext too short');
  const params = { name: 'AES-GCM', iv: u8.subarray(0, 12) };
  if (aad) params.additionalData = typeof aad === 'string' ? utf8(aad) : aad;
  try {
    return new Uint8Array(await subtle().decrypt(params, key, u8.subarray(12)));
  } catch {
    throw new CryptoError('decrypt-failed', 'wrong key or corrupted data');
  }
}

export async function encryptJson(key, value, aad) {
  return b64e(await encryptBytes(key, utf8(JSON.stringify(value)), aad));
}
export async function decryptJson(key, text, aad) {
  return JSON.parse(fromUtf8(await decryptBytes(key, b64d(text), aad)));
}

/* ---------- password-protected content (posts) ---------- */
/**
 * A protected post has a random content key. The content key is wrapped by a key-encryption key derived
 * from the share password, so changing the password only re-wraps 32 bytes and never touches the media.
 */
export async function createProtection(password, iterations) {
  const salt = randomBytes(16);
  const raw = newRawKey();
  const kek = await deriveKey(password, salt, iterations);
  const wrap = b64e(await encryptBytes(kek, raw, 'specact:wrap'));
  return {
    protection: { alg: 'AES-256-GCM', kdf: 'PBKDF2-SHA256', iter: iterations, salt: b64e(salt), wrap },
    raw,
    key: await importRawKey(raw),
  };
}

export async function unlockProtection(protection, password) {
  const kek = await deriveKey(password, b64d(protection.salt), protection.iter);
  let raw;
  try {
    raw = await decryptBytes(kek, b64d(protection.wrap), 'specact:wrap');
  } catch {
    throw new CryptoError('wrong-password', 'wrong password');
  }
  return { raw, key: await importRawKey(raw) };
}

export async function rewrapProtection(raw, newPassword, iterations) {
  const salt = randomBytes(16);
  const kek = await deriveKey(newPassword, salt, iterations);
  return { alg: 'AES-256-GCM', kdf: 'PBKDF2-SHA256', iter: iterations, salt: b64e(salt), wrap: b64e(await encryptBytes(kek, raw, 'specact:wrap')) };
}

/* ---------- PKCE ---------- */
export async function pkcePair() {
  const verifier = b64urlEncode(randomBytes(48));
  const challenge = b64urlEncode(new Uint8Array(await subtle().digest('SHA-256', utf8(verifier))));
  return { verifier, challenge };
}
