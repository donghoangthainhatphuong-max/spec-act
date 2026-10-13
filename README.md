<div align="center">

# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Not a social network — a network of personal content under your control: sovereign, owned and controlled.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

[Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md)

</div>

---

SPECACT is a Vue 3 PWA for **sharing posts and photos with exactly the people you choose**. There is no server and no database of ours:

- All data lives in a **`SPECACT` folder in your own Google Drive**.
- Who can see a post is decided by **Google Drive permissions** — no permission, no access, even with the link.
- After the HTML/JS is loaded the browser **talks only to Google** (the CSP blocks every other destination). The web host just serves static files.
- Every user brings **their own Google OAuth client**. Client ID/secret, tokens and keys never leave the device, are **encrypted twice**, and are guarded by a **6-digit PIN**.

## Personal · Sovereign · Decentralised

- **Data sovereignty:** your data lives in your Drive with no provider in the middle — none of the project's servers can store, read or alter your content, access rules or keys.
- **Personalisation:** you decide who sees, who comments, which posts are password-protected or public by link.
- **Decentralised & cross-platform:** the data uses an [open format](docs/OPEN_FORMAT.md), so many websites and apps can share one personal data source of yours without copying or migrating it.

## Features

| | |
|---|---|
| **Posts** | Create, edit, delete (Drive trash or permanent — configurable); photo upload (orientation-corrected, resized, **EXIF/GPS stripped**, thumbnails). Photo viewer with slideshow, zoom, rotate and pan. |
| **Camera & video** | Take photos and record video inside the app (front/back camera, up to `VITE_MAX_VIDEO_SECONDS`) or pick files; on a phone the **+** tab opens the camera first, on a computer it opens the picker. Videos get a poster frame, play in the viewer, and are encrypted too in password-protected posts. |
| **Audio & documents** | Record a voice note in the app or attach audio files; attach documents (PDF, Office, text, archives…) like photos. They appear as a list under the post (play / download), are encrypted in password-protected posts, and risky types (web pages, scripts, programs, SVG) are refused. Limits: `VITE_MAX_FILE_MB`, `VITE_MAX_AUDIO_SECONDS`. |
| **Sharing** | Type `@email` to mention a connected friend and grant access. Roles: *can view*, *can comment*. Pick friends from a grid, enter an e-mail, revoke any time. |
| **Public link** | "Anyone with the link" opens **only the post's files** (`post.json` + photos), never the folder. |
| **Passwords** | Password-protect a post: text and photos are **encrypted in the browser** (AES-256-GCM) before they reach Drive. Combine with a public link if you like. |
| **Comments** | Three modes per post: **open** (everyone who can see it), **shared people only**, **locked**. Enforced in Drive, not just in the UI. |
| **Likes** | Own `likes.json`: everyone the post is open to can like, regardless of the comment mode. |
| **Fast index** | Each user's `index.json` summarises own + shared posts; the feed paints instantly from an encrypted local cache and syncs in the background, downloading only changed posts. |
| **Message** | A “Message” button next to a friend, a post author, or a commenter opens that person's Google Chat conversation in a new tab (SPECACT never reads or stores chats; the URL is configurable via `VITE_CHAT_URL_TEMPLATE`). |
| **Friends** | A list of connected people (`contacts.json`) for mentions/sharing, with suggestions from people who shared with you. |
| **Local security** | PIN, auto-lock, throttled then wiping brute-force protection, PIN change, device wipe. |
| **Languages & UI** | 14 languages (incl. RTL Arabic), light/dark/system, responsive, installable PWA. About / Terms / Privacy pages at `#/about`, `#/terms`, `#/privacy`. |
| **Demo** | Sample-data mode (no Google needed) at `#/demo`. |

## Quick start

```bash
npm install
npm run dev            # http://localhost:5173  (open #/demo for a no-setup preview)
```

For real use create your own Google OAuth client — see **[docs/GOOGLE_SETUP.md](docs/GOOGLE_SETUP.md)** (about 5 minutes). The redirect URI is the page address, e.g. `http://localhost:5173/`.

## Docker

```bash
cp .env.example .env        # edit if needed
docker compose up -d --build
# → http://localhost:8088   (change the port with SPECACT_PORT in .env)
```

- Node build → `nginx-unprivileged` (non-root, read-only root filesystem, all capabilities dropped).
- Security headers (CSP allowing only `www.googleapis.com` / `oauth2.googleapis.com`, `X-Frame-Options`, `Referrer-Policy: no-referrer` …) live in [docker/security-headers.conf](docker/security-headers.conf).
- **Change settings without rebuilding**: edit `.env` and run `docker compose up -d`. Every `VITE_*` variable is written to `/env-config.js` at container start (`VITE_BASE_PATH` is baked in at build time).
- Put it behind HTTPS for a real domain — Google only accepts plain `http://` for `localhost`, and WebCrypto needs a secure context.

## Configuration (`.env`)

