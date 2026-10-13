# Kiến trúc

[English](ARCHITECTURE.md)

## Nguyên tắc

1. **Không có backend.** Trang là file tĩnh. Sau khi tải, trình duyệt chỉ gọi `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com` (CSP trong `docker/security-headers.conf` ép điều này).
2. **Google Drive là nguồn sự thật** cho dữ liệu *và* quyền truy cập. Ứng dụng không tự phát minh hệ thống quyền riêng.
3. **Mọi thứ nhạy cảm trên thiết bị** nằm trong vault mã hóa hai lớp (xem [SECURITY.vi.md](SECURITY.vi.md)).

## Cây thư mục trên Drive

```
SPECACT/                         properties: specact=root
├── index.json                   chỉ mục cá nhân (bài của tôi + được chia sẻ)
├── contacts.json                người đã kết nối
├── shared/                      mỗi bài được chia sẻ cho tôi có một lối tắt Drive mang tiền tố
│   └── __S.P.E.C.T.A.C.T__ Alice · 2026-10-12   →  thư mục bài của Alice
└── posts/                       properties: specact=posts
    └── __S.P.E.C.T.A.C.T__ 2026-10-12_ab12cd34ef/   properties: specact=post, rev, pj, cj, lj, mf
        ├── post.json
        ├── __S.P.E.C.T.A.C.T__ comments.json
        ├── __S.P.E.C.T.A.C.T__ likes.json           {v:1, likes:[email]}
        └── media/
            ├── ab12cd34ef_anh.jpg        ảnh đã thu nhỏ
            ├── ab12cd34ef_t.jpg          ảnh thu nhỏ (thumbnail)
            ├── ab12cd34ef_clip.webm      video (ảnh bìa = thumbnail)
            ├── ab12cd34ef_voice.webm     âm thanh (không thumbnail)
            └── ab12cd34ef_HopDong.pdf    tài liệu (không thumbnail)
```

`properties` (không phải `appProperties`) được dùng vì `appProperties` chỉ thấy được với *cùng OAuth client* — mà mỗi người một client.

Thư mục bài mang `pj`/`cj`/`lj`/`mf` (id của `post.json`, `comments.json`, `likes.json`, `media/`) và `rev` (mốc cập nhật). Chỉ cần **một lần liệt kê metadata** là biết bài nào đổi, rồi tải thẳng file cần thiết.

### `post.json` (v1)

```jsonc
{
  "v": 1, "id": "ab12cd34ef",
  "owner": { "email": "an@gmail.com", "name": "An" },
  "createdAt": 1790000000000, "updatedAt": 1790000000000,
  "text": "…", "mentions": ["binh@gmail.com"],
  "media": [{ "id": "<fileId>", "thumb": "<fileId>", "name": "a.jpg", "mime": "image/jpeg", "w": 2048, "h": 1365, "size": 412345 }],
  "audience": { "binh@gmail.com": "view", "chi@gmail.com": "comment" },  // bản sao; sự thật là quyền trên Drive
  "linkShare": false, "commentMode": "shared", "cj": "<fileId>", "lj": "<fileId>",
  "protection": null
}
```

Bài **có mật khẩu**: `text`, `mentions`, `media` gom vào `payload` (AES-256-GCM, AAD `post:<id>`); `protection` = `{ kdf: "PBKDF2-SHA256", iter, salt, wrap }` với `wrap` là *khóa nội dung ngẫu nhiên* được bọc bằng khóa dẫn xuất từ mật khẩu. Đổi mật khẩu chỉ bọc lại 32 byte, không đụng tới ảnh. Ảnh được mã hóa riêng (AAD `media:<id>`) và đặt tên ngẫu nhiên `*.bin`.

Mục media có `kind: "video"` còn mang `duration` (giây) và `mime` như `video/webm` hay `video/mp4`; `thumb` là ảnh bìa. Video được lưu đúng như lúc quay (không chuyển mã) và tải lên bằng giao thức resumable của Drive khi lớn hơn 4 MB; trong bài có mật khẩu, byte video được mã hóa như ảnh.

Các loại media khác: `kind: "audio"` (có `duration`) và `kind: "file"` (tài liệu và tệp an toàn khác; `name`, `mime`, `size`) **không có ảnh thu nhỏ** (`thumb: null`). Ảnh và video tạo thành lưới hình và khung xem; âm thanh và tài liệu hiện thành danh sách dưới bài. `mediaCount` / `media` trong mục chỉ mục chỉ đếm ảnh và video; `files` / `fileCount` mô tả phần còn lại.

### `comments.json` / `likes.json`

```jsonc
{ "v": 1, "comments": [{ "id": "…", "by": "chi@gmail.com", "name": "Chi", "at": 1790000000000, "text": "…" }], "likes": [] }
{ "v": 1, "likes": ["chi@gmail.com"] }
```
Bình luận của bài có mật khẩu mang `enc` thay cho `text`. Tim nằm trong `likes.json`; bài cũ được tạo file này (kèm tim cũ) khi chủ bài mở lần đầu.

