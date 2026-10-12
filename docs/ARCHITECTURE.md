# Architecture

[Tiếng Việt](ARCHITECTURE.vi.md)

## Principles

1. **No backend.** The page is static. After loading, the browser only calls `accounts.google.com`, `oauth2.googleapis.com` and `www.googleapis.com` (the CSP in `docker/security-headers.conf` enforces this).
2. **Google Drive is the source of truth** for data *and* access. The app does not invent a separate permission system.
3. **Everything sensitive on the device** lives in the doubly-encrypted vault (see [SECURITY.md](SECURITY.md)).

## Drive layout

```
SPECACT/                         properties: specact=root
├── index.json                   personal index (my posts + shared with me)
├── contacts.json                connected people
├── shared/                      one branded Drive shortcut per post shared with me
│   └── __S.P.E.C.T.A.C.T__ Alice · 2026-10-12   →  Alice's post folder
└── posts/                       properties: specact=posts
    └── __S.P.E.C.T.A.C.T__ 2026-10-12_ab12cd34ef/   properties: specact=post, rev, pj, cj, lj, mf
        ├── post.json
        ├── __S.P.E.C.T.A.C.T__ comments.json
        ├── __S.P.E.C.T.A.C.T__ likes.json           {v:1, likes:[email]}
        └── media/
            ├── ab12cd34ef_photo.jpg      resized photo
            ├── ab12cd34ef_t.jpg          thumbnail
            └── ab12cd34ef_clip.webm      video (poster = its thumbnail)
```

`properties` (not `appProperties`) are used because `appProperties` are only visible to the *same OAuth client* — and every person has their own.

A post folder carries `pj`/`cj`/`lj`/`mf` (ids of `post.json`, `comments.json`, `likes.json`, `media/`) and `rev` (update stamp). One metadata listing tells which posts changed, and the needed files are fetched directly.

### `post.json` (v1)

```jsonc
{
  "v": 1, "id": "ab12cd34ef",
  "owner": { "email": "an@gmail.com", "name": "An" },
  "createdAt": 1790000000000, "updatedAt": 1790000000000,
  "text": "…", "mentions": ["binh@gmail.com"],
  "media": [{ "id": "<fileId>", "thumb": "<fileId>", "name": "a.jpg", "mime": "image/jpeg", "w": 2048, "h": 1365, "size": 412345 }],
  "audience": { "binh@gmail.com": "view", "chi@gmail.com": "comment" },  // mirror; the truth is the Drive permissions
  "linkShare": false, "commentMode": "shared", "cj": "<fileId>", "lj": "<fileId>",
  "protection": null
}
```

For **password-protected** posts `text`, `mentions` and `media` move into `payload` (AES-256-GCM, AAD `post:<id>`); `protection` = `{ kdf: "PBKDF2-SHA256", iter, salt, wrap }` where `wrap` is the random *content key* wrapped by a password-derived key. Changing the password re-wraps 32 bytes and never touches the photos. Photo bytes are encrypted separately (AAD `media:<id>`) and stored under random `*.bin` names.

A media item with `kind: "video"` also carries `duration` (seconds) and a `mime` such as `video/webm` or `video/mp4`; its `thumb` is a poster frame. Videos are stored as recorded (no transcoding) and uploaded with Drive's resumable protocol above 4 MB; in protected posts their bytes are sealed like photos.

### `comments.json` / `likes.json`

```jsonc
{ "v": 1, "comments": [{ "id": "…", "by": "chi@gmail.com", "name": "Chi", "at": 1790000000000, "text": "…" }], "likes": [] }
{ "v": 1, "likes": ["chi@gmail.com"] }
```
Comments of protected posts carry `enc` instead of `text`. Likes live in `likes.json`; older posts get the file (carrying their old likes over) the first time the owner opens them.

### `index.json`

```jsonc
{ "v": 1, "owner": "an@gmail.com", "updatedAt": …, "syncedAt": …, "mine": [ /* entry */ ], "shared": [ /* entry */ ] }
// entry = id(folderId), pid, owner, createdAt, updatedAt, rev, protected, linkShare, commentMode,
//         text(snippet ≤600), truncated, mediaCount, media(≤3), audience(≤12), ids{pj,cj,lj,mf}, via?
```
Protected posts **never** have content in the index.

## Keeping Drive tidy

Everything SPECACT creates that other people may see carries the prefix `__S.P.E.C.T.A.C.T__` (post folders, `comments.json`, `likes.json`), so it is easy to recognise and search in Drive's "Shared with me". A person cannot move someone else's shared folder into their own tree, so on every index sync SPECACT creates a **Drive shortcut** per shared post inside `SPECACT/shared/` (named `__S.P.E.C.T.A.C.T__ <owner> · <date>`) and removes it when access ends. Everything shared with you is then reachable under your own `SPECACT` folder. Shortcuts are a convenience: failures never break a sync, and `VITE_GROUP_SHARED=false` turns the feature off. Drive still lists the shared files themselves (the post folder, `comments.json`, `likes.json`) under "Shared with me" — the prefix makes them easy to find or filter, but Drive offers no API to hide them.

## Permission model

| Who | Drive permission |
|---|---|
| Owner | owner of the tree |
| **Can view** | `reader` on the post folder (inherited by `post.json`, `comments.json`, `media/*`) |
| **Can comment** | `reader` on the folder + `writer` **on `comments.json` only** (never `post.json`) |
| **Like** | `writer` **on `likes.json` only** for everyone who can see the post, in every comment mode; `anyone` `writer` on it only when the post is public by link |
| **Anyone with the link** | `anyone` `reader` **on the files** (`post.json`, photos) — never on the folder or `comments.json` |

Comment modes: **open** (everyone who can see the post, link visitors included when public), **shared** (default: only "can comment" people), **locked** (nobody; writer permissions on `comments.json` are removed in Drive).

An `@email` in the text adds that person to the audience (*can view*). Removing a mention does **not** revoke access — revocation is always an explicit action. Before every sharing change the app reads the *real* permissions from Drive, so people added by hand in the Drive UI are not revoked by accident and `post.json.audience` never records access Drive refused.

## Index sync

1. On open, paint the index from the encrypted cache (or `index.json` from Drive on a new device).
2. In the background list folder metadata of `posts/` (mine) and `sharedWithMe = true` filtered by `properties has {specact=post}` — one request per ~200 posts.
3. Compare `rev` with the index; **download `post.json` only for new/changed posts** (4 in parallel).
4. Posts that disappeared (access removed / trashed) are dropped; link-opened posts are kept while they resolve.
5. Save the local cache (encrypted) and push `index.json` to Drive (debounced, skipped when unchanged).

Comments and likes do **not** bump `rev`; cards lazily load them when they scroll into view.

## Code map

- `services/repo.js` — all Drive business logic (`DriveRepo`); `services/demoRepo.js` has the same interface for demo mode.
- `services/drive.js` — REST client: bearer token, one refresh on 401, back-off on 429/5xx, concurrency cap 6.
- `services/googleAuth.js` — OAuth *authorization code + PKCE (S256)*, `state` against CSRF, code exchange directly with `oauth2.googleapis.com` using the user's own secret.
- `stores/session.js` — state machine `booting → no-vault | locked → signed-out → ready`.
