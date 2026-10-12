<div align="center">

# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Không phải mạng xã hội. Là mạng lưới nội dung cá nhân có kiểm soát — nội dung có chủ quyền, có bản quyền, có kiểm soát.*

[English](README.en.md) · [Kiến trúc](docs/ARCHITECTURE.md) · [Bảo mật](docs/SECURITY.md) · [Thiết lập Google](docs/GOOGLE_SETUP.md)

</div>

---

SPECACT là một ứng dụng web (Vue 3, PWA) để **chia sẻ bài viết và ảnh chỉ với những người bạn chọn**. Không có máy chủ, không có cơ sở dữ liệu của chúng tôi:

- Mọi dữ liệu nằm trong **thư mục `SPECACT` trên Google Drive của chính bạn**.
- Ai được xem là do **quyền truy cập của Google Drive** quyết định — người không có quyền thì không thể đọc, kể cả khi có đường dẫn.
- Sau khi tải HTML/JS về, trình duyệt **chỉ nói chuyện với Google** (CSP chặn mọi đích khác). Máy chủ web chỉ là nơi phát file tĩnh.
- Mỗi người dùng tự tạo **Google OAuth client của riêng mình**; client ID / secret, token và khóa chỉ nằm trên thiết bị, **mã hóa hai lớp** và khóa bằng **mã PIN 6 số**.

## Cá nhân hóa · Chủ quyền · Phân tán

- **Chủ quyền dữ liệu:** dữ liệu nằm trong Drive của bạn, không có nhà cung cấp ở giữa — không máy chủ nào của dự án lưu, đọc hay can thiệp được vào nội dung, quyền truy cập hay khóa của bạn.
- **Cá nhân hóa:** bạn tự chọn ai xem, ai bình luận, bài nào có mật khẩu, bài nào công khai bằng liên kết; giao diện, ngôn ngữ, mức khóa là của riêng bạn.
- **Phân tán & xuyên nền tảng:** dữ liệu theo [định dạng mở](docs/OPEN_FORMAT.md); nhiều website/ứng dụng khác nhau có thể cùng dùng một nguồn dữ liệu cá nhân của bạn mà không phải sao chép hay di cư.

## Tính năng

| | |
|---|---|
| **Bài viết** | Tạo, sửa, xóa (vào thùng rác Drive hoặc xóa hẳn — cấu hình được); tải ảnh (tự xoay đúng chiều, thu nhỏ, **xóa EXIF/GPS**, tạo ảnh thu nhỏ). |
| **Chia sẻ** | Gõ `@email` để *tag* một người bạn đã kết nối → họ được cấp quyền xem. Hai mức: *được xem* và *được bình luận*. Chọn bạn từ lưới, nhập email, hoặc thu hồi bất kỳ lúc nào. |
| **Mật khẩu** | Bài có thể **bảo vệ bằng mật khẩu**: nội dung và ảnh được mã hóa ngay trên trình duyệt (AES-256-GCM) trước khi lên Drive. Có thể thêm **mở bằng liên kết + mật khẩu**. |
| **Bình luận & tim** | Lưu trong `comments.json` của bài; người chỉ-xem không ghi được. |
| **Chỉ mục nhanh** | Mỗi người có `index.json` trong thư mục SPECACT của mình tổng hợp bài của mình và bài được chia sẻ — hiển thị tức thì từ bộ nhớ đệm mã hóa, rồi tự đồng bộ nền (chỉ tải lại bài có thay đổi). |
| **Bạn bè** | Danh sách người đã kết nối (`contacts.json`) dùng cho tag/chia sẻ; gợi ý từ những người đã chia sẻ cho bạn. |
| **Bảo mật cục bộ** | PIN 6 số, khóa tự động, giới hạn thử sai (làm chậm rồi xóa kho khóa), đổi PIN, xóa dữ liệu thiết bị. |
| **Đa ngôn ngữ** | 14 ngôn ngữ: vi, en, zh, ja, ko, ru, fr, de, es, th, id, hi, ar (RTL), tr. |
| **Giao diện** | Sáng/tối/tự động, responsive từ điện thoại đến máy tính, PWA cài được. |
| **Trang thông tin** | Giới thiệu (mục tiêu cốt lõi, nguyên tắc), Điều khoản sử dụng, Chính sách quyền riêng tư tại `#/about`, `#/terms`, `#/privacy` — xem được cả khi chưa đăng nhập. Nội dung ở `src/locales/pages/` (en, vi; ngôn ngữ khác hiện bản tiếng Anh). Người vận hành nên rà soát theo luật địa phương và điền `VITE_LEGAL_CONTACT`. |
| **Dùng thử** | Chế độ demo với dữ liệu mẫu (không cần Google) tại `#/demo`. |

