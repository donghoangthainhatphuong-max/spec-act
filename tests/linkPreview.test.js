import { beforeEach, describe, expect, it, vi } from 'vitest';
import { FakeDrive } from './fakeDrive';

vi.mock('../src/config', async (orig) => {
  const mod = await orig();
  return { ...mod, config: { ...mod.config, pbkdf2Iterations: 1000, postKdfIterations: 1000, syncIntervalSeconds: 0, linkPreviewUrl: 'https://proxy.example/og?u={url}' } };
});
vi.mock('../src/services/image', () => ({
  prepareMedia: async (file) => ({
    kind: 'image', mime: 'image/jpeg', name: `${(file.name || 'p').replace(/\.[^.]+$/, '')}.jpg`,
    main: { blob: new Blob([new Uint8Array([0xff, 0xd8, ...new TextEncoder().encode(`MAIN-${file.name}`)])], { type: 'image/jpeg' }), w: 1600, h: 1200 },
    thumb: { blob: new Blob([new Uint8Array([0xff, 0xd8, 1])], { type: 'image/jpeg' }), w: 480, h: 360 },
  }),
}));

const { DriveClient } = await import('../src/services/drive');
const { DriveRepo } = await import('../src/services/repo');
const { vault } = await import('../src/services/secureStore');
const { cleanLink } = await import('../src/services/postModel');
const { fetchPreview, firstUrl, parseOpenGraph } = await import('../src/services/linkPreview');

const PAGE = `<!doctype html><html><head><title>Fallback title</title>
<meta property="og:title" content="  A great\u202E article  ">
<meta property="og:description" content="Line one
   line two">
<meta property="og:image" content="/cover.png">
<meta property="og:site_name" content="Example News">
<meta property="og:url" content="https://evil.example/phish">
<script>window.pwned = 1</script></head><body><img src=x onerror="window.pwned=2"></body></html>`;

let fake;
const mk = (email, name) => {
  const token = fake.addUser(email, name);
  return new DriveRepo({ drive: new DriveClient({ getToken: async () => token }), me: { email, name }, vault });
};

beforeEach(async () => {
  fake = new FakeDrive();
  globalThis.fetch = fake.fetch;
  URL.createObjectURL ||= () => 'blob:fake';
  URL.revokeObjectURL ||= () => {};
  await vault.create('123456');
});

describe('Open Graph parsing', () => {
  it('reads title, description, picture and site — as plain, cleaned text', () => {
    const { link, imageUrl } = parseOpenGraph(PAGE, 'https://news.example/a/b');
    expect(link.title).toBe('A great article');
    expect(link.description).toBe('Line one line two');
    expect(link.site).toBe('Example News');
    expect(imageUrl).toBe('https://news.example/cover.png');
    expect(globalThis.pwned).toBeUndefined(); // DOMParser never runs the page's scripts or handlers
  });

  it('always opens the address that was pasted, never one the page claims', () => {
    expect(parseOpenGraph(PAGE, 'https://news.example/a/b').link.url).toBe('https://news.example/a/b');
  });

  it('falls back to <title> and ignores pages that say nothing', () => {
    expect(parseOpenGraph('<title>Only title</title>', 'https://x.example/').link.title).toBe('Only title');
    expect(parseOpenGraph('<html><body>hi</body></html>', 'https://x.example/')).toBeNull();
  });

  it('finds the first link in a text', () => {
    expect(firstUrl('look https://a.example/x?y=1, and https://b.example')).toBe('https://a.example/x?y=1');
    expect(firstUrl('nothing here')).toBe('');
  });
});

describe('hostile cards are neutralised', () => {
  it('keeps http(s) only and limits text', () => {
    expect(cleanLink({ url: 'javascript:alert(1)', title: 'x' })).toBeNull();
    expect(cleanLink({ url: 'data:text/html,<script>', title: 'x' })).toBeNull();
    const c = cleanLink({ url: 'https://ok.example/', title: 'T'.repeat(999), description: 'a\u0000b\u202Ec', site: 's', image: '../../x' });
    expect(c.title).toHaveLength(200);
    expect(c.description).toBe('a b c');
    expect(c.image).toBeNull();
  });
});

