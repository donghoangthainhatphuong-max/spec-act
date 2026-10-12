import { beforeEach, describe, expect, it, vi } from 'vitest';
import { FakeDrive } from './fakeDrive';

vi.mock('../src/config', async (orig) => {
  const mod = await orig();
  return { ...mod, config: { ...mod.config, pbkdf2Iterations: 1000, postKdfIterations: 1000, syncIntervalSeconds: 0 } };
});
vi.mock('../src/services/image', () => ({
  prepareImage: async (file) => ({
    name: `${(file.name || 'p').replace(/\.[^.]+$/, '')}.jpg`,
    main: { blob: new Blob([new Uint8Array([0xff, 0xd8, ...new TextEncoder().encode(`MAIN-${file.name}`)])], { type: 'image/jpeg' }), w: 1600, h: 1200 },
    thumb: { blob: new Blob([new Uint8Array([0xff, 0xd8, ...new TextEncoder().encode(`THUMB-${file.name}`)])], { type: 'image/jpeg' }), w: 480, h: 360 },
  }),
}));

const { DriveClient } = await import('../src/services/drive');
const { DriveRepo } = await import('../src/services/repo');
const { vault } = await import('../src/services/secureStore');

let fake;
const mk = (email, name) => {
  const token = fake.addUser(email, name);
  const drive = new DriveClient({ getToken: async () => token });
  return new DriveRepo({ drive, me: { email, name }, vault });
};
const file = (name) => ({ name, type: 'image/jpeg', size: 10 });

beforeEach(async () => {
  fake = new FakeDrive();
  globalThis.fetch = fake.fetch;
  URL.createObjectURL ||= () => 'blob:fake';
  URL.revokeObjectURL ||= () => {};
  await vault.create('123456');
});

describe('layout', () => {
  it('creates SPECACT/posts once and reuses it', async () => {
    const a = mk('alice@gmail.com', 'Alice');
    const L = await a.ensureLayout();
    expect(fake.files.get(L.rootId).name).toBe('SPECACT');
    expect(fake.files.get(L.postsId).name).toBe('posts');
    const again = new DriveRepo({ drive: a.drive, me: { email: 'alice@gmail.com' }, vault });
    const L2 = await again.ensureLayout();
    expect(L2.rootId).toBe(L.rootId);
    expect(fake.find((f) => f.name === 'SPECACT')).toHaveLength(1);
  });
});

