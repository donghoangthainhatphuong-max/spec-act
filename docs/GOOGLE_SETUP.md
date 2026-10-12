# Google OAuth setup

[Tiếng Việt](GOOGLE_SETUP.vi.md)

SPECACT has no shared app: **each person creates their own OAuth client** (free, about 5 minutes). Your keys therefore never leave your device, and nobody else — not even whoever hosts the site — can hold access to your Drive.

## 1. Create a project and enable the Drive API

1. Open <https://console.cloud.google.com/projectcreate> and create a project (any name).
2. Open <https://console.cloud.google.com/apis/library/drive.googleapis.com> and **Enable** *Google Drive API*.

## 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen** → user type **External** → fill in an app name and e-mail.
2. No scopes need to be added here (SPECACT requests `https://www.googleapis.com/auth/drive` when you sign in).
3. *Test users*: add **your own Gmail** (and the Gmail of anyone who will sign in through this same project). If every person creates their own project (recommended) each only adds themselves.

> While the app is in **Testing**, refresh tokens expire after 7 days — just press *Continue with Google* again; your PIN and keys stay on the device. Switch to **In production** to avoid the 7-day expiry (Google shows an "unverified app" warning, which is fine for personal use).

## 3. Create the OAuth client

1. **Credentials → Create credentials → OAuth client ID**.
2. Application type: **Web application**.
3. **Authorized JavaScript origins**: the site origin, e.g. `http://localhost:5173` or `https://specact.example.com` (SPECACT shows the exact value on the keys screen, with a copy button).
4. **Authorized redirect URIs**: exactly the page address **with a trailing `/`**, e.g. `http://localhost:5173/` or `https://specact.example.com/`.
5. **Create**, then copy the **Client ID** (`…apps.googleusercontent.com`) and **Client secret** (`GOCSPX-…`).

## 4. Enter them in SPECACT

Open the app → **Continue with Google** → create a 6-digit PIN → paste the Client ID / Client secret → **Save and continue with Google** → approve Drive access. SPECACT creates the `SPECACT` folder in your Drive.

The keys are stored **encrypted twice on this device only**. Edit them later in *Settings → Security → Google keys*.

## Why the full `drive` scope?

`drive.file` only sees files created by *this very OAuth client*. Because every person has their own client, posts that others share with you would be invisible. `drive` is the only way to open shared folders. (SPECACT only reads/writes inside the `SPECACT` tree and post folders shared with you; it does not touch other files.)

## Troubleshooting

| Symptom | Cause |
|---|---|
| `redirect_uri_mismatch` | The redirect URI in Google differs from the page address (missing trailing `/`, wrong port, `http` vs `https`). |
| `Error 403: access_denied` | The e-mail is not a *test user* while the app is in Testing. |
| `invalid_client` | Wrong or deleted client ID / secret. |
| No refresh token | You granted access before: remove SPECACT at <https://myaccount.google.com/permissions> and sign in again. |
| Signed out after 7 days | The project is in *Testing* — sign in again or switch to *In production*. |
