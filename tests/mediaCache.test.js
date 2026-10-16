import { beforeEach, describe, expect, it, vi } from 'vitest';
import { FakeDrive } from './fakeDrive';

vi.mock('../src/config', async (orig) => {
  const mod = await orig();
  return { ...mod, config: { ...mod.config, pbkdf2Iterations: 1000, postKdfIterations: 1000, syncIntervalSeconds: 0 } };
});
vi.mock('../src/services/image', () => ({
  prepareMedia: async (file) => ({
    kind: 'image', mime: 'image/jpeg', name: `${(file.name || 'p').replace(/\.[^.]+$/, '')}.jpg`,
    main: { blob: new Blob([new Uint8Array([0xff, 0xd8, ...new TextEncoder().encode(`MAIN-${file.name}`)])], { type: 'image/jpeg' }), w: 1600, h: 1200 },
    thumb: { blob: new Blob([new Uint8Array([0xff, 0xd8, 1, 2, 3])], { type: 'image/jpeg' }), w: 480, h: 360 },
  }),
}));

const { DriveClient } = await import('../src/services/drive');
const { DriveRepo } = await import('../src/services/repo');
const { vault } = await import('../src/services/secureStore');
const { cacheClear, cacheGet, cachePut } = await import('../src/services/mediaCache');

// a tiny in-memory Cache Storage
function installCaches() {
  const stores = new Map();
  globalThis.caches = {
    open: async (name) => {
      if (!stores.has(name)) stores.set(name, new Map());
      const m = stores.get(name);
      return {
        match: async (r) => { const b = m.get(r.url); return b ? new Response(b.slice(0)) : undefined; },
        put: async (r, res) => { m.set(r.url, await res.arrayBuffer()); },
        keys: async () => [...m.keys()].map((u) => new Request(u)),
        delete: async (r) => m.delete(r.url),
      };
    },
    delete: async (name) => stores.delete(name),
    _stores: stores,
  };
}

let fake;
beforeEach(async () => {
  fake = new FakeDrive();
  globalThis.fetch = fake.fetch;
  URL.createObjectURL = () => 'blob:fake';
  URL.revokeObjectURL ||= () => {};
  installCaches();
  await vault.create('123456');
});

describe('media cache', () => {
  it('keeps bytes encrypted and returns them while the vault is unlocked', async () => {
    await cachePut('file1', new Uint8Array([1, 2, 3, 4]));
    const raw = new Uint8Array([...globalThis.caches._stores.get('specact-media-v1').values()][0]);
    expect([...raw]).not.toEqual([1, 2, 3, 4]); // sealed, not the plain photo
    expect([...(await cacheGet('file1'))]).toEqual([1, 2, 3, 4]);
    vault.lock();
    expect(await cacheGet('file1')).toBeNull(); // a locked app cannot read it
    await vault.unlock('123456');
    await cacheClear();
    expect(await cacheGet('file1')).toBeNull();
  });
});

describe('photo loading', () => {
  it('downloads a photo once, then serves it from the device — always with the Authorization header (Google refuses query tokens)', async () => {
    const token = fake.addUser('alice@gmail.com', 'Alice');
    const seen = [];
    const realFetch = globalThis.fetch;
    globalThis.fetch = vi.fn(async (url, init) => { seen.push([String(url), init]); return realFetch(url, init); });
    const repo = new DriveRepo({ drive: new DriveClient({ getToken: async () => token }), me: { email: 'alice@gmail.com', name: 'Alice' }, vault });
    const { post } = await repo.createPost({ text: 'x', files: [{ name: 'a.jpg', type: 'image/jpeg', size: 10 }] });
    seen.length = 0;

    repo.blobs.clear();
    await repo.mediaUrl(post, post.media[0], { thumb: true });
    const dl = seen.filter(([u]) => u.includes('alt=media'));
    expect(dl).toHaveLength(1);
    expect(dl[0][0]).not.toContain('access_token=');
    expect(dl[0][1].headers.Authorization).toMatch(/^Bearer /);

    await new Promise((r) => setTimeout(r, 30)); // the copy is written in the background
    repo.blobs.clear(); // e.g. after a reload: only the on-device copy remains
    await repo.mediaUrl(post, post.media[0], { thumb: true });
    expect(seen.filter(([u]) => u.includes('alt=media'))).toHaveLength(1); // not downloaded again
  });
});