describe('posts and sharing', () => {
  it('stores each post in its own folder with post.json, comments.json and media/', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'Hello @bob@gmail.com', files: [file('a.jpg'), file('b.jpg')], audience: { 'bob@gmail.com': 'view' } });
    const folder = fake.files.get(post.id);
    expect(folder.parents).toEqual([(await alice.ensureLayout()).postsId]);
    const kids = fake.find((f) => f.parents.includes(post.id)).map((f) => f.name).sort();
    expect(kids).toEqual(['__S.P.E.C.T.A.C.T__ comments.json', '__S.P.E.C.T.A.C.T__ likes.json', 'media', 'post.json']);
    expect(folder.name).toMatch(/^__S\.P\.E\.C\.T\.A\.C\.T__ \d{4}-\d{2}-\d{2}_/);
    const media = fake.find((f) => f.parents.includes(post.ids.mf));
    expect(media).toHaveLength(4); // 2 photos + 2 thumbnails
    const doc = JSON.parse(fake.text(fake.files.get(post.ids.pj)));
    expect(doc.text).toBe('Hello @bob@gmail.com');
    expect(doc.mentions).toEqual(['bob@gmail.com']);
    expect(doc.audience).toEqual({ 'bob@gmail.com': 'view' });
    expect(folder.properties).toMatchObject({ specact: 'post', pj: post.ids.pj, cj: post.ids.cj, mf: post.ids.mf });
  });

  it('only people with a permission can read; viewers cannot write; commenters can write comments only', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const carol = mk('carol@gmail.com', 'Carol');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'secret-ish', files: [file('a.jpg')], audience: { 'bob@gmail.com': 'view', 'carol@gmail.com': 'comment' } });

    expect((await bob.openPost(post.id)).role).toBe('view');
    expect((await carol.openPost(post.id)).role).toBe('comment');
    await expect(dave.openPost(post.id)).rejects.toMatchObject({ code: 'forbidden' });

    const bobPost = await bob.openPost(post.id);
    await expect(bob.addComment(bobPost, 'hi')).rejects.toMatchObject({ code: 'forbidden' });
    const carolPost = await carol.openPost(post.id);
    const res = await carol.addComment(carolPost, 'nice @alice@gmail.com');
    expect(res.comments).toHaveLength(1);
    expect((await bob.loadComments(bobPost)).comments[0]).toMatchObject({ by: 'carol@gmail.com', text: 'nice @alice@gmail.com' });

    // carol must not be able to rewrite the post itself
    await expect(carol.drive.updateJson(post.ids.pj, { hacked: true })).rejects.toMatchObject({ status: 403 });
    // likes
    const liked = await carol.toggleLike(carolPost);
    expect(liked.likes).toEqual(['carol@gmail.com']);
    expect((await carol.toggleLike(carolPost)).likes).toEqual([]);
    // only the author of a comment or the post owner can delete it
    await expect(carol.deleteComment(carolPost, 'nope')).resolves.toBeTruthy();
    const cid = res.comments[0].id;
    expect((await alice.deleteComment(await alice.openPost(post.id), cid)).comments).toHaveLength(0);
  });

  it('builds a per-user index of shared posts and only re-downloads changed posts', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    await alice.createPost({ text: 'one', files: [file('a.jpg')], audience: { 'bob@gmail.com': 'view' } });
    const { post: second } = await alice.createPost({ text: 'two', files: [], audience: { 'bob@gmail.com': 'comment' } });
    await alice.createPost({ text: 'private', files: [], audience: {} });

    let idx = await bob.syncIndex();
    expect(idx.shared.map((e) => e.text).sort()).toEqual(['one', 'two']);
    expect(idx.mine).toHaveLength(0);
    expect(idx.shared[0].owner.email).toBe('alice@gmail.com');
    await bob.flush();
    const L = await bob.ensureLayout();
    expect(JSON.parse(fake.text(fake.files.get(L.indexId))).shared).toHaveLength(2);

    fake.log.length = 0;
    await bob.syncIndex();
    expect(fake.log.filter((l) => l.endsWith('alt=media'))).toHaveLength(0); // nothing changed => no content downloads

    // a new device with an empty local cache starts from the Drive copy of the index
    const fresh = new DriveRepo({ drive: bob.drive, me: { email: 'bob@gmail.com' }, vault });
    await vault.remove('index:bob@gmail.com');
    expect((await fresh.loadIndex()).shared).toHaveLength(2);

    // edit => rev bump => only that post re-downloaded
    const aliceFull = await alice.openPost(second.id);
    await alice.updatePost(aliceFull, { text: 'two (edited)', keepMedia: [], files: [] });
    fake.log.length = 0;
    idx = await bob.syncIndex();
    expect(fake.log.filter((l) => l.endsWith('alt=media'))).toHaveLength(1);
    expect(idx.shared.map((e) => e.text).sort()).toEqual(['one', 'two (edited)']);
  });

  it('changes roles, revokes access and removes the post from the viewer index', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'hi', files: [], audience: { 'bob@gmail.com': 'view' } });
    expect((await bob.openPost(post.id)).role).toBe('view');

    let r = await alice.setAccess(post, 'bob@gmail.com', 'comment');
    expect(r.warnings).toEqual([]);
    expect((await bob.openPost(post.id)).role).toBe('comment');

    r = await alice.setAccess(r.post, 'bob@gmail.com', 'view');
    expect((await bob.openPost(post.id)).role).toBe('view');

    const audience = await alice.readAudience(r.post);
    expect(audience.audience).toEqual({ 'bob@gmail.com': 'view' });

    await bob.syncIndex();
    expect((await bob.loadIndex()).shared).toHaveLength(1);
    await alice.setAccess(r.post, 'bob@gmail.com', null);
    await expect(bob.openPost(post.id)).rejects.toMatchObject({ code: 'forbidden' });
    expect((await bob.syncIndex()).shared).toHaveLength(0);
  });

  it('updates text and media, deleting files that are no longer referenced', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'v1', files: [file('a.jpg'), file('b.jpg')], audience: {} });
    const keep = post.media[1].id;
    const { post: next } = await alice.updatePost(post, { text: 'v2 @bob@gmail.com', keepMedia: [keep], files: [file('c.jpg')] });
    expect(next.media.map((m) => m.id)).toContain(keep);
    expect(next.media).toHaveLength(2);
    expect(fake.find((f) => f.parents.includes(post.ids.mf))).toHaveLength(4);
    expect(fake.files.has(post.media[0].id)).toBe(false);
    expect(next.mentions).toEqual(['bob@gmail.com']);
    expect((await alice.loadIndex()).mine[0].text).toContain('v2');
  });

  it('refuses edits from non-owners and respects the image limit', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'comment' } });
    const bobPost = await bob.openPost(post.id);
    await expect(bob.updatePost(bobPost, { text: 'hack' })).rejects.toMatchObject({ code: 'forbidden' });
    await expect(bob.deletePost(bobPost)).rejects.toMatchObject({ code: 'forbidden' });
    await expect(alice.createPost({ text: 'x', files: Array.from({ length: 11 }, (_, i) => file(`${i}.jpg`)), audience: {} })).rejects.toMatchObject({ code: 'too-many-images' });
  });

  it('deletes (trash) and rolls back failed creations', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'bye', files: [], audience: { 'bob@gmail.com': 'view' } });
    await bob.syncIndex();
    await alice.deletePost(post);
    expect(fake.files.get(post.id).trashed).toBe(true);
    expect((await alice.loadIndex()).mine).toHaveLength(0);
    expect((await bob.syncIndex()).shared).toHaveLength(0);

    // a failure half-way trashes the half-written folder
    const bad = mk('eve@gmail.com', 'Eve');
    const orig = bad.drive.createJson.bind(bad.drive);
    bad.drive.createJson = async (name, ...rest) => { if (name === 'post.json') throw new Error('boom'); return orig(name, ...rest); };
    await expect(bad.createPost({ text: 'x', files: [], audience: {} })).rejects.toThrow('boom');
    const L = await bad.ensureLayout();
    expect(fake.find((f) => f.parents.includes(L.postsId) && !f.trashed)).toHaveLength(0);
  });

  it('keeps going when one recipient cannot be added and reports it', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post, warnings } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view', 'not-an-email': 'view' } });
    expect(warnings.map((w) => w.email)).toEqual(['not-an-email']);
    expect(post.audience).toEqual({ 'bob@gmail.com': 'view' });
    const doc = JSON.parse(fake.text(fake.files.get(post.ids.pj)));
    expect(doc.audience).toEqual({ 'bob@gmail.com': 'view' });
  });
});

