import { describe, expect, it } from 'vitest';
import { b64d, b64e, createProtection, decryptBytes, decryptJson, deriveKey, encryptBytes, encryptJson, importRawKey, newRawKey, pkcePair, rewrapProtection, unlockProtection, utf8, fromUtf8, randomBytes } from '../src/services/crypto';

describe('crypto primitives', () => {
  it('base64 round trips large buffers', () => {
    const data = randomBytes(100_000);
    expect(b64d(b64e(data))).toEqual(data);
  });

  it('encrypts and decrypts, binding additional data', async () => {
    const key = await importRawKey(newRawKey());
    const ct = await encryptBytes(key, utf8('hello'), 'a');
    expect(fromUtf8(await decryptBytes(key, ct, 'a'))).toBe('hello');
    await expect(decryptBytes(key, ct, 'b')).rejects.toMatchObject({ code: 'decrypt-failed' });
  });

  it('detects tampering', async () => {
    const key = await importRawKey(newRawKey());
    const ct = await encryptBytes(key, utf8('hello'));
    ct[ct.length - 1] ^= 1;
    await expect(decryptBytes(key, ct)).rejects.toMatchObject({ code: 'decrypt-failed' });
  });

  it('json helpers', async () => {
    const key = await deriveKey('123456', randomBytes(16), 1000);
    const text = await encryptJson(key, { a: [1, 2, 'é'] }, 'x');
    expect(await decryptJson(key, text, 'x')).toEqual({ a: [1, 2, 'é'] });
  });

  it('password protection: unlock, wrong password, rewrap', async () => {
    const { protection, raw } = await createProtection('s3cret', 1000);
    const ok = await unlockProtection(protection, 's3cret');
    expect(ok.raw).toEqual(raw);
    await expect(unlockProtection(protection, 'nope')).rejects.toMatchObject({ code: 'wrong-password' });
    const next = await rewrapProtection(raw, 'new-pass', 1000);
    expect((await unlockProtection(next, 'new-pass')).raw).toEqual(raw);
    await expect(unlockProtection(next, 's3cret')).rejects.toMatchObject({ code: 'wrong-password' });
  });

  it('pkce pair is url-safe and consistent length', async () => {
    const { verifier, challenge } = await pkcePair();
    expect(verifier).toMatch(/^[A-Za-z0-9_-]{43,}$/);
    expect(challenge).toMatch(/^[A-Za-z0-9_-]{43}$/);
  });
});
