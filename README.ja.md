# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*ソーシャルネットワークではありません。あなたが管理する個人コンテンツのネットワーク——主権があり、所有され、制御されます。*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT は、**あなたが選んだ人とだけ**投稿や写真を共有する Vue 3 PWA です。私たちのサーバーもデータベースもありません。

- すべてのデータは**あなた自身の Google ドライブの `SPECACT` フォルダ**に保存されます。
- 誰が投稿を見られるかは **Google ドライブの権限**で決まります。権限がなければ、リンクがあってもアクセスできません。
- 読み込み後、ブラウザは**Google とだけ通信**します（CSP がそれ以外をすべてブロック）。Web ホストは静的ファイルを配信するだけです。
- 各ユーザーが**自分の Google OAuth クライアント**を使います。クライアント ID/シークレット、トークン、キーは端末の外に出ず、**二重に暗号化**され、**6 桁の PIN** で守られます。

## パーソナル · データ主権 · 分散

- データ主権：データはあなたのドライブにあり、間に事業者はいません。本プロジェクトのサーバーが保存・閲覧・改変することはできません。
- パーソナライズ：誰が見られるか、誰がコメントできるか、どの投稿にパスワードを付けるか、リンクで公開するかを自分で決めます。
- 分散：オープンなデータ形式により、複数のサイトやアプリがあなたの同じ個人データを共有できます。

## 機能

- 投稿：作成・編集・削除、写真（リサイズ、EXIF/GPS 削除）、ズーム・回転できるスライドビューア。
- 共有：`@メール` でメンション、「閲覧可」「コメント可」の権限、いつでも取り消し。
- 公開リンク：「リンクを知っている全員」は投稿のファイルだけを開き、フォルダは決して開きません。
- パスワード保護された投稿はブラウザで暗号化（AES-256-GCM）。
- コメントモード：全員 / 共有した人のみ / ロック——Drive 側で強制。いいねは投稿を見られる人に従います。
- 高速な個人インデックス（index.json）と暗号化ローカルキャッシュ。
- 二重暗号化のローカル保管庫、6 桁 PIN、自動ロック、誤入力が続くと消去。
- 14 言語（RTL 含む）、ライト/ダーク、レスポンシブ、インストール可能な PWA、`#/demo` のデモ、概要/規約/プライバシーのページ。

## クイックスタート

```bash
npm install
npm run dev            # http://localhost:5173
```

本番利用には自分の Google OAuth クライアントを作成します（約 5 分）：docs/GOOGLE_SETUP.md。設定なしで試すには `#/demo` を開いてください。

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- 上記のコマンドでビルドして起動します。ポートは `.env` の `SPECACT_PORT` で変更できます。
- 非 root の nginx、読み取り専用ファイルシステム、厳格な CSP。`.env` を編集して `docker compose up -d` するだけで、再ビルドは不要です。
- 本番ドメインでは HTTPS を使ってください（Google は localhost にのみ http:// を許可。WebCrypto にはセキュアコンテキストが必要）。
- すべての設定は `.env.example` に記載されています。Google クライアントシークレットを `.env` に入れないでください。

## 既知の制限

- Drive のロジックは本物の Google ではなく模擬 Drive に対してテストされています。まず使い捨てアカウントで試してください。
- Testing モードでは Google のリフレッシュトークンは 7 日で失効します（再ログインしてください）。
- コメント権限のある人は技術的には Drive 経由で他人のコメントを編集でき、同時書き込みは稀に上書きし合います。
- アクセスを取り消しても、すでに見られたものは消せません。パスワード保護の強度はパスワード次第です。

---

その他のドキュメント（English / Tiếng Việt）： [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

コントリビューター向けルール：CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

ライセンス：MIT。
