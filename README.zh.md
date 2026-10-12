# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*不是社交网络——而是由你掌控的个人内容网络：有主权、有归属、可控制。*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT 是一个 Vue 3 PWA，用来**只与你选择的人**分享帖子和照片。没有我们的服务器，也没有我们的数据库：

- 所有数据都保存在**你自己 Google Drive 中的 `SPECACT` 文件夹**里。
- 谁能看到帖子由 **Google Drive 权限**决定——没有权限就无法访问，即使有链接。
- 页面加载后，浏览器**只与 Google 通信**（CSP 会拦截其他一切地址）。网站主机只提供静态文件。
- 每位用户使用**自己的 Google OAuth 客户端**；客户端 ID/密钥、令牌和密钥不会离开设备，经过**两层加密**，并由 **6 位 PIN** 保护。

## 个性化 · 数据主权 · 去中心化

- 数据主权：数据在你自己的 Drive 中，中间没有服务商——本项目的任何服务器都无法存储、读取或修改。
- 个性化：由你决定谁能查看、谁能评论，哪些帖子设密码或通过链接公开。
- 去中心化：开放的数据格式让多个网站和应用共用你同一个个人数据源。

## 功能

- 帖子：创建、编辑、删除；照片（缩放、去除 EXIF/GPS），带幻灯片查看器（缩放、旋转）。
- 分享：`@邮箱` 提及，角色“可查看”/“可评论”，随时撤销。
- 公开链接：“拥有链接的任何人”只开放帖子的文件，绝不开放文件夹。
- 密码保护的帖子，在浏览器中加密（AES-256-GCM）。
- 评论模式：开放 / 仅限已分享的人 / 锁定——在 Drive 中强制执行。点赞跟随谁能看到帖子。
- 快速个人索引（index.json），配合加密的本地缓存。
- 两层加密的本地保险库、6 位 PIN、自动锁定、错误次数过多即清除。
- 14 种语言（含 RTL）、浅色/深色、响应式、可安装 PWA、`#/demo` 演示模式、关于/条款/隐私页面。

## 快速开始

```bash
npm install
npm run dev            # http://localhost:5173
```

正式使用请创建你自己的 Google OAuth 客户端（约 5 分钟）：docs/GOOGLE_SETUP.md。无需任何设置，打开 `#/demo` 即可预览。

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- 按上面的命令构建并运行；用 `.env` 中的 `SPECACT_PORT` 修改端口。
- 非 root 的 nginx、只读文件系统、严格 CSP。修改 `.env` 后执行 `docker compose up -d` 即可，无需重新构建。
- 正式域名请使用 HTTPS（Google 仅允许 localhost 使用 http://；WebCrypto 需要安全上下文）。
- 所有设置都记录在 `.env.example` 中。切勿把 Google 客户端密钥写进 `.env`。

## 已知限制

- Drive 逻辑是针对模拟的 Drive 测试的，而非真实 Google——请先用临时账号试用。
- 在 Testing 模式下，Google 刷新令牌 7 天后过期（重新登录即可）。
- 评论者技术上可通过 Drive 修改他人评论；同时写入极少数情况下会互相覆盖。
- 撤销访问无法让别人“忘记”已看到的内容；密码保护的强度取决于密码本身。

---

更多文档（English / Tiếng Việt）： [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

贡献者规则：CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

许可证：MIT。
