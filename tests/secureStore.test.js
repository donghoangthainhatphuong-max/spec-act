import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/config', async (orig) => {
  const mod = await orig();
  return { ...mod, config: { ...mod.config, pbkdf2Iterations: 1000, pinMaxAttempts: 4 } };
});

const { vault, _internals } = await import('../src/services/secureStore');

async function clearThrottle() {
  const db = await _internals.openDb();
  await new Promise((res) => {
    const t = db.transaction('meta', 'readwrite');
    const s = t.objectStore('meta');
    const g = s.get('vault');
    g.onsuccess = () => { s.put({ ...g.result, lockedUntil: 0 }, 'vault'); };
    t.oncomplete = res;
  });
}

describe('secure vault', () => {
  beforeEach(async () => { await vault.wipe(); });

  it('stores nothing readable without the PIN', async () => {
    await vault.create('123456');
    await vault.set('creds', { clientId: 'abc', clientSecret: 'TOP-SECRET' });
    const raw = await new Promise((resolve) => {
      const db = indexedDB.open('specact-vault');
      db.onsuccess = () => {
        const t = db.result.transaction('records').objectStore('records').getAll();
        t.onsuccess = () => resolve(JSON.stringify(t.result));
      };
    });
    expect(raw).not.toContain('TOP-SECRET');
    expect(raw).not.toContain('clientSecret');
  });

  it('unlocks with the right PIN and reads back values', async () => {
    await vault.create('123456');
    await vault.set('creds', { a: 1 });
    vault.lock();
    expect(vault.unlocked).toBe(false);
    await expect(vault.get('creds')).rejects.toMatchObject({ code: 'locked' });
    await vault.unlock('123456');
    expect(await vault.get('creds')).toEqual({ a: 1 });
  });

  it('rejects a wrong PIN, counts attempts and throttles', async () => {
    await vault.create('123456');
    vault.lock();
    await expect(vault.unlock('000000')).rejects.toMatchObject({ code: 'bad-pin', attempts: 1, remaining: 3 });
    await expect(vault.unlock('000001')).rejects.toMatchObject({ code: 'bad-pin', attempts: 2 });
    await expect(vault.unlock('000002')).rejects.toMatchObject({ code: 'bad-pin', attempts: 3 });
    await expect(vault.unlock('123456')).rejects.toMatchObject({ code: 'throttled' });
  });

  it('wipes after too many failures', async () => {
    await vault.create('123456');
    vault.lock();
    for (let i = 0; i < 3; i++) await expect(vault.unlock('111111')).rejects.toMatchObject({ code: 'bad-pin' });
    await clearThrottle();
    await expect(vault.unlock('111111')).rejects.toMatchObject({ code: 'wiped' });
    expect(await vault.exists()).toBe(false);
  });

  it('a correct PIN resets the counter', async () => {
    await vault.create('123456');
    vault.lock();
    await expect(vault.unlock('000000')).rejects.toMatchObject({ attempts: 1 });
    await vault.unlock('123456');
    expect((await vault.status()).attempts).toBe(0);
  });

  it('changes the PIN and keeps data', async () => {
    await vault.create('123456');
    await vault.set('k', { v: 42 });
    await expect(vault.changePin('999999', '654321')).rejects.toMatchObject({ code: 'bad-pin' });
    await vault.changePin('123456', '654321');
    vault.lock();
    await expect(vault.unlock('123456')).rejects.toMatchObject({ code: 'bad-pin' });
    await vault.unlock('654321');
    expect(await vault.get('k')).toEqual({ v: 42 });
  });
});
