# SPECACT cho Android (Flutter)

[English](README.md)

Bản Flutter gốc (native) của SPECACT. Cùng ý tưởng, cùng **định dạng dữ liệu mở** — bài tạo ở đây mở được trên web và ngược lại. Không có backend: app chỉ nói chuyện với Google (OAuth + Drive) bằng OAuth client **của chính bạn**.

## Hiện trạng (giai đoạn 1)

| Phần | Trạng thái |
|---|---|
| Cấu trúc Drive, `post.json` / `comments.json` / `likes.json` (định dạng v1) | ✅ đã port, test với Drive giả lập trong bộ nhớ |
| AES-256-GCM + PBKDF2, bài đặt mật khẩu | ✅ **đã kiểm chứng giải mã được dữ liệu do bản web tạo** |
| Vault 2 lớp (khóa thiết bị trong Android Keystore + PIN 6 số), khóa/xóa khi nhập sai, tự khóa | ✅ đã port + unit test |
| Đăng nhập (OAuth code + PKCE, redirect loopback) | ⚠️ đã viết, **chưa chạy với Google thật** |
| Bảng tin (của tôi / được chia sẻ), chi tiết bài, xem ảnh, bình luận, thích | ✅ có code + test logic; **chưa chạy giao diện trên thiết bị** |
| Tạo bài: chữ + ảnh (xóa EXIF), chia sẻ qua email (xem/bình luận), chế độ bình luận, link công khai (chỉ tệp), mật khẩu | ✅ logic đã test; giao diện chưa thử trên thiết bị |
| Đính kèm: chụp ảnh/quay video (điện thoại: app camera; trình duyệt: camera trong app), ghi âm, tài liệu, lưới ảnh có “+N” | ✅ logic đã test; chụp/ghi chưa thử trên thiết bị thật |
| Xem trước liên kết: dán link → thẻ Open Graph (tiêu đề, mô tả, ảnh) lấy thẳng từ điện thoại; bản web cần `--dart-define=LINK_PREVIEW_URL=…` | ✅ logic đã test; chưa thử với site thật |
| Xóa bài, cài đặt (ngôn ngữ, giao diện sáng/tối/tự động, PIN, đăng xuất, xóa dữ liệu) | ✅ |
| Video, ghi âm, tài liệu, gợi ý @mention, sửa bài, bạn bè, trang pháp lý, nút Google Chat, cache index.json | ⏳ chưa có |

Chưa thử trên thiết bị thật hay Google Drive thật — hãy coi đây là bản đầu.

## Cài đặt Google

Tạo OAuth client loại **Desktop app** (cho phép redirect loopback `http://127.0.0.1:<port>` mà app dùng; client Web sẽ lỗi `redirect_uri_mismatch`) và dán client ID + secret ở lần mở đầu. Chúng chỉ nằm trong vault mã hóa trên thiết bị. Xem [../docs/GOOGLE_SETUP.vi.md](../docs/GOOGLE_SETUP.vi.md).

## Build

```bash
flutter pub get
flutter test
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
```

Có thể ghi đè cấu hình lúc build, ví dụ `--dart-define=PBKDF2_ITERATIONS=600000` (xem `lib/core/config.dart`).
Bản dịch dùng chung với web: chạy `tool/sync_locales.sh` sau khi sửa `../src/locales/*.json`.

## Cấu trúc

`lib/core` — mã hóa, vault, Drive client, OAuth, mô hình bài, repo (không import Flutter, có unit test) · `lib/ui` — màn hình · `lib/state.dart` — trạng thái app · `lib/i18n.dart` — bản dịch.

Quy tắc bảo mật của bản web áp dụng ở đây: mọi thứ đọc từ Drive do người khác viết đều là độc hại (`publicMedia`, `cleanName`), không render HTML, tệp đính kèm không bao giờ mở như trang.