| Variable | Default | Meaning |
|---|---|---|
| `SPECACT_PORT` | `8088` | Port published by docker compose |
| `VITE_APP_NAME` | `SPECACT` | Display name (PWA manifest) |
| `VITE_BASE_PATH` | `/` | Base path when hosted in a sub-folder (*build time*) |
| `VITE_DEFAULT_LANG` / `VITE_DETECT_LANG` / `VITE_DEFAULT_THEME` | `en` / `true` / `system` | Default language, whether to follow the browser language, default theme |
| `VITE_LEGAL_CONTACT` | *(empty)* | Contact e-mail shown on the Terms/Privacy pages (operator fills in) |
| `VITE_ENABLE_DEMO` | `true` | Enable demo mode |
| `VITE_DRIVE_ROOT_FOLDER` / `VITE_DRIVE_POSTS_FOLDER` | `SPECACT` / `posts` | Folder names in Drive |
| `VITE_CHAT_URL_TEMPLATE` | `https://mail.google.com/chat/?authuser={me}#chat/dm/{email}` | Link that opens a Google Chat conversation (`{me}` = your e-mail, `{email}` = the friend's) |
| `VITE_DRIVE_SHARED_FOLDER` / `VITE_GROUP_SHARED` | `shared` / `true` | Folder holding shortcuts to posts shared with you; turn grouping on/off |
| `VITE_OAUTH_SCOPES` | `…/auth/drive` | OAuth scopes (full `drive` is needed to open posts others shared) |
| `VITE_OAUTH_REDIRECT_URI` | *(auto)* | Override the redirect URI if needed |
| `VITE_DELETE_MODE` | `trash` | `trash` (recoverable) or `permanent` |
| `VITE_NOTIFY_EMAIL` | `false` | Let Google send its share e-mail |
| `VITE_SYNC_INTERVAL_SECONDS` | `180` | Background index refresh (0 = off) |
| `VITE_PIN_LENGTH` | `6` | PIN digits |
| `VITE_PBKDF2_ITERATIONS` | `600000` | Cost of deriving the key from the PIN |
| `VITE_PIN_MAX_ATTEMPTS` | `10` | After this many wrong PINs the local vault is erased |
| `VITE_AUTO_LOCK_MINUTES` | `5` | Auto-lock after N idle minutes (0 = off) |
| `VITE_POST_KDF_ITERATIONS` | `310000` | Cost of deriving the key from a post password |
| `VITE_MAX_IMAGES_PER_POST` / `VITE_MAX_IMAGE_MB` | `10` / `25` | Photo limits |
| `VITE_MAX_FILE_MB` / `VITE_MAX_AUDIO_SECONDS` | `50` / `600` | Size limit for documents/audio files; max length when recording sound in the app |
| `VITE_MAX_VIDEO_MB` / `VITE_MAX_VIDEO_SECONDS` | `200` / `180` | Video size limit; max length when recording in the app |
| `VITE_IMAGE_MAX_DIMENSION` / `VITE_IMAGE_QUALITY` / `VITE_THUMB_DIMENSION` | `2048` / `0.86` / `480` | Photo quality |

> **Never put a Google client secret in `.env`.** Each person enters their own in the browser.

## Data in Drive

```
SPECACT/
├── index.json                  your personal fast index
├── contacts.json               friends / connected people
└── posts/
    └── 2026-10-12_ab12cd34ef/  one folder per post
        ├── post.json           content + metadata (or an encrypted payload)
        ├── comments.json       comments
        ├── likes.json          likes
        └── media/              photos (+ thumbnails)
```

Schema, permission model and sync flow: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Threat model and limits: [docs/SECURITY.md](docs/SECURITY.md). Format for other apps: [docs/OPEN_FORMAT.md](docs/OPEN_FORMAT.md).

## Development

```bash
npm run dev        # dev server
npm test           # 90+ tests (crypto, vault, OAuth, multi-user fake Drive, i18n, …)
npm run lint
npm run build      # dist/ (with the PWA service worker)
npm run icons      # regenerate PWA icons from the logo
```

To drive the real UI against the fake Drive (no Google account needed) run `npm run dev` and, in the browser console, `const h = await (await import('/tests/browserHarness.js')).bootstrap()` — it signs `an@gmail.com` in (PIN 482916) and gives you a second user, `h.binh`.

```
src/
├── services/     crypto · secureStore (two-layer vault) · googleAuth (OAuth PKCE) · drive (REST) ·
│                 repo (domain: posts/comments/sharing/index) · demoRepo · mentions · image
├── stores/       Pinia: session · posts · people · draft · prefs · ui
├── views/        Welcome · Feed · Post · Compose · Friends · Settings · Legal
├── components/   ui/ · layout/ · post/ · auth/
├── i18n/         tiny in-house i18n (flat JSON, English fallback)
├── locales/      14 languages (+ pages/ for About/Terms/Privacy)
└── styles/       CSS from design v3
tests/            vitest (fake Drive in tests/fakeDrive.js)
docker/           nginx, security headers, env-config.js generator
```

## Known limitations

- Drive logic is tested against an in-repo simulation of the Drive API (`tests/fakeDrive.js`: permission inheritance, `sharedWithMe`, `properties`, multipart uploads), not live Google. Try it with a throw-away account before trusting it with important data.
- The `drive` scope is restricted: OAuth clients in *Testing* mode get refresh tokens that expire after 7 days (just sign in again) and are limited to 100 test users — each person uses their own client, so this is per person.
- Commenters hold writer permission on `comments.json` only; technically they could edit others' comments through Drive. Simultaneous comments or likes can, rarely, overwrite each other.
- Videos are stored exactly as recorded (WebM on Chrome/Firefox, MP4 on Safari), so playback depends on the viewer's browser, and a video is downloaded whole before it plays. Large uploads use Drive's resumable upload; that path is covered by the fake Drive but not yet by real Drive. The in-app camera could not be tried on a real device (the fallback to the device camera app was).
- Revoking access cannot un-download what someone already saw. Password protection is only as strong as the password.

Rules for contributors (human or AI): [CLAUDE.md](CLAUDE.md).

License: MIT.
