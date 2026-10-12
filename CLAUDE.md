# CLAUDE.md — working rules for the SPECACT project

[Tiếng Việt](CLAUDE.vi.md) — keep both files in sync (the English one is the reference).

Read everything before changing code. Each rule below exists because a real mistake happened. When you meet a new mistake, **add a rule here in the same commit that fixes it**.

## 1. Product invariants (never break)

1. **No backend.** The browser only talks to `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`. Do not add CDNs, analytics, external fonts or any other endpoint (the CSP in `docker/security-headers.conf` blocks them; change the CSP only when truly needed and say why).
2. **Drive is the source of truth for data and access.** Do not invent a separate permission system. `post.json.audience` is only a mirror for display.
3. **Every client-side secret** (client ID/secret, refresh token, post keys, index cache) lives only in `services/secureStore.js` (two layers: device key + PIN). Never write them to `localStorage`, URLs, logs or `.env`. The access token stays in memory.
4. **Public-by-link grants permission on FILES only** (`post.json` + photos) — **never on the folder** and never on `comments.json`. Keep the test "link sharing opens FILES only" green.
5. **People who may comment get `writer` on `comments.json` only**, never on the folder or `post.json`.
6. Password-protected posts: content, comments and photo bytes are encrypted on the client; **never put content in `index.json`**.
7. No `v-html` / `innerHTML` with user data. Text is rendered through `RichText.vue` (safe text/mention/link segments).
8. Deleting / revoking / overwriting access must be **explicit**: removing an `@mention` does not revoke access; editing must not revoke people shared by hand in Drive (see `updatePost` / `setAccess`).
9. **Branding:** emphasise personalisation, data sovereignty, decentralisation / cross-platform use. Do **not** claim "no ads / no tracking" in the UI or docs (ads may come later). Never add any mechanism that lets the provider interfere with user data; keep the data format open and versioned ([docs/OPEN_FORMAT.md](docs/OPEN_FORMAT.md)).
10. When data / privacy / sharing behaviour changes, update `src/locales/pages/*.json` (Terms / Privacy / About, both `en` and `vi`, same structure — `tests/pages.test.js`) in the same commit.
13. **Media items** carry `kind` (`image` default, `video`) via `publicMedia()`; any code that renders or uploads media must handle both (feed grid, viewer, composer previews, demo repo, protected posts).
12. **Naming:** everything SPECACT creates in Drive that others can see uses the `__S.P.E.C.T.A.C.T__` prefix (`brandName()` in `postModel.js`). Lookups must accept both prefixed and older plain names.
11. **Liking follows who can see the post, not who can comment.** Likes live in their own `likes.json` (writer for everyone who can see the post, no other rights). Do not move likes back into `comments.json`.

## 2. Mistakes made → rules

