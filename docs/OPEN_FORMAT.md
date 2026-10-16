# Open, portable data

[Tiếng Việt](OPEN_FORMAT.vi.md)

SPECACT does not keep your data — **your Google Drive is the only place it is stored**, in the open format below. Any website or app you trust can read and write the same data source (with your own OAuth client and Drive permissions), so you can change *where you view* your content without migrating it and without lock-in.

## Sovereignty principles

1. **No middleman.** Browser ↔ Google Drive directly; there is no SPECACT server to store, read, moderate or alter data.
2. **Access is yours.** Who can see or comment is decided by your Drive permissions; revoke any time.
3. **Keys are yours.** Password-protected posts are encrypted client-side; the site host has no key.
4. **Open, versioned format** (`v`), documented here and in [ARCHITECTURE.md](ARCHITECTURE.md). Other apps that follow it are compatible.
5. **Self-hostable.** MIT source; run it from a static Nginx/Docker on your own machine.

> Honest limit: the *website* host serves the JavaScript; a malicious host could serve altered code on a later load. The remedy is to **self-host** (or use a build you verified) — see [SECURITY.md](SECURITY.md). Data stored on Google Drive remains subject to Google's terms.

## Minimal spec for other apps

- Root folder `SPECACT/` (property `specact=root`); posts in `SPECACT/posts/<date>_<id>/` (properties `specact=post`, `rev`, `pj`, `cj`, `lj`, `mf`).
- `post.json` (`v: 1`): `id, owner, createdAt, updatedAt, text, media[], mentions[], link{}, audience{}, linkShare, commentMode, cj, lj, protection`. Password-protected posts carry an AES-256-GCM `payload` (AAD `post:<id>`) with the content key wrapped by a PBKDF2-SHA256 key. Optional `link` is a link-preview card `{ url, title, description, site, image }`: `image` is the id of a file in the post's own `media/` folder, only `http(s)` URLs are accepted and every field is plain text — readers must never render it as HTML.
- `comments.json`: `{ v:1, comments[], likes[] }` (comments of protected posts carry `enc`; the `likes` array is legacy).
- `likes.json`: `{ v:1, likes[] }` — liking follows who may *see* the post, independent of the comment mode.
- Sharing = Drive permissions: *can view* = `reader` on the folder; *can comment* = also `writer` **on `comments.json` only**; liking = `writer` on `likes.json` for everyone who can see the post; public by link = `anyone` `reader` **on the files only** (`post.json`, photos), never on the folder.
- A post is identified by its folder id (people it was shared with) or by its `post.json` id (public link).
- Other apps **must** preserve unknown fields when rewriting `post.json` and must never open wider access than the user chose.
