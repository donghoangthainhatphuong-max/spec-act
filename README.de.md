# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Kein soziales Netzwerk — ein Netzwerk persönlicher Inhalte unter Ihrer Kontrolle: souverän, besessen und kontrolliert.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT ist eine Vue-3-PWA, um **Beiträge und Fotos genau mit den Personen zu teilen, die Sie wählen**. Wir haben weder Server noch Datenbank:

- Alle Daten liegen in einem **`SPECACT`-Ordner in Ihrem eigenen Google Drive**.
- Wer einen Beitrag sehen darf, bestimmen die **Google-Drive-Berechtigungen** — ohne Berechtigung kein Zugriff, auch nicht mit Link.
- Nach dem Laden spricht der Browser **nur noch mit Google** (die CSP blockiert alles andere). Der Webhost liefert nur statische Dateien.
- Jeder Nutzer bringt **seinen eigenen Google-OAuth-Client** mit; Client-ID/Secret, Tokens und Schlüssel verlassen das Gerät nie, sind **doppelt verschlüsselt** und durch eine **6-stellige PIN** geschützt.

## Persönlich · Souverän · Dezentral

- Souveränität: Ihre Daten liegen in Ihrem Drive, ohne Anbieter dazwischen — kein Server des Projekts kann sie speichern, lesen oder ändern.
- Personalisierung: Sie entscheiden, wer sieht, wer kommentiert, welche Beiträge passwortgeschützt oder per Link öffentlich sind.
- Dezentral: Ein offenes Datenformat lässt viele Websites und Apps dieselbe persönliche Datenquelle nutzen.

## Funktionen

- Beiträge: erstellen, bearbeiten, löschen; Fotos (verkleinert, EXIF/GPS entfernt) mit Diashow-Viewer (Zoom, Drehen).
- Teilen: `@E-Mail`-Erwähnungen, Rollen „kann ansehen“ / „kann kommentieren“, jederzeit widerrufbar.
- Öffentlicher Link: „Jeder mit dem Link“ öffnet nur die Dateien des Beitrags, nie den Ordner.
- Passwortgeschützte Beiträge, im Browser verschlüsselt (AES-256-GCM).
- Kommentarmodi: offen / nur geteilte Personen / gesperrt — in Drive durchgesetzt. Likes folgen, wer den Beitrag sehen kann.
- Schneller persönlicher Index (index.json) mit verschlüsseltem lokalem Cache.
- Doppelt verschlüsselter lokaler Tresor, 6-stellige PIN, Auto-Sperre, Löschung nach zu vielen Fehlversuchen.
- 14 Sprachen (inkl. RTL), hell/dunkel, responsiv, installierbare PWA, Demo-Modus `#/demo`, Seiten Über/Bedingungen/Datenschutz.

## Schnellstart

```bash
npm install
npm run dev            # http://localhost:5173
```

Für den echten Einsatz erstellen Sie Ihren eigenen Google-OAuth-Client (ca. 5 Minuten): docs/GOOGLE_SETUP.md. Öffnen Sie `#/demo` für eine Vorschau ohne Einrichtung.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- Mit dem obigen Befehl bauen und starten; den Port ändern Sie mit `SPECACT_PORT` in `.env`.
- nginx ohne Root, schreibgeschütztes Dateisystem, strikte CSP. `.env` anpassen und `docker compose up -d` — kein Neubau nötig.
- Für eine echte Domain HTTPS verwenden (Google erlaubt `http://` nur für localhost; WebCrypto braucht einen sicheren Kontext).
- Alle Einstellungen sind in `.env.example` dokumentiert. Niemals ein Google-Client-Secret in `.env` ablegen.

## Bekannte Einschränkungen

- Die Drive-Logik wird gegen ein simuliertes Drive getestet, nicht gegen echtes Google — erst mit einem Wegwerfkonto ausprobieren.
- Im Testing-Modus laufen Google-Refresh-Tokens nach 7 Tagen ab (erneut anmelden).
- Kommentierende können technisch fremde Kommentare über Drive ändern; gleichzeitige Schreibvorgänge überschreiben sich selten gegenseitig.
- Zugriffsentzug macht Gesehenes nicht ungeschehen; Passwortschutz ist nur so stark wie das Passwort.

---

Weitere Dokumentation (English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

🌐 **[specact.com](https://specact.com)** · [GitHub](https://github.com/donghoangthainhatphuong-max/spec-act)

Regeln für Mitwirkende: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

Lizenz: MIT.