describe('sharing edge cases', () => {
  it('does not revoke people added through the Drive UI when changing someone else', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const carol = mk('carol@gmail.com', 'Carol');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: {} });
    await alice.drive.addPermission(post.id, { email: 'carol@gmail.com', role: 'reader' }); // shared by hand in Drive
    expect((await alice.readAudience(post)).audience).toEqual({ 'carol@gmail.com': 'view' });
    await alice.setAccess(post, 'bob@gmail.com', 'view');
    expect((await carol.openPost(post.id)).text).toBe('x');
    expect((await bob.openPost(post.id)).text).toBe('x');
  });

  it('editing a post keeps people shared by hand in Drive, but still honours removals the owner made', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const carol = mk('carol@gmail.com', 'Carol');
    const { post } = await alice.createPost({ text: 'v1', files: [], audience: { 'bob@gmail.com': 'view' } });
    await alice.drive.addPermission(post.id, { email: 'carol@gmail.com', role: 'reader' }); // by hand in Drive
    // the compose form only knows what the post listed
    const edited = await alice.updatePost(post, { text: 'v2', audience: { 'bob@gmail.com': 'view' }, keepMedia: [], files: [] });
    expect(edited.post.audience).toEqual({ 'bob@gmail.com': 'view', 'carol@gmail.com': 'view' });
    expect((await carol.openPost(post.id)).text).toBe('v2');
    // removing someone the post did list really revokes them
    await alice.updatePost(edited.post, { text: 'v3', audience: { 'carol@gmail.com': 'view' }, keepMedia: [], files: [] });
    await expect(bob.openPost(post.id)).rejects.toMatchObject({ code: 'forbidden' });
    // a text-only update never touches permissions
    await alice.drive.addPermission(post.id, { email: 'bob@gmail.com', role: 'reader' });
    await alice.updatePost(edited.post, { text: 'v4', keepMedia: [], files: [] });
    expect((await bob.openPost(post.id)).text).toBe('v4');
  });

  it('never records access in post.json that Drive refused to grant', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: {} });
    const { post: next, warnings } = await alice.setAccess(post, 'not-an-email', 'view');
    expect(warnings.map((w) => w.email)).toEqual(['not-an-email']);
    expect(next.audience).toEqual({});
    expect(JSON.parse(fake.text(fake.files.get(post.ids.pj))).audience).toEqual({});
  });

  it('falls back to client-side filtering if Drive rejects the properties filter', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    await alice.createPost({ text: 'visible', files: [], audience: { 'bob@gmail.com': 'view' } });
    const stray = await alice.drive.createFolder('holiday photos', 'root');
    await alice.drive.addPermission(stray.id, { email: 'bob@gmail.com', role: 'reader' });
    const orig = fake.fetch;
    globalThis.fetch = async (url, init) => {
      const u = decodeURIComponent(String(url));
      if (u.includes('/drive/v3/files?') && u.includes('sharedWithMe') && u.includes('properties has')) {
        return new Response(JSON.stringify({ error: { code: 400, message: 'Invalid Value', errors: [{ reason: 'invalid' }] } }), { status: 400 });
      }
      return orig(url, init);
    };
    const idx = await bob.syncIndex();
    expect(idx.shared.map((e) => e.text)).toEqual(['visible']); // the unrelated shared folder is ignored
  });

  it('treats a trashed post as gone', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view' } });
    await alice.deletePost(post);
    await expect(bob.openPost(post.id)).rejects.toMatchObject({ code: 'not-found' });
  });
});

