# SPECACT brand identity

[Tiếng Việt](BRAND.vi.md) · Visual sheet: [brand/index.html](brand/index.html) · App icon: [brand/app-icon-1024.png](brand/app-icon-1024.png)

## 1. Essence

**Purpose.** Give people a place for their moments that is theirs — stored in their own Google Drive, shared only with the few they choose, open and portable.

**Promise (tagline).** *Your data is your personal asset.* — Vietnamese: *Dữ liệu là tài sản cá nhân.*
Supporting line: *Private moments that belong only to you and the people closest to you.*

**Personality.** Warm · calm · trustworthy · plain-spoken · a little playful. Never techy, never fearful, never salesy. We are a quiet living room, not a vault door.

**Idea behind the name.** SPEC + ACT — an *open specification* (the format is public and versioned) and *what you do* (you post, you choose, you keep control). Expanded: **S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust.

## 2. Logo

The mark is the product in one picture — **one moment in the middle, the people who can see it around it** (the same idea as the orbit on the welcome screen).

- **The disc with a keyhole** — your moment; the keyhole says it is private by default.
- **The thin ring** — the circle of people you chose.
- **Three apricot dots** — those people. Placed unevenly on purpose: real circles are not symmetrical.

Files: `public/brand/mark.svg` (mark on transparent), `public/favicon.svg` (app icon), `docs/brand/app-icon-1024.png`. Regenerate PNG icons with `npm run icons`. In code: `AppLogo.vue` (web) and `BrandMark` (Flutter).

**Wordmark.** Lowercase **spec**act: *spec* in regular weight (the open format), *act* in extra-bold and the accent colour (what you do). Set in Inter, tracking −2.5 %. The acronym SPECACT stays uppercase in running text and legal pages.

**Clear space** = the diameter of one apricot dot × 2 on every side. **Minimum size** 16 px for the mark alone (below that, use the favicon with the background), 96 px wide for mark + wordmark.

**Don't** recolour the dots to anything but Apricot, fill the ring, add shadows or outlines, rotate the mark, put it on busy photos, or stretch it.

## 3. Colour

Warm paper neutrals, a deep forest green for trust, apricot as the human spark.

| Role | Light | Dark | Use |
|---|---|---|---|
| Paper (background) | `#F6F3EC` | `#0D1311` | page background |
| Surface | `#FFFFFF` | `#141B18` | cards, sheets |
| Sunken | `#EFEBE2` | `#1B2420` | inputs, chips, quiet areas |
| Line | `#E4DFD3` | `#27312C` | borders, dividers |
| Ink (text) | `#1A1F1C` | `#EAEFEB` | text |
| Muted | `#646D66` | `#9AA79F` | secondary text |
| **Forest** (accent) | `#14594A` | **Mint** `#8FDCB8` | primary actions, links, the "act" in the wordmark |
| Accent soft | `#DDF0E7` | `#1A2D26` | selected states, tonal buttons |
| Deep forest (hero) | `#0C3A31` | `#0E2A23` | hero panels, the app icon |
| **Apricot** (spark) | `#EE7F43` | `#FFA46B` | the dots, new/unread badges, liked hearts — **never for body text** |
| Apricot soft | `#FDE7D8` | `#3A2517` | highlights behind apricot items |
| Danger | `#B3261E` | `#F2B8B5` | destructive actions, errors |

Rules: apricot is a *spark*, used in small doses (≤ 5 % of a screen). Text on apricot is always Ink (`#2A1405` on light). Contrast (WCAG, measured): Forest on Paper 7.4:1, white on Forest 8.2:1, Ink on Paper 15:1, Mint on Night 11.7:1, Muted on Paper 4.8:1; apricot on white is only 2.7:1, so apricot is decoration only, never the only carrier of meaning, and text on apricot is Ink (6.5:1).

Code: web tokens in `src/styles/base.css` (`--bg`, `--accent`, `--spark`…), Flutter in `flutter/lib/theme.dart` (`Brand`, `AppTheme`).

## 4. Typography

- **Interface — Inter** (variable, weight 100–900): the most carefully drawn screen sans, with correct stacked Vietnamese tone marks, Cyrillic and Greek. Headlines 650–800, tracking −0.015 em at most (tight tracking makes tone marks collide).
- **Reading — Noto Serif** (400, 400 italic, 600, 700): posts, comments, quotes and the mission statement, so that what people write feels like writing, not like a feed.
- **One file per family.** Each family is a single font file holding Latin, Latin Extended, Vietnamese, Cyrillic and Greek together — never split by `unicode-range`. When a base letter and its tone mark came from two different files, Vietnamese (and any text typed as decomposed letters) was drawn with misplaced marks.
- Thai, Devanagari, Arabic and CJK fall back to the matching Noto / system fonts (see `--ui` and `--read` in `src/styles/base.css`). Fonts are self-hosted (no CDN); licences are SIL OFL 1.1 (`src/assets/fonts/LICENSE-*.txt`).
- Scale: 12 / 14 / 16 / 19 (reading) / 24 / 30. Line height **1.45 for body, never below 1.2 for headings** (stacked Vietnamese marks need the room).
- Regenerating the files: subset the full fonts to U+0020–007E, 00A0–024F, 0300–036F, 0370–03FF, 0400–052F, 1E00–1EFF, 2000–206F and common symbols with `pyftsubset --layout-features='*'`, keeping layout features so mark positioning survives.

## 5. Shapes, imagery, motion

- **Shapes:** generous radii — cards 24, sheets 28, buttons fully round, photos 18–22. Soft borders in *Line* rather than heavy shadows.
- **Signature visuals:** the **orbit** (a photo in the middle, avatars around it) and **tilted photo cards** (−12° / 0 / +10°, white 3 px frames) for empty states and welcome screens.
- **Avatars:** a gradient derived from the person's name, so a friend always looks the same.
- **Photography:** real, unposed, warm light. Never stock "people pointing at laptops".
- **Motion:** short and soft (160–260 ms, ease-out); hearts pop, PIN dots swell, errors shake once. Respect "reduce motion".

## 6. Voice and tone

Speak like a close friend who happens to be good with computers.

| We say | We avoid |
|---|---|
| "Only you can see this." | "Access restricted to authorised principals." |
| "Share with people you choose." | "Leverage our social graph." |
| "Your data stays in your Google Drive." | "Military-grade encryption!!!" |
| "Something went wrong. Try again." | "Error 0x80004005" |
| "Erase local data" (and say exactly what is erased) | "Reset" (vague) |

Principles: say what will happen *before* it does; be specific about what is kept where; never make claims we haven't verified (see the README's "not yet tried" notes); no fear, no hype; short sentences. Vietnamese: dùng "bạn", ấm áp, không dịch máy móc ("Quay lại SPECACT", không "Trở về ứng dụng").

## 7. Checklist for new screens

1. Does the page feel like *paper* (warm), not *steel* (cold grey)?
2. Is apricot used once or twice, not everywhere?
3. Is anything the user wrote set in the reading serif?
4. Does the copy say what is private and where data lives?
5. Do both light and dark themes look intentional, and does RTL (Arabic) still work?