describe('fetching through the configured service', () => {
  it('asks the service (not the site), without cookies or a referrer, and returns the card', async () => {
    const seen = [];
    globalThis.fetch = vi.fn(async (url, init) => {
      seen.push([String(url), init]);
      return String(url).startsWith('https://proxy.example/') ? new Response(PAGE, { status: 200 }) : new Response('no', { status: 404 });
    });
    const r = await fetchPreview('https://news.example/a/b?x=1');
    expect(seen[0][0]).toBe(`https://proxy.example/og?u=${encodeURIComponent('https://news.example/a/b?x=1')}`);
    expect(seen[0][1]).toMatchObject({ credentials: 'omit', referrerPolicy: 'no-referrer' });
    expect(r.link.title).toBe('A great article');
    expect(r.image).toBeNull(); // the picture could not be fetched: the card simply has none
  });

  it('is silent on failure', async () => {
    globalThis.fetch = vi.fn(async () => { throw new Error('offline'); });
    expect(await fetchPreview('https://news.example/')).toBeNull();
    expect(await fetchPreview('javascript:alert(1)')).toBeNull();
  });
});

describe('the card travels with the post', () => {
  const card = { url: 'https://news.example/a', title: 'Hello', description: 'World', site: 'News' };

  it('is stored in post.json, with its picture as a file of the post, and shown to people it is shared with', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'read this https://news.example/a', link: card, linkImage: { name: 'cover.png', type: 'image/png', size: 10 }, audience: { 'bob@gmail.com': 'view' } });
    expect(post.link).toMatchObject(card);
    expect(post.link.image).toBeTruthy();
    expect(post.media).toHaveLength(0); // the picture is not a gallery photo
    expect(fake.files.get(post.link.image).parents).toEqual([post.ids.mf]);

    const seen = await bob.openPost(post.id);
    expect(seen.link).toMatchObject(card);
    expect(await bob.mediaUrl(seen, { id: seen.link.image, thumb: null, mime: 'image/jpeg' })).toMatch(/^blob:/);
    const entry = (await alice.loadIndex()).mine.find((e) => e.id === post.id);
    expect(entry.link.title).toBe('Hello');
  });

  it('inside a password-protected post the card and its picture are sealed', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'secret', link: card, linkImage: { name: 'c.png', type: 'image/png', size: 1 }, password: 'hunter22' });
    const raw = JSON.stringify(fake.files.get(post.ids.pj).content ?? '');
    expect(raw).not.toContain('news.example');
    expect(fake.files.get(post.link.image).name).toMatch(/\.bin$/);
    const entry = (await alice.loadIndex()).mine.find((e) => e.id === post.id);
    expect(entry.link).toBeNull();
  });

  it('a public-by-link post opens the picture file too, never the folder', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'public', link: card, linkImage: { name: 'c.png', type: 'image/png', size: 1 }, linkShare: true });
    const anyoneOn = (id) => [...fake.files.get(id).perms.values()].some((p) => p.type === 'anyone');
    expect(anyoneOn(post.link.image)).toBe(true);
    expect(anyoneOn(post.id)).toBe(false);
    expect(anyoneOn(post.ids.cj)).toBe(false);
  });

  it('can be replaced or removed when editing', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'x', link: card, linkImage: { name: 'c.png', type: 'image/png', size: 1 } });
    const oldImage = post.link.image;
    const kept = (await alice.updatePost(post, { text: 'x2' })).post;
    expect(kept.link.image).toBe(oldImage); // untouched
    const removed = (await alice.updatePost(kept, { link: null })).post;
    expect(removed.link).toBeNull();
    expect(fake.files.has(oldImage)).toBe(false); // its picture is deleted with it
  });
});
