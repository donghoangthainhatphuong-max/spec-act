# Dữ liệu mở & phân tán / Open, portable data

SPECACT không giữ dữ liệu của bạn — **Google Drive của bạn là nơi duy nhất lưu dữ liệu**, theo định dạng mở dưới đây. Bất kỳ website hay ứng dụng nào bạn tin tưởng đều có thể đọc/ghi cùng nguồn dữ liệu này (với OAuth client và quyền Drive của chính bạn), nên bạn đổi nơi hiển thị mà không phải di cư dữ liệu, và không bị khóa vào một nhà cung cấp.

## Nguyên tắc chủ quyền

1. **Không có bên trung gian.** Trình duyệt ↔ Google Drive trực tiếp; không có máy chủ SPECACT để lưu, đọc, kiểm duyệt hay sửa dữ liệu.
2. **Quyền truy cập là của bạn.** Ai xem/bình luận do quyền Drive của bạn quyết định; bạn thu hồi bất cứ lúc nào.
3. **Khóa là của bạn.** Bài có mật khẩu được mã hóa ở client; nhà cung cấp trang web không có khóa.
4. **Định dạng mở, có phiên bản** (`v`), tài liệu ở đây và trong [ARCHITECTURE.md](ARCHITECTURE.md). Ứng dụng khác tuân theo đặc tả này sẽ tương thích.
5. **Tự host được.** Mã nguồn MIT; chạy bằng Docker/Nginx tĩnh trên máy của bạn.

> Giới hạn thật thà: nhà cung cấp *trang web* chỉ phát file JS; một nhà cung cấp xấu có thể phát mã bị sửa ở lần tải sau. Cách loại bỏ rủi ro này là **tự host** (hoặc dùng bản build bạn đã kiểm tra) — xem [SECURITY.md](SECURITY.md). Dữ liệu lưu trên Google Drive vẫn tuân theo điều khoản của Google.

## Đặc tả tối thiểu cho ứng dụng khác

- Thư mục gốc `SPECACT/` (properties `specact=root`), bài ở `SPECACT/posts/<ngày>_<id>/` (properties `specact=post`, `rev`, `pj`, `cj`, `mf`).
- `post.json` (`v: 1`): `id, owner, createdAt, updatedAt, text, media[], mentions[], audience{}, linkShare, commentMode, cj, protection`. Bài có mật khẩu mang `payload` AES-256-GCM (AAD `post:<id>`), khóa nội dung bọc bằng PBKDF2-SHA256.
- `comments.json`: `{ v:1, comments[], likes[] }` (bình luận bài có mật khẩu mang `enc`).
- Chia sẻ = quyền Drive: *được xem* = `reader` trên thư mục; *được bình luận* = thêm `writer` **chỉ trên `comments.json`**; công khai bằng liên kết = `anyone` `reader` **chỉ trên các tệp** (`post.json`, ảnh), không trên thư mục.
- Bài được định danh bằng id thư mục (người được chia sẻ) hoặc id `post.json` (liên kết công khai).
- Ứng dụng khác **phải** giữ nguyên các trường không biết khi ghi lại `post.json`, và không được mở quyền rộng hơn người dùng đã chọn.