## Chạy nhanh

```bash
npm install
npm run dev          # http://localhost:5173
```

Mở `http://localhost:5173/#/demo` để xem thử ngay không cần cấu hình gì.

Để dùng thật, bạn cần một Google OAuth client của riêng mình — xem **[docs/GOOGLE_SETUP.md](docs/GOOGLE_SETUP.md)** (khoảng 5 phút). Redirect URI chính là địa chỉ trang, ví dụ `http://localhost:5173/`.

## Docker

```bash
cp .env.example .env        # chỉnh nếu cần
docker compose up -d --build
# → http://localhost:8088   (đổi cổng bằng SPECACT_PORT trong .env)
```

- Image: Node build → `nginx-unprivileged` (chạy không root, root filesystem chỉ-đọc, bỏ hết capabilities).
- Header bảo mật (CSP chỉ cho phép `googleapis.com`/`oauth2.googleapis.com`, `X-Frame-Options`, `Referrer-Policy: no-referrer`, …) nằm trong [docker/security-headers.conf](docker/security-headers.conf).
- **Đổi cấu hình không cần build lại**: sửa `.env` rồi `docker compose up -d`. Mọi biến `VITE_*` được ghi vào `/env-config.js` khi container khởi động (riêng `VITE_BASE_PATH` được nhúng lúc build).
- Chạy sau reverse proxy HTTPS (bắt buộc cho tên miền thật vì Google chỉ chấp nhận `http://` với `localhost`).

## Cấu hình (`.env`)

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `SPECACT_PORT` | `8088` | Cổng publish của docker compose |
| `VITE_APP_NAME` | `SPECACT` | Tên hiển thị (manifest PWA) |
| `VITE_BASE_PATH` | `/` | Đường dẫn gốc nếu host ở thư mục con (*lúc build*) |
| `VITE_DEFAULT_LANG` / `VITE_DETECT_LANG` / `VITE_DEFAULT_THEME` | `vi` / `true` / `system` | Ngôn ngữ mặc định, có tự nhận ngôn ngữ trình duyệt không, giao diện mặc định |
| `VITE_LEGAL_CONTACT` | *(trống)* | Email liên hệ hiển thị ở trang Điều khoản/Quyền riêng tư (người vận hành điền) |
| `VITE_ENABLE_DEMO` | `true` | Bật chế độ dùng thử |
| `VITE_DRIVE_ROOT_FOLDER` / `VITE_DRIVE_POSTS_FOLDER` | `SPECACT` / `posts` | Tên thư mục trên Drive |
| `VITE_OAUTH_SCOPES` | `…/auth/drive` | Phạm vi OAuth (cần `drive` đầy đủ để mở bài người khác chia sẻ) |
| `VITE_OAUTH_REDIRECT_URI` | *(tự động)* | Ghi đè redirect URI nếu cần |
| `VITE_DELETE_MODE` | `trash` | `trash` (khôi phục được) hoặc `permanent` |
| `VITE_NOTIFY_EMAIL` | `false` | Có để Google gửi email thông báo khi chia sẻ không |
| `VITE_SYNC_INTERVAL_SECONDS` | `180` | Chu kỳ tự đồng bộ chỉ mục (0 = tắt) |
| `VITE_PIN_LENGTH` | `6` | Số chữ số PIN |
| `VITE_PBKDF2_ITERATIONS` | `600000` | Độ nặng khi dẫn xuất khóa từ PIN |
| `VITE_PIN_MAX_ATTEMPTS` | `10` | Sai quá số lần này thì xóa kho khóa cục bộ |
| `VITE_AUTO_LOCK_MINUTES` | `5` | Tự khóa sau N phút không thao tác (0 = tắt) |
| `VITE_POST_KDF_ITERATIONS` | `310000` | Độ nặng khi dẫn xuất khóa từ mật khẩu bài viết |
| `VITE_MAX_IMAGES_PER_POST` / `VITE_MAX_IMAGE_MB` | `10` / `25` | Giới hạn ảnh |
| `VITE_IMAGE_MAX_DIMENSION` / `VITE_IMAGE_QUALITY` / `VITE_THUMB_DIMENSION` | `2048` / `0.86` / `480` | Chất lượng ảnh |