describe('password protected posts', () => {
  it('seals text, comments and media; only the password opens them', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({
      text: 'the-launch-codes-are-in-the-drawer', files: [file('plan.jpg')], audience: { 'bob@gmail.com': 'comment' }, password: 'open-sesame',
    });
    expect(post.protected).toBe(true);
    expect(post.text).toBe('the-launch-codes-are-in-the-drawer');

    // nothing readable at rest in Drive
    expect(fake.allBytesContain('launch-codes')).toBe(false);
    expect(fake.allBytesContain('plan')).toBe(false);
    expect(fake.allBytesContain('MAIN-plan')).toBe(false);
    const entry = (await alice.loadIndex()).mine[0];
    expect(entry.text).toBe('');
    expect(entry.media).toEqual([]);

    const locked = await bob.openPost(post.id);
    expect(locked.locked).toBe(true);
    expect(locked.text).toBe('');
    await expect(bob.unlockAndOpen(post.id, 'wrong')).rejects.toMatchObject({ code: 'wrong-password' });
    const open = await bob.unlockAndOpen(post.id, 'open-sesame');
    expect(open.locked).toBe(false);
    expect(open.text).toBe('the-launch-codes-are-in-the-drawer');

    const url = await bob.mediaUrl(open, open.media[0]);
    expect(url).toBeTruthy();

    const withComment = await bob.addComment(open, 'sealed reply');
    expect(withComment.comments[0].text).toBe('sealed reply');
    expect(fake.allBytesContain('sealed reply')).toBe(false);
    expect((await alice.loadComments(await alice.openPost(post.id))).comments[0].text).toBe('sealed reply');
  });

  it('the owner keeps access on the same device but a fresh repo needs the password', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const { post } = await alice.createPost({ text: 'mine', files: [], audience: {}, password: 'pw' });
    const again = new DriveRepo({ drive: alice.drive, me: { email: 'alice@gmail.com' }, vault });
    await again.restoreKeys();
    expect((await again.openPost(post.id)).text).toBe('mine');
    await vault.remove('postkeys:alice@gmail.com');
    const other = new DriveRepo({ drive: alice.drive, me: { email: 'alice@gmail.com' }, vault });
    expect((await other.openPost(post.id)).locked).toBe(true);
  });

  it('changing the password keeps old content readable and invalidates the old password', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'rotate me', files: [file('a.jpg')], audience: { 'bob@gmail.com': 'view' }, password: 'old' });
    const { post: next } = await alice.updatePost(post, { text: 'rotate me', newPassword: 'new', keepMedia: post.media.map((m) => m.id), files: [] });
    await expect(bob.unlockAndOpen(post.id, 'old')).rejects.toMatchObject({ code: 'wrong-password' });
    const open = await bob.unlockAndOpen(post.id, 'new');
    expect(open.text).toBe('rotate me');
    expect(open.media).toHaveLength(1);
    expect(next.protected).toBe(true);
  });

  it('link sharing opens FILES only (post.json + photos), never the folder or comments', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const dave = mk('dave@gmail.com', 'Dave');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'for everyone', files: [file('a.jpg')], audience: {}, linkShare: true });
    expect(post.linkShare).toBe(true);

    const anyoneOn = (id) => [...fake.files.get(id).perms.values()].some((p) => p.type === 'anyone');
    expect(anyoneOn(post.id)).toBe(false); // folder
    expect(anyoneOn(post.ids.mf)).toBe(false); // media folder
    expect(anyoneOn(post.ids.cj)).toBe(false); // comments
    expect(anyoneOn(post.ids.pj)).toBe(true);
    expect(post.media.every((m) => anyoneOn(m.id) && anyoneOn(m.thumb))).toBe(true);

    await expect(dave.openPost(post.id)).rejects.toMatchObject({ code: 'forbidden' }); // folder id: no access
    const open = await dave.openPost(post.ids.pj); // link id: the public file
    expect(open.text).toBe('for everyone');
    expect(open.role).toBe('view');
    expect(open.ids.cj).toBeNull();
    expect(await dave.mediaUrl(open, open.media[0])).toBeTruthy();
    expect((await dave.loadComments(open)).comments).toEqual([]);
    const seen = (await dave.drive.list({ q: `'${post.id}' in parents and trashed = false` })).map((f) => f.name);
    expect(seen.sort()).toEqual(['__S.P.E.C.T.A.C.T__ likes.json', 'post.json']); // only public files show up: no comments.json, no media folder
    await expect(dave.drive.get(post.id)).rejects.toMatchObject({ status: 403 });
    expect((await dave.loadIndex()).shared[0]).toMatchObject({ id: post.ids.pj, via: 'link' });
    // the owner following their own link lands on the real post
    expect((await alice.openPost(post.ids.pj)).id).toBe(post.id);
    expect((await bob.syncIndex()).shared).toHaveLength(0);

    // photos added later are opened too; turning it off closes everything again
    const grown = await alice.updatePost(post, { keepMedia: post.media.map((m) => m.id), files: [file('b.jpg')] });
    expect(grown.post.media.every((m) => anyoneOn(m.id))).toBe(true);
    const off = await alice.setLinkShare(grown.post, false);
    expect(off.linkShare).toBe(false);
    expect(anyoneOn(post.ids.pj) || off.media.some((m) => anyoneOn(m.id))).toBe(false);
    await expect(dave.openPost(post.ids.pj)).rejects.toMatchObject({ code: 'forbidden' });
  });

  it('a protected post opened through its public file still needs the password', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'via link', files: [file('a.jpg')], audience: {}, password: 'pw', linkShare: true });
    expect((await dave.openPost(post.ids.pj)).locked).toBe(true);
    await expect(dave.unlockAndOpen(post.ids.pj, 'bad')).rejects.toMatchObject({ code: 'wrong-password' });
    const open = await dave.unlockAndOpen(post.ids.pj, 'pw');
    expect(open.text).toBe('via link');
    expect(await dave.mediaUrl(open, open.media[0])).toBeTruthy();
  });
});

