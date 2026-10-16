# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Pas un réseau social — un réseau de contenus personnels sous votre contrôle : souverain, possédé et maîtrisé.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT est une PWA Vue 3 pour **partager des posts et des photos avec exactement les personnes que vous choisissez**. Aucun serveur ni base de données de notre part :

- Toutes les données vivent dans un **dossier `SPECACT` de votre propre Google Drive**.
- Qui peut voir un post est décidé par les **permissions Google Drive** — sans permission, pas d’accès, même avec le lien.
- Une fois chargé, le navigateur **ne parle qu’à Google** (la CSP bloque toute autre destination). L’hébergeur ne sert que des fichiers statiques.
- Chaque utilisateur apporte **son propre client OAuth Google** ; ID/secret client, jetons et clés ne quittent jamais l’appareil, sont **chiffrés deux fois** et protégés par un **PIN à 6 chiffres**.

## Personnel · Souverain · Décentralisé

- Souveraineté : vos données sont dans votre Drive, sans intermédiaire — aucun serveur du projet ne peut les stocker, lire ou modifier.
- Personnalisation : vous décidez qui voit, qui commente, quels posts sont protégés par mot de passe ou publics par lien.
- Décentralisation : un format de données ouvert permet à de nombreux sites et applications de partager une même source de données personnelle.

## Fonctionnalités

- Posts : créer, modifier, supprimer ; photos (redimensionnées, EXIF/GPS supprimés) avec visionneuse en diaporama (zoom, rotation).
- Partage : mentions `@e-mail`, rôles « peut voir » / « peut commenter », révocation à tout moment.
- Lien public : « toute personne avec le lien » n’ouvre que les fichiers du post, jamais le dossier.
- Posts protégés par mot de passe, chiffrés dans le navigateur (AES-256-GCM).
- Modes de commentaires : ouvert / personnes partagées / verrouillé — appliqués dans Drive. Les mentions « j’aime » suivent qui peut voir le post.
- Index personnel rapide (index.json) avec cache local chiffré.
- Coffre local à double chiffrement, PIN à 6 chiffres, verrouillage automatique, effacement après trop d’erreurs.
- 14 langues (dont RTL), clair/sombre, responsive, PWA installable, mode démo `#/demo`, pages À propos / Conditions / Confidentialité.

## Démarrage rapide

```bash
npm install
npm run dev            # http://localhost:5173
```

Pour un usage réel, créez votre propre client OAuth Google (environ 5 minutes) : docs/GOOGLE_SETUP.md. Ouvrez `#/demo` pour un aperçu sans configuration.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- Construisez et lancez avec la commande ci-dessus ; changez le port avec `SPECACT_PORT` dans `.env`.
- nginx sans root, système de fichiers en lecture seule, CSP stricte. Modifiez `.env` puis `docker compose up -d` — sans reconstruire.
- Utilisez HTTPS pour un vrai domaine (Google n’autorise `http://` que pour localhost ; WebCrypto exige un contexte sécurisé).
- Tous les réglages sont documentés dans `.env.example`. Ne mettez jamais de secret client Google dans `.env`.

## Limites connues

- La logique Drive est testée sur un Drive simulé, pas sur le vrai Google — essayez d’abord avec un compte jetable.
- En mode Testing, les jetons d’actualisation Google expirent après 7 jours (reconnectez-vous).
- Les commentateurs peuvent techniquement modifier les commentaires des autres via Drive ; des écritures simultanées peuvent rarement s’écraser.
- Révoquer l’accès n’efface pas ce qui a déjà été vu ; la protection par mot de passe vaut ce que vaut le mot de passe.

---

Documentation complémentaire (English / Tiếng Việt) : [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

🌐 **[specact.com](https://specact.com)** · [GitHub](https://github.com/donghoangthainhatphuong-max/spec-act)

Règles pour les contributeurs : CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

Licence : MIT.
