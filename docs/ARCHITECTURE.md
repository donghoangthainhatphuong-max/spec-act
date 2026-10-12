# Kiến trúc / Architecture

## Nguyên tắc

1. **Không có backend.** Trang là file tĩnh. Sau khi tải, trình duyệt chỉ gọi `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com` (CSP trong `docker/security-headers.conf` ép điều này).
2. **Google Drive là nguồn sự thật** cho dữ liệu *và* quyền truy cập. Ứng dụng không tự phát minh hệ thống quyền riêng.
3. **Mọi thứ nhạy cảm trên thiết bị** nằm trong vault mã hóa hai lớp (xem [SECURITY.md](SECURITY.md)).

## Cây thư mục trên Drive

```
SPECACT/                         properties: specact=root
├── index.json                   chỉ mục cá nhân (bài của tôi + được chia sẻ)
├── contacts.json                người đã kết nối
└── posts/                       properties: specact=posts
    └── 2026-10-12_ab12cd34ef/   properties: specact=post, rev, pj, cj, mf
        ├── post.json
        ├── comments.json
        └── media/
            ├── ab12cd34ef_anh.jpg        ảnh đã thu nhỏ
            └── ab12cd34ef_t.jpg          ảnh thu nhỏ (thumbnail)
```

`properties` (không phải `appProperties`) được dùng vì `appProperties` chỉ thấy được với *cùng OAuth client* — mà mỗi người một client.

Thư mục bài mang `pj`/`cj`/`mf` (id của `post.json`, `comments.json`, `media/`) và `rev` (mốc cập nhật). Nhờ vậy chỉ cần **một lần liệt kê metadata** là biết bài nào đổi, và tải thẳng file cần thiết mà không phải duyệt từng thư mục.

### `post.json` (v1)

```jsonc
{
  "v": 1, "id": "ab12cd34ef",
  "owner": { "email": "an@gmail.com", "name": "An" },
  "createdAt": 1790000000000, "updatedAt": 1790000000000,
  "text": "…", "mentions": ["binh@gmail.com"],
  "media": [{ "id": "<fileId>", "thumb": "<fileId>", "name": "a.jpg", "mime": "image/jpeg", "w": 2048, "h": 1365, "size": 412345 }],
  "audience": { "binh@gmail.com": "view", "chi@gmail.com": "comment" },   // bản sao; sự thật là quyền trên Drive
  "linkShare": false,
  "protection": null
}
```

Bài **có mật khẩu**: `text`, `mentions`, `media` được gom vào `payload` (AES-256-GCM, AAD `post:<id>`); `protection` = `{ kdf: "PBKDF2-SHA256", iter, salt, wrap }` với `wrap` là *khóa nội dung ngẫu nhiên* đã được bọc bằng khóa dẫn xuất từ mật khẩu. Đổi mật khẩu chỉ bọc lại 32 byte, không đụng tới ảnh. Ảnh được mã hóa riêng (`media:<id>` làm AAD) và đặt tên ngẫu nhiên `*.bin`.

### `comments.json`

```jsonc
{ "v": 1, "comments": [{ "id": "…", "by": "chi@gmail.com", "name": "Chi", "at": 1790000000000, "text": "…" }], "likes": ["chi@gmail.com"] }
```
Với bài có mật khẩu, mỗi bình luận mang `enc` thay cho `text`.

### `index.json`

```jsonc
{ "v": 1, "owner": "an@gmail.com", "updatedAt": …, "syncedAt": …,
  "mine":   [ /* entry */ ],
  "shared": [ /* entry */ ] }
// entry = id(folderId), pid, owner, createdAt, updatedAt, rev, protected, linkShare,
//         text(snippet ≤600), truncated, mediaCount, media(≤3), audience(≤12), ids{pj,cj,mf}, via?
```
Bài có mật khẩu **không bao giờ** có nội dung trong chỉ mục.

## Mô hình quyền

| Vai trò | Quyền trên Drive |
|---|---|
| Chủ bài | owner của cây thư mục |
| **Được xem** | `reader` trên thư mục bài (kế thừa xuống `post.json`, `comments.json`, `media/*`) |
| **Được bình luận** | `reader` trên thư mục + `writer` **chỉ trên `comments.json`** (không bao giờ ghi được `post.json`) |
| Liên kết + mật khẩu | `anyone` `reader` trên thư mục (chỉ cho bài có mật khẩu; nội dung vẫn mã hóa) |

`@email` trong nội dung → người đó được thêm vào danh sách chia sẻ (mức *được xem*). Gỡ `@mention` khỏi văn bản **không** thu hồi quyền — thu hồi luôn là hành động tường minh.

Trước mỗi thay đổi chia sẻ, ứng dụng đọc quyền *thực tế* từ Drive (`readAudience`) nên người được thêm tay trong giao diện Drive không bị gỡ nhầm, và `post.json.audience` không bao giờ ghi quyền mà Drive từ chối cấp.

## Luồng đồng bộ chỉ mục

1. Mở ứng dụng → hiển thị ngay `index` từ bộ nhớ đệm mã hóa (hoặc `index.json` trên Drive nếu thiết bị mới).
2. Nền: liệt kê metadata thư mục của `posts/` (bài của tôi) và `sharedWithMe = true` lọc `properties has {specact=post}` (bài được chia sẻ) — 1 request / ~200 bài.
3. So `rev` với chỉ mục; **chỉ tải `post.json` của bài mới/đổi** (tối đa 4 song song).
4. Bài biến mất (bị gỡ quyền / thùng rác) bị loại; bài mở bằng liên kết được giữ nếu còn truy cập được.
5. Ghi lại cache cục bộ (mã hóa) và đẩy `index.json` lên Drive (debounce, bỏ qua nếu không đổi).

Bình luận/tim **không** tăng `rev`; thẻ bài tải `comments.json` lười khi hiện ra trong màn hình.

## Mã nguồn

- `services/repo.js` — toàn bộ nghiệp vụ Drive (`DriveRepo`). `services/demoRepo.js` có cùng giao diện cho chế độ demo.
- `services/drive.js` — client REST: bearer token, tự refresh 1 lần khi 401, backoff với 429/5xx, giới hạn đồng thời 6.
- `services/googleAuth.js` — OAuth *authorization code + PKCE (S256)*, `state` chống CSRF, trao đổi mã trực tiếp với `oauth2.googleapis.com` bằng client secret của người dùng.
- `stores/session.js` — máy trạng thái `booting → no-vault | locked → signed-out → ready`.