| What went wrong | Rule |
|---|---|
| `ui.openViewer(items, index)` was called with an object `{post, items}` → the photo viewer opened **empty**, no slideshow. Only the demo was eyeballed, so it slipped through. | When changing the signature of a shared function, `grep` every caller and update them. Every store action needs a unit test (`tests/ui.test.js` is an example). When touching UI, **open the browser and use it** (click a photo, next/prev, zoom), don't just build/test. |
| Next/prev buttons were pushed to the top corner by the old design CSS `.viewer .icon-btn {top:16px}`. | The design's global CSS (`src/styles/*.css`) outranks scoped CSS. Overlay styles need specific selectors (`.viewer .icon-btn.nav`) and **positions must be measured with `getBoundingClientRect`** after the change. |
| Public sharing first required a password and then granted `anyone` on the **folder** → exposed structure/comments. | Grant public access at the minimum scope (individual files). Before adding any Drive permission, state who / which object / which level, and write a test for what must NOT be opened. |
| A feature was added to the detail screen but forgotten on the compose screen. | A feature touching several flows (create / edit / detail / demo) must be added to **all** of `ComposeView`, `PostView`, `repo.js` **and** `demoRepo.js`, and listed in the commit message. |
| Saving the audience from a form revoked people shared by hand in Drive. | Never infer permissions from the `post.json` mirror; read the truth with `readAudience`. Only touch permissions when the caller passes `audience`. |
| `expireSession` ran asynchronously without `await` → briefly wrong UI state (a test caught it). | Every auth state transition must be awaited before the calling function returns. |
| vue-i18n treats `@` in a message as link syntax → the app crashed on load. | Use the in-house i18n layer (`src/i18n`); translations are flat JSON with `{name}` only. Do not bring vue-i18n back. |
| Comment permissions depend on several states (role, comment mode, public link). | Any change that affects who may write `comments.json` must go through `#syncCommenting` / `canCommentWith` and be covered by `describe('comment modes')`. Locking comments must be enforced in **Drive** (remove write access), not just by hiding a button. |
| The camera dialog's controls were squashed off-screen: its generic class names (`.bar`, `.top`, `.row`…) collided with the design's global CSS (`.bar` = 6 px progress bar, `.top` = mobile header). | Component-specific classes must be prefixed (`cam-…`, `viewer …`); before naming a class, `grep` `src/styles/*.css`. Full-screen overlays use `Teleport to="body"`, `100svh`, and are verified at a small viewport (375×640) by measuring every control with `getBoundingClientRect`. |
| `docker compose` used the container/image name `specact`, clashing with another project of the user. | This project's Docker names are always `spec-act`; never touch other containers/images (`docker ps` first). Default port 8088. |
| `FakeDrive` first used `Buffer` → it could not run in a browser. | Code shared between Node and the browser must not use Node-only APIs. |

## 3. Required workflow for every change

1. **Understand first**: read the files and their callers (`grep`); don't guess.
2. **Write / update tests together with the code.** Drive / permission logic → add cases to `tests/repo.test.js` (using `tests/fakeDrive.js`). If real Drive behaves differently from the fake, fix the fake first.
3. Run everything: `npm run lint && npm test && npm run build`. Never commit red.
4. **Check the real UI** (`npm run dev`): demo at `#/demo`; Drive flows via `tests/browserHarness.js`. Check light/dark, mobile (390 px) and desktop. Wait 1–2 s before screenshots (animations / lazy loading).
5. **i18n**: add keys to `src/locales/en.json` **and all 14 languages** (`tests/i18n.test.js` catches missing / extra keys and wrong placeholders). If a string's meaning changes, update every language — never leave a stale meaning.
6. **Configuration**: new parameters go through `src/config.js` + `.env.example` + `.env` + README. No hard-coding.
7. **Docs**: every document exists in English and Vietnamese (`README.md` + `README.<lang>.md`, `docs/X.md` + `docs/X.vi.md`, `CLAUDE.md` + `CLAUDE.vi.md`). Update both when behaviour or limits change. Don't promise what hasn't been verified; say clearly what has not been tried against real Google Drive.
8. Small commits, English messages explaining **why**. Don't push unless asked; never commit secrets, `node_modules` or `dist`.

## 4. Code conventions

- Vue 3 `<script setup>`, Pinia setup stores, plain JS (no TypeScript). Component files `PascalCase.vue`.
- All Drive calls go through `services/drive.js`; all business logic through `services/repo.js` (`demoRepo.js` has the **same interface**). Components never call `fetch` directly.
- Every visible string goes through `t('...')`; no hard-coded English/Vietnamese in templates.
- Business errors use `RepoError(code)`; the UI maps `code` to an i18n string and never shows raw `error.message`.
- Keep to design v3 (colour tokens in `styles/base.css`, Bricolage/Newsreader fonts, evergreen accent). New CSS goes in `styles/extra.css` or scoped; don't rewrite the design CSS.
- Support RTL (use logical properties `inset-inline-*`, `margin-inline-*`).

## 5. Clean up afterwards

- Stop the dev server (`pkill -f "vite --port"`) and any container you started (`docker compose down`); never stop another project's container.
- Leave no temporary files in the repo.