describe('comment modes', () => {
  const tryComment = (repo, post, text = 'hi') => repo.addComment(post, text).then(() => 'ok', (e) => e.code);

  it('shared (default): only "can comment" people write; link visitors only read', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const carol = mk('carol@gmail.com', 'Carol');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view', 'carol@gmail.com': 'comment' }, linkShare: true });
    expect(post.commentMode).toBe('shared');
    expect(await tryComment(bob, await bob.openPost(post.id))).toBe('forbidden');
    expect(await tryComment(carol, await carol.openPost(post.id))).toBe('ok');
    const pub = await dave.openPost(post.ids.pj);
    expect(pub.role).toBe('view');
    expect(pub.ids.cj).toBeNull();
  });

  it('open: everyone who can see the post may comment, including link visitors — still without the folder', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view' }, linkShare: true, commentMode: 'open' });
    expect(await tryComment(bob, await bob.openPost(post.id))).toBe('ok');
    const pub = await dave.openPost(post.ids.pj);
    expect(pub.role).toBe('comment');
    expect(await tryComment(dave, pub, 'from a stranger')).toBe('ok');
    expect((await alice.loadComments(post)).comments.map((c) => c.by).sort()).toEqual(['bob@gmail.com', 'dave@gmail.com']);
    await expect(dave.drive.get(post.id)).rejects.toMatchObject({ status: 403 }); // folder stays private
    await expect(dave.drive.updateJson(post.ids.pj, { hacked: true })).rejects.toMatchObject({ status: 403 }); // post.json read-only
  });

  it('switching modes re-applies permissions: locked blocks everybody, then shared / open restore', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const carol = mk('carol@gmail.com', 'Carol');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view', 'carol@gmail.com': 'comment' }, linkShare: true });
    await carol.addComment(await carol.openPost(post.id), 'before lock');

    let cur = await alice.setCommentMode(post, 'locked');
    expect(cur.commentMode).toBe('locked');
    const carolLocked = await carol.openPost(post.id);
    expect(carolLocked.role).toBe('view');
    expect(await tryComment(carol, { ...carolLocked, role: 'comment', commentMode: 'shared' })).toBe('forbidden'); // Drive refuses even a stale client
    expect(await tryComment(alice, cur)).toBe('comments-locked');
    expect((await alice.toggleLike(cur)).likes).toEqual(['alice@gmail.com']); // likes are not comments: locking comments leaves them alone
    expect((await bob.loadComments(await bob.openPost(post.id))).comments).toHaveLength(1); // still readable
    const first = (await alice.loadComments(cur)).comments[0];
    expect((await alice.deleteComment(cur, first.id)).comments).toHaveLength(0); // owner can still moderate

    cur = await alice.setCommentMode(cur, 'shared');
    expect((await carol.openPost(post.id)).role).toBe('comment'); // level remembered
    expect((await bob.openPost(post.id)).role).toBe('view');

    cur = await alice.setCommentMode(cur, 'open');
    expect((await bob.openPost(post.id)).role).toBe('comment');
    expect((await dave.openPost(post.ids.pj)).role).toBe('comment');
    await alice.setLinkShare(cur, false); // no link, no stranger writing
    await expect(dave.openPost(post.ids.pj)).rejects.toMatchObject({ code: 'forbidden' });
    expect((await bob.openPost(post.id)).role).toBe('comment');
  });
});

