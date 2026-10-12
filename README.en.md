<div align="center">

# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Not a social network — a network of personal content under your control: sovereign, owned, and controlled.*

[Tiếng Việt](README.md) · [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md)

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

- **Posts**: create, edit, delete (Drive trash or permanent — configurable), upload photos (orientation-corrected, resized, **EXIF/GPS stripped**, thumbnails).
- **Sharing**: type `@email` to mention a connected friend and grant them access. Two roles: *can view*, *can comment*. Revoke any time.
- **Passwords**: protect a post so its text and photos are **encrypted in the browser** (AES-256-GCM) before they reach Drive. Optionally allow **open with link + password**.
- **Comments & likes** in `comments.json`; view-only people cannot write.
- **Fast index**: each user's `index.json` summarises own + shared posts; the feed paints instantly from an encrypted local cache and syncs in the background, re-downloading only changed posts.
- **Local security**: PIN, auto-lock, throttled and finally wiping brute-force protection, PIN change, device wipe.
- **14 languages** (incl. RTL Arabic), light/dark/system theme, responsive, installable PWA, and a **demo mode** at `#/demo`.

## Quick start

```bash
npm install
npm run dev            # http://localhost:5173  (open #/demo for a no-setup preview)
```

For real use create your own Google OAuth client — see [docs/GOOGLE_SETUP.md](docs/GOOGLE_SETUP.md). The redirect URI is the page address (e.g. `http://localhost:5173/`).

## Docker

```bash
cp .env.example .env
docker compose up -d --build      # http://localhost:8088  (SPECACT_PORT)
```

Non-root `nginx-unprivileged`, read-only root filesystem, all capabilities dropped, strict CSP. Edit `.env` and run `docker compose up -d` to change any `VITE_*` setting **without rebuilding** (they are written to `/env-config.js` at start-up; `VITE_BASE_PATH` is build-time). Put it behind HTTPS for a real domain — Google only allows plain `http://` for `localhost`.

All settings are documented in [`.env.example`](.env.example). **Never put a Google client secret in `.env`.**

## Development

```bash
npm test        # 70+ tests: crypto, vault, OAuth session, multi-user fake Drive, i18n completeness
npm run lint
npm run build
```

To drive the real UI against the fake Drive (no Google account needed) run `npm run dev` and, in the browser console, `const h = await (await import('/tests/browserHarness.js')).bootstrap()` — it signs `an@gmail.com` in (PIN 482916) and gives you a second user, `h.binh`.

## Known limitations

- Drive logic is tested against an in-repo simulation of the Drive API (`tests/fakeDrive.js`: permission inheritance, `sharedWithMe`, `properties`, multipart uploads), not live Google. Try it with a throw-away account before trusting it with important data.
- The `drive` scope is restricted: OAuth clients in *Testing* mode get refresh tokens that expire after 7 days (just sign in again).
- Commenters hold writer permission on `comments.json` only; technically they could edit others' comments through Drive. Simultaneous comments can, rarely, overwrite each other.
- Revoking access cannot un-download what someone already saw. Password protection is only as strong as the password.

License: MIT.
