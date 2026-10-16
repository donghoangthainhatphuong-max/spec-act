# SPECACT for Android (Flutter)

[Tiếng Việt](README.vi.md)

A native Flutter port of SPECACT. Same idea, same **open data format** — a post created here opens in the web app and the other way round. No backend: the app talks only to Google (OAuth + Drive) with **your own** OAuth client.

## Status (phase 1)

| Area | State |
|---|---|
| Drive layout, `post.json` / `comments.json` / `likes.json` (format v1) | ✅ ported, tested against an in-memory fake Drive |
| AES-256-GCM + PBKDF2, protected posts | ✅ **verified to decrypt data produced by the web app** |
| Two-layer vault (Android Keystore device key + 6-digit PIN), lockout/wipe, auto-lock | ✅ ported + unit tests |
| Sign-in (OAuth code + PKCE, loopback redirect) | ⚠️ written, **not yet run against real Google** |
| Feed (mine / shared), post detail, photo viewer, comments, likes | ✅ code + tests of the logic; **UI not yet run on a device** |
| Create post: text + photos (EXIF stripped), share by e-mail (view/comment), comment mode, public link (files only), password | ✅ logic tested; UI untested on a device |
| Attachments: photo/video capture (phone: camera app; browser: in-app camera), voice recording, documents, photo grid with “+N” | ✅ logic tested; capture/recording not yet tried on a real device |
| Link previews: paste a link → Open Graph card (title, description, picture) fetched straight from the phone; the web build needs `--dart-define=LINK_PREVIEW_URL=…` | ✅ logic tested; not tried against real sites |
| Delete post, settings (language, light/dark/auto theme, PIN, sign-out, erase) | ✅ |
| Video, audio recording, documents, @mention autocomplete, edit post, friends, legal pages, Google Chat button, index.json cache | ⏳ not yet |

Untested on real hardware or real Google Drive — treat it as an early build.

## Google setup

Create an OAuth client of type **Desktop app** (it allows the loopback redirect `http://127.0.0.1:<port>` the app uses; a Web client will fail with `redirect_uri_mismatch`) and paste its client ID and secret on first launch. They are stored only in the encrypted on-device vault. See [../docs/GOOGLE_SETUP.md](../docs/GOOGLE_SETUP.md).

## Build

```bash
flutter pub get
flutter test
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
```

Settings can be overridden at build time, e.g. `--dart-define=PBKDF2_ITERATIONS=600000` (see `lib/core/config.dart`).
Translations are shared with the web app: run `tool/sync_locales.sh` after editing `../src/locales/*.json`.

## Layout

`lib/core` — crypto, vault, Drive client, OAuth, post model, repo (no Flutter imports, unit-tested) · `lib/ui` — screens · `lib/state.dart` — app state · `lib/i18n.dart` — translations.

Security rules from the web app apply here too: everything read from Drive that someone else wrote is hostile (`publicMedia`, `cleanName`), nothing is rendered as HTML, attachments are never opened as pages.