describe('grouping shared posts under SPECACT/shared', () => {
  it('creates one branded shortcut per shared post, keeps them in step, and never duplicates', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const a = await alice.createPost({ text: 'one', files: [], audience: { 'bob@gmail.com': 'view' } });
    await alice.createPost({ text: 'two', files: [], audience: { 'bob@gmail.com': 'view' } });
    await alice.createPost({ text: 'private', files: [], audience: {} });
    await bob.syncIndex();
    const L = await bob.ensureLayout();
    const list = () => fake.find((f) => f.parents.includes(L.sharedId) && f.mimeType === 'application/vnd.google-apps.shortcut');
    expect(fake.files.get(L.sharedId).name).toBe('shared');
    expect(fake.files.get(L.sharedId).parents).toEqual([L.rootId]);
    expect(list()).toHaveLength(2);
    expect(list().every((s) => s.name.startsWith('__S.P.E.C.T.A.C.T__ Alice · '))).toBe(true);
    expect(list().map((s) => s.shortcutDetails.targetId)).toContain(a.post.id);
    await bob.syncIndex(); // idempotent
    expect(list()).toHaveLength(2);
    // access removed -> its shortcut goes away; unrelated things in the folder stay
    await bob.drive.createFolder('my own folder', L.sharedId);
    await alice.setAccess(a.post, 'bob@gmail.com', null);
    await bob.syncIndex();
    expect(list()).toHaveLength(1);
    expect(fake.find((f) => f.name === 'my own folder')).toHaveLength(1);
  });
});