### `index.json`

```jsonc
{ "v": 1, "owner": "an@gmail.com", "updatedAt": …, "syncedAt": …, "mine": [ /* entry */ ], "shared": [ /* entry */ ] }
// entry = id(folderId), pid, owner, createdAt, updatedAt, rev, protected, linkShare, commentMode,
//         text(snippet ≤600), truncated, mediaCount, media(≤3), audience(≤12), ids{pj,cj,lj,mf}, via?
```
Bài có mật khẩu **không bao giờ** có nội dung trong chỉ mục.

## Giữ Drive gọn gàng

Mọi thứ SPECACT tạo ra mà người khác có thể thấy đều mang tiền tố `__S.P.E.C.T.A.C.T__` (thư mục bài, `comments.json`, `likes.json`), nên dễ nhận biết và tìm trong “Được chia sẻ với tôi” của Drive. Không ai di chuyển được thư mục bài của người khác vào cây của mình, nên mỗi lần đồng bộ chỉ mục SPECACT tạo một **lối tắt Drive** cho mỗi bài được chia sẻ trong `SPECACT/shared/` (đặt tên `__S.P.E.C.T.A.C.T__ <chủ bài> · <ngày>`) và xóa nó khi hết quyền. Nhờ đó mọi thứ được chia sẻ với bạn đều truy cập được ngay trong thư mục `SPECACT` của chính bạn. Lối tắt chỉ là tiện ích: lỗi không làm hỏng đồng bộ, và `VITE_GROUP_SHARED=false` tắt tính năng. Drive vẫn liệt kê các tệp được chia sẻ (thư mục bài, `comments.json`, `likes.json`) trong “Được chia sẻ với tôi” — tiền tố giúp dễ tìm/lọc nhưng Drive không có API để ẩn chúng.

## Mô hình quyền

| Đối tượng | Quyền trên Drive |
|---|---|
| Chủ bài | owner của cây thư mục |
| **Được xem** | `reader` trên thư mục bài (kế thừa xuống `post.json`, `comments.json`, `media/*`) |
| **Được bình luận** | `reader` trên thư mục + `writer` **chỉ trên `comments.json`** (không bao giờ `post.json`) |
| **Thả tim** | `writer` **chỉ trên `likes.json`** cho mọi người được xem bài, ở mọi chế độ bình luận; `anyone` `writer` trên file này chỉ khi bài công khai bằng liên kết |
| **Ai có liên kết** | `anyone` `reader` **trên các tệp** (`post.json`, ảnh) — không bao giờ trên thư mục hay `comments.json` |

Chế độ bình luận: **mở** (mọi người xem được bài, gồm cả người qua liên kết nếu bài công khai), **người được chia sẻ** (mặc định: chỉ người có mức "được bình luận"), **khóa** (không ai; quyền ghi trên `comments.json` bị gỡ ngay trong Drive).

`@email` trong nội dung → người đó được thêm vào danh sách chia sẻ (*được xem*). Gỡ `@mention` **không** thu hồi quyền — thu hồi luôn là hành động tường minh. Trước mỗi thay đổi chia sẻ, ứng dụng đọc quyền *thực tế* từ Drive nên người được thêm tay trong giao diện Drive không bị gỡ nhầm, và `post.json.audience` không bao giờ ghi quyền mà Drive từ chối cấp.

## Luồng đồng bộ chỉ mục

1. Mở ứng dụng → hiển thị ngay chỉ mục từ bộ nhớ đệm mã hóa (hoặc `index.json` trên Drive nếu thiết bị mới).
2. Nền: liệt kê metadata thư mục của `posts/` (bài của tôi) và `sharedWithMe = true` lọc `properties has {specact=post}` (bài được chia sẻ) — 1 request / ~200 bài.
3. So `rev` với chỉ mục; **chỉ tải `post.json` của bài mới/đổi** (tối đa 4 song song).
4. Bài biến mất (bị gỡ quyền / thùng rác) bị loại; bài mở bằng liên kết được giữ nếu còn truy cập được.
5. Ghi lại cache cục bộ (mã hóa) và đẩy `index.json` lên Drive (debounce, bỏ qua nếu không đổi).

Bình luận/tim **không** tăng `rev`; thẻ bài tải chúng lười khi hiện ra trong màn hình.

## Mã nguồn

- `services/repo.js` — toàn bộ nghiệp vụ Drive (`DriveRepo`); `services/demoRepo.js` có cùng giao diện cho chế độ demo.
- `services/drive.js` — client REST: bearer token, tự refresh 1 lần khi 401, backoff với 429/5xx, giới hạn đồng thời 6.
- `services/googleAuth.js` — OAuth *authorization code + PKCE (S256)*, `state` chống CSRF, trao đổi mã trực tiếp với `oauth2.googleapis.com` bằng client secret của người dùng.
- `stores/session.js` — máy trạng thái `booting → no-vault | locked → signed-out → ready`.
