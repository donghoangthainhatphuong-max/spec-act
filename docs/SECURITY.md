# Security

[Tiếng Việt](SECURITY.vi.md)

## Who sees what

| Party | Sees |
|---|---|
| Whoever hosts the static site | Only static-file access logs. Never tokens, keys or content (the browser does not call back to the host after loading). |
| Google | Your data as with any Drive file (password-protected posts are only ciphertext). |
| People you share with | Only the post folders/files you granted. Protected posts also need the password. |
| Everyone else | Nothing (Drive refuses). |

## Local vault

Every secret on the device — client ID/secret, refresh token, post keys, cached index, contacts — lives in IndexedDB, each record **encrypted twice**:

```
record = AES-256-GCM_{PIN key}( AES-256-GCM_{device key}( JSON ) )
```

- **Device key**: a random AES key created with WebCrypto as `extractable: false`, bound to this browser profile; JavaScript cannot read or export it.
- **PIN key**: PBKDF2-SHA256 (600,000 iterations by default, random 16-byte salt) from the PIN.
- Each layer binds the record name as additional data, so records cannot be swapped.
- Wrong PIN: 3 free tries, then 5 s, 10 s, 20 s … up to 15 min (persisted, survives reloads); after `VITE_PIN_MAX_ATTEMPTS` failures the **vault is erased**.
- The access token lives **in memory only**. Locking (auto after N idle minutes / long hidden tab / manual) drops every key from memory.
- Downloaded photos are kept only as in-memory blob URLs.

### Honest limits

- A 6-digit PIN has only 10⁶ possibilities. PBKDF2 makes each guess cost time, but an attacker who copies the **whole browser profile** *and* obtains the device key could brute-force the PIN offline. The attempt counter only stops people using the UI. Use the OS screen lock / disk encryption; the PIN does not replace them.
- If the static host is compromised it can serve malicious code on a later load. Self-host, pin versions, and use the strict CSP shipped here.
- Third-party scripts are blocked by the CSP (`script-src 'self'`); no CDN, no analytics, fonts are bundled.

## OAuth

- *Authorization code + PKCE (S256)*, random `state` verified on return, the code is used once and removed from the address bar immediately.
- The client secret is created by the user; Google requires it for "Web application" clients, so it is stored **encrypted in the vault** and sent **only** to `oauth2.googleapis.com`.
- Signing out calls `oauth2.googleapis.com/revoke` and deletes the refresh token. With "Remember on this device" off, the refresh token is never written to disk.

## Password-protected posts

- A random 256-bit content key, wrapped by a password-derived key (PBKDF2-SHA256, 310,000 iterations by default).
- Text, photo list, comments **and photo bytes** are AES-256-GCM encrypted in the browser before reaching Drive.
- Still visible: owner, timestamps, the list of people shared with, file sizes and counts. The index entry of such a post is always empty.
- A weak password can be brute-forced offline by anyone who has the files — use a long passphrase. A lost password cannot be recovered.
- Public link + password: anyone signed in with Google who has the link can fetch the **ciphertext**; without the password it is meaningless.

## Public links and comment/like files

- "Anyone with the link" grants `anyone` `reader` on **individual files only** (`post.json`, photos). The folder and `comments.json` are never opened, so the folder cannot be browsed.
- Open comments and likes by link visitors grant `anyone` `writer` on `comments.json` / `likes.json` **only** (never `post.json`). A visitor could tamper with that one file.

## Photo privacy

Photos are redrawn through a canvas before upload, so **EXIF (GPS, device, capture time) is stripped**. They are also orientation-corrected and size-capped.

## Limits of the sharing model

- People who can comment hold `writer` on `comments.json`, so technically they can edit or delete others' comments directly via Drive. The app only lets you delete your own comments (or the owner delete any).
- Two people writing `comments.json`/`likes.json` at once: the last write wins (read–modify–write, no locking).
- Viewers can copy or screenshot — revoking access does not un-see.

## Reporting a vulnerability

Open a private issue on the repository or contact the maintainer. Please do not include real keys in reports.
