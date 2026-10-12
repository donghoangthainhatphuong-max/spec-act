# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Bukan jejaring sosial — jaringan konten pribadi di bawah kendali Anda: berdaulat, dimiliki, dan terkendali.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT adalah PWA Vue 3 untuk **membagikan kiriman dan foto hanya kepada orang yang Anda pilih**. Tidak ada server atau basis data milik kami:

- Semua data tersimpan di **folder `SPECACT` di Google Drive Anda sendiri**.
- Siapa yang bisa melihat kiriman ditentukan oleh **izin Google Drive** — tanpa izin tidak ada akses, bahkan dengan tautan.
- Setelah dimuat, peramban **hanya berbicara dengan Google** (CSP memblokir tujuan lain). Host web hanya menyajikan berkas statis.
- Setiap pengguna membawa **klien OAuth Google miliknya sendiri**; ID/rahasia klien, token, dan kunci tidak pernah keluar dari perangkat, **dienkripsi dua kali**, dan dijaga **PIN 6 digit**.

## Personal · Berdaulat · Terdesentralisasi

- Kedaulatan: data Anda ada di Drive Anda tanpa penyedia di tengah — tidak ada server proyek yang dapat menyimpan, membaca, atau mengubahnya.
- Personalisasi: Anda menentukan siapa yang melihat, siapa yang berkomentar, kiriman mana yang memakai kata sandi atau publik lewat tautan.
- Desentralisasi: format data terbuka memungkinkan banyak situs dan aplikasi berbagi satu sumber data pribadi Anda.

## Fitur

- Kiriman: buat, ubah, hapus; foto (diubah ukurannya, EXIF/GPS dihapus) dengan penampil slide (zoom, putar).
- Berbagi: sebutan `@email`, peran “boleh melihat”/“boleh berkomentar”, cabut kapan saja.
- Tautan publik: “siapa pun yang punya tautan” hanya membuka berkas kiriman, tidak pernah foldernya.
- Kiriman dengan kata sandi, dienkripsi di peramban (AES-256-GCM).
- Mode komentar: terbuka / hanya orang yang dibagikan / terkunci — ditegakkan di Drive. Suka mengikuti siapa yang dapat melihat kiriman.
- Indeks pribadi cepat (index.json) dengan cache lokal terenkripsi.
- Brankas lokal terenkripsi dua lapis, PIN 6 digit, kunci otomatis, dihapus setelah terlalu banyak kesalahan.
- 14 bahasa (termasuk RTL), terang/gelap, responsif, PWA yang dapat dipasang, mode demo `#/demo`, halaman Tentang/Ketentuan/Privasi.

## Mulai cepat

```bash
npm install
npm run dev            # http://localhost:5173
```

Untuk penggunaan nyata, buat klien OAuth Google Anda sendiri (sekitar 5 menit): docs/GOOGLE_SETUP.md. Buka `#/demo` untuk pratinjau tanpa pengaturan.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- Bangun dan jalankan dengan perintah di atas; ubah port dengan `SPECACT_PORT` di `.env`.
- nginx non-root, sistem berkas hanya-baca, CSP ketat. Ubah `.env` lalu `docker compose up -d` — tanpa build ulang.
- Gunakan HTTPS untuk domain sungguhan (Google hanya mengizinkan `http://` untuk localhost; WebCrypto butuh konteks aman).
- Semua pengaturan didokumentasikan di `.env.example`. Jangan pernah menaruh rahasia klien Google di `.env`.

## Keterbatasan yang diketahui

- Logika Drive diuji pada Drive simulasi, bukan Google asli — coba dulu dengan akun cadangan.
- Pada mode Testing, refresh token Google kedaluwarsa setelah 7 hari (masuk lagi).
- Pengomentar secara teknis dapat mengubah komentar orang lain lewat Drive; penulisan bersamaan jarang saling menimpa.
- Mencabut akses tidak menghapus apa yang sudah terlihat; kekuatan perlindungan kata sandi bergantung pada kata sandinya.

---

Dokumentasi lainnya (English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

Aturan kontributor: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

Lisensi: MIT.