describe('likes', () => {
  const likeBy = (repo, post) => repo.toggleLike(post).then((r) => r.likes, (e) => e.code);

  it('follow who the post is open to: view-only people like, strangers cannot, whatever the comment mode', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const eve = mk('eve@gmail.com', 'Eve');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view' }, commentMode: 'locked' });
    const bobPost = await bob.openPost(post.id);
    expect(bobPost.role).toBe('view');
    expect(await likeBy(bob, bobPost)).toEqual(['bob@gmail.com']);
    expect(await likeBy(alice, await alice.openPost(post.id))).toEqual(['bob@gmail.com', 'alice@gmail.com']);
    expect((await bob.loadComments(bobPost)).likes).toEqual(['bob@gmail.com', 'alice@gmail.com']);
    expect(await likeBy(bob, bobPost)).toEqual(['alice@gmail.com']); // unlike
    await expect(eve.openPost(post.id)).rejects.toMatchObject({ code: 'forbidden' });
    expect(await likeBy(eve, { id: post.id, ids: post.ids, protected: false })).toBe('forbidden'); // no permission on likes.json
    // the like file never gives write access to the post or the comments
    await expect(bob.drive.updateJson(post.ids.pj, {})).rejects.toMatchObject({ status: 403 });
    await expect(bob.drive.updateJson(post.ids.cj, {})).rejects.toMatchObject({ status: 403 });
  });

  it('are removed with the person, and opened to link visitors only on public posts', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const dave = mk('dave@gmail.com', 'Dave');
    const { post } = await alice.createPost({ text: 'x', files: [], audience: { 'bob@gmail.com': 'view' }, linkShare: true });
    const pub = await dave.openPost(post.ids.pj);
    expect(pub.ids.lj).toBe(post.ids.lj);
    expect(await likeBy(dave, pub)).toEqual(['dave@gmail.com']);
    const off = await alice.setLinkShare(post, false);
    expect(await likeBy(dave, pub)).toBe('forbidden');
    const cur = (await alice.setAccess(off, 'bob@gmail.com', null)).post;
    expect(await likeBy(bob, { id: post.id, ids: post.ids })).toBe('forbidden');
    expect(cur.audience).toEqual({});
  });

  it('posts made before likes.json get one (with the old likes) when the owner next opens them', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    const bob = mk('bob@gmail.com', 'Bob');
    const { post } = await alice.createPost({ text: 'old', files: [], audience: { 'bob@gmail.com': 'view' } });
    // simulate the previous layout: no likes.json, likes kept in comments.json
    fake.files.delete(post.ids.lj);
    const f = fake.files.get(post.id);
    delete f.properties.lj;
    const doc = JSON.parse(fake.text(fake.files.get(post.ids.pj)));
    delete doc.lj;
    fake.files.get(post.ids.pj).content = new TextEncoder().encode(JSON.stringify(doc));
    fake.files.get(post.ids.cj).content = new TextEncoder().encode(JSON.stringify({ v: 1, comments: [], likes: ['carol@gmail.com'] }));

    const before = await bob.openPost(post.id);
    expect(before.ids.lj).toBeFalsy();
    expect(await likeBy(bob, before)).toBe('forbidden'); // not possible until the owner migrates it

    const mine = await alice.openPost(post.id);
    expect(mine.ids.lj).toBeTruthy();
    expect((await alice.loadComments(mine)).likes).toEqual(['carol@gmail.com']);
    const after = await bob.openPost(post.id);
    expect(await likeBy(bob, after)).toEqual(['carol@gmail.com', 'bob@gmail.com']);
  });
});

describe('contacts', () => {
  it('persist to Drive and to the local vault', async () => {
    const alice = mk('alice@gmail.com', 'Alice');
    await alice.saveContacts([{ email: 'bob@gmail.com', name: 'Bob', addedAt: 1 }]);
    const other = new DriveRepo({ drive: alice.drive, me: { email: 'alice@gmail.com' }, vault });
    await vault.remove('contacts:alice@gmail.com');
    expect(await other.loadContacts()).toEqual([{ email: 'bob@gmail.com', name: 'Bob', addedAt: 1 }]);
  });
});