> **Không đặt Google client secret trong `.env`.** Mỗi người nhập khóa của họ trong trình duyệt.

## Dữ liệu trên Drive

```
SPECACT/
├── index.json                  chỉ mục nhanh của riêng bạn
├── contacts.json               bạn bè / người đã kết nối
└── posts/
    └── 2026-10-12_ab12cd34ef/  mỗi bài một thư mục
        ├── post.json           nội dung + metadata (hoặc payload đã mã hóa)
        ├── comments.json       bình luận + tim
        └── media/              ảnh (+ ảnh thu nhỏ)
```

Chi tiết lược đồ, mô hình quyền và luồng đồng bộ: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Mô hình đe dọa và giới hạn: [docs/SECURITY.md](docs/SECURITY.md).

## Phát triển

```bash
npm run dev        # dev server
npm test           # 70+ test (mã hóa, vault, OAuth, Drive giả lập đa người dùng, i18n…)
npm run lint
npm run build      # dist/ (kèm service worker PWA)
npm run icons      # sinh lại icon PWA từ logo
```

Thử giao diện thật với **Drive giả lập** (không cần tài khoản Google): chạy `npm run dev`, mở console của trình duyệt và gõ

```js
const h = await (await import('/tests/browserHarness.js')).bootstrap();   // đăng nhập an@gmail.com (PIN 482916)
await h.binh.createPost({ text: 'Chào An', files: [], audience: { 'an@gmail.com': 'comment' } });  // người dùng thứ hai
await h.posts.sync();
```

Cấu trúc mã nguồn:

```
src/
├── services/     crypto · secureStore (vault 2 lớp) · googleAuth (OAuth PKCE) · drive (REST) ·
│                 repo (miền: bài viết/bình luận/chia sẻ/chỉ mục) · demoRepo · mentions · image
├── stores/       Pinia: session · posts · people · draft · prefs · ui
├── views/        Welcome · Feed · Post · Compose · Friends · Settings
├── components/   ui/ · layout/ · post/ · auth/
├── i18n/         lớp dịch nhỏ gọn (JSON phẳng, fallback tiếng Anh)
├── locales/      14 ngôn ngữ
└── styles/       CSS theo thiết kế v3
tests/            vitest (Drive giả lập trong tests/fakeDrive.js)
docker/           nginx, header bảo mật, script sinh env-config.js
```

## Giới hạn đã biết

- Chưa thử với Google Drive thật trong CI — logic Drive được kiểm thử bằng một Drive giả lập mô phỏng quyền kế thừa, `sharedWithMe`, `properties`, upload multipart (xem `tests/fakeDrive.js`). Hãy thử với tài khoản thật của bạn trước khi dùng cho dữ liệu quan trọng.
- Phạm vi `drive` là *restricted scope*: với OAuth client ở chế độ **Testing**, refresh token hết hạn sau 7 ngày (đăng nhập lại là xong) và tối đa 100 test user. Mỗi người dùng client riêng của mình nên giới hạn này tính theo từng người.
- Người được quyền bình luận có quyền ghi trên `comments.json` (và chỉ file đó): về mặt kỹ thuật họ có thể sửa bình luận của người khác qua Drive. Hai người bình luận cùng lúc có thể (hiếm) ghi đè nhau.
- Thu hồi quyền không thể “lấy lại” những gì người xem đã tải/chụp. Bài có mật khẩu chỉ an toàn khi mật khẩu đủ mạnh.

Quy tắc làm việc cho người/AI đóng góp: [CLAUDE.md](CLAUDE.md).

Giấy phép: MIT.
