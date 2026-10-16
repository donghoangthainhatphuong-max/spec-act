# Bộ nhận diện thương hiệu SPECACT

[English](BRAND.md) · Bảng trực quan: [brand/index.html](brand/index.html) · Biểu tượng app: [brand/app-icon-1024.png](brand/app-icon-1024.png)

## 1. Cốt lõi

**Mục đích.** Cho mỗi người một nơi cất giữ khoảnh khắc của riêng mình — lưu trong Google Drive của chính họ, chỉ chia sẻ với vài người họ chọn, mở và mang đi được.

**Lời hứa (slogan).** *Dữ liệu là tài sản cá nhân.* — tiếng Anh: *Your data is your personal asset.*
Câu phụ: *Những khoảnh khắc riêng tư, chỉ thuộc về bạn và người thân.*

**Tính cách.** Ấm áp · điềm tĩnh · đáng tin · nói thẳng, dễ hiểu · một chút tinh nghịch. Không "công nghệ khô cứng", không dọa dẫm, không bán hàng. Chúng ta là một phòng khách yên tĩnh, không phải cánh cửa hầm sắt.

**Ý nghĩa cái tên.** SPEC + ACT — một *đặc tả mở* (định dạng công khai, có phiên bản) và *điều bạn làm* (bạn đăng, bạn chọn, bạn giữ quyền kiểm soát). Viết đầy đủ: **S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust.

## 2. Logo

Biểu tượng là cả sản phẩm trong một hình — **một khoảnh khắc ở giữa, những người được thấy nó xung quanh** (cùng ý với hình "quỹ đạo" ở màn chào).

- **Đĩa có lỗ khóa** — khoảnh khắc của bạn; lỗ khóa nói rằng mặc định nó là riêng tư.
- **Vòng mảnh** — vòng tròn những người bạn chọn.
- **Ba chấm màu mơ** — chính những người đó. Đặt lệch có chủ ý: vòng người thân thật không đối xứng.

Tệp: `public/brand/mark.svg` (nền trong suốt), `public/favicon.svg` (biểu tượng app), `docs/brand/app-icon-1024.png`. Sinh lại icon PNG bằng `npm run icons`. Trong code: `AppLogo.vue` (web) và `BrandMark` (Flutter).

**Chữ logo.** Viết thường **spec**act: *spec* nét thường (định dạng mở), *act* siêu đậm và màu nhấn (điều bạn làm). Phông Inter, giãn chữ −2,5 %. Từ viết tắt SPECACT vẫn viết hoa trong văn bản và trang pháp lý.

**Khoảng trống** = 2 lần đường kính một chấm mơ ở mọi phía. **Cỡ tối thiểu** 16 px cho riêng biểu tượng (nhỏ hơn dùng favicon có nền), 96 px chiều rộng cho biểu tượng + chữ.

**Không** đổi màu ba chấm khác màu Mơ, tô kín vòng, thêm bóng hay viền, xoay, đặt lên ảnh rối, hoặc kéo giãn.

## 3. Màu sắc

Trung tính ấm như giấy, xanh rừng đậm cho sự tin cậy, màu mơ là tia sáng của con người.

| Vai trò | Sáng | Tối | Dùng cho |
|---|---|---|---|
| Giấy (nền) | `#F6F3EC` | `#0D1311` | nền trang |
| Bề mặt | `#FFFFFF` | `#141B18` | thẻ, bảng trượt |
| Chìm | `#EFEBE2` | `#1B2420` | ô nhập, chip, vùng phụ |
| Đường kẻ | `#E4DFD3` | `#27312C` | viền, ngăn cách |
| Mực (chữ) | `#1A1F1C` | `#EAEFEB` | chữ |
| Chữ phụ | `#646D66` | `#9AA79F` | chữ thứ cấp |
| **Xanh rừng** (nhấn) | `#14594A` | **Bạc hà** `#8FDCB8` | nút chính, liên kết, chữ "act" |
| Nhấn nhạt | `#DDF0E7` | `#1A2D26` | trạng thái chọn, nút tông nhạt |
| Xanh rừng đậm (hero) | `#0C3A31` | `#0E2A23` | vùng hero, biểu tượng app |
| **Mơ** (tia sáng) | `#EE7F43` | `#FFA46B` | các chấm, huy hiệu mới, tim đã thích — **không dùng cho chữ thường** |
| Mơ nhạt | `#FDE7D8` | `#3A2517` | nền nhấn cho mục màu mơ |
| Nguy hiểm | `#B3261E` | `#F2B8B5` | thao tác xóa, lỗi |

Quy tắc: màu mơ là *tia sáng*, dùng liều nhỏ (≤ 5 % màn hình). Chữ trên nền mơ luôn là màu Mực (`#2A1405` ở nền sáng). Độ tương phản (WCAG, đã đo): xanh rừng trên Giấy 7,4:1, trắng trên xanh rừng 8,2:1, Mực trên Giấy 15:1, Bạc hà trên nền Đêm 11,7:1, Chữ phụ trên Giấy 4,8:1; mơ trên trắng chỉ 2,7:1 nên chỉ để trang trí, không bao giờ là cách duy nhất truyền đạt ý nghĩa, và chữ trên nền mơ là màu Mực (6,5:1).

Code: token web ở `src/styles/base.css` (`--bg`, `--accent`, `--spark`…), Flutter ở `flutter/lib/theme.dart` (`Brand`, `AppTheme`).

## 4. Chữ

- **Giao diện — Inter** (variable, độ đậm 100–900): sans màn hình được vẽ kỹ nhất, đặt dấu tiếng Việt chồng nhau đúng chỗ, có cả Cyrillic và Hy Lạp. Tiêu đề 650–800, giãn chữ hẹp tối đa −0,015 em (giãn quá hẹp làm dấu thanh đụng nhau).
- **Đọc — Noto Serif** (400, 400 nghiêng, 600, 700): bài viết, bình luận, trích dẫn và tuyên ngôn, để thứ người dùng viết ra giống *được viết*, không giống một dòng feed.
- **Mỗi họ phông một tệp.** Mỗi họ là một tệp duy nhất chứa Latin, Latin mở rộng, tiếng Việt, Cyrillic và Hy Lạp — tuyệt đối không tách theo `unicode-range`. Khi chữ cái nền và dấu thanh lấy từ hai tệp khác nhau, tiếng Việt (và văn bản gõ dạng chữ tách dấu) bị vẽ lệch dấu, "méo".
- Tiếng Thái, Devanagari, Ả Rập và CJK dùng phông Noto / hệ thống tương ứng (xem `--ui` và `--read` trong `src/styles/base.css`). Phông tự host (không CDN); giấy phép SIL OFL 1.1 (`src/assets/fonts/LICENSE-*.txt`).
- Thang cỡ: 12 / 14 / 16 / 19 (đọc) / 24 / 30. Giãn dòng **1,45 cho thân bài, tiêu đề không bao giờ dưới 1,2** (dấu chồng của tiếng Việt cần khoảng trống).
- Tạo lại tệp: cắt (subset) phông gốc theo U+0020–007E, 00A0–024F, 0300–036F, 0370–03FF, 0400–052F, 1E00–1EFF, 2000–206F và các ký hiệu thường dùng bằng `pyftsubset --layout-features='*'`, giữ các tính năng bố cục để vị trí dấu không bị mất.

## 5. Hình khối, hình ảnh, chuyển động

- **Hình khối:** bo góc rộng rãi — thẻ 24, bảng trượt 28, nút bo tròn hẳn, ảnh 18–22. Viền mềm màu *Đường kẻ* thay vì bóng đổ nặng.
- **Hình đặc trưng:** **quỹ đạo** (một ảnh ở giữa, avatar xung quanh) và **những tấm ảnh nghiêng** (−12° / 0 / +10°, viền trắng 3 px) cho trạng thái trống và màn chào.
- **Avatar:** gradient sinh từ tên, nên một người bạn luôn mang cùng một màu.
- **Ảnh:** thật, tự nhiên, ánh sáng ấm. Không dùng ảnh stock "người chỉ vào laptop".
- **Chuyển động:** ngắn và mềm (160–260 ms, ease-out); tim bật nảy, chấm PIN phồng lên, lỗi rung một lần. Tôn trọng "giảm chuyển động".

## 6. Giọng nói

Nói như một người bạn thân tình cờ giỏi máy tính.

| Chúng ta nói | Chúng ta tránh |
|---|---|
| "Chỉ mình bạn thấy nội dung này." | "Quyền truy cập bị hạn chế với chủ thể được ủy quyền." |
| "Chia sẻ với những người bạn chọn." | "Tận dụng đồ thị xã hội." |
| "Dữ liệu của bạn nằm trong Google Drive của bạn." | "Mã hóa chuẩn quân đội!!!" |
| "Có lỗi xảy ra. Thử lại nhé." | "Lỗi 0x80004005" |
| "Xóa dữ liệu trên máy" (và nói rõ xóa gì) | "Đặt lại" (mơ hồ) |

Nguyên tắc: nói điều *sắp xảy ra* trước khi nó xảy ra; cụ thể về cái gì được giữ ở đâu; không nêu điều chưa kiểm chứng (xem các ghi chú "chưa thử" trong README); không dọa, không phóng đại; câu ngắn. Tiếng Việt: dùng "bạn", ấm áp, không dịch máy móc.

## 7. Kiểm tra khi làm màn hình mới

1. Trang trông như *giấy* (ấm) hay như *thép* (xám lạnh)?
2. Màu mơ chỉ dùng một hai chỗ, không rải khắp nơi?
3. Thứ người dùng tự viết có đặt bằng serif đọc không?
4. Câu chữ có nói rõ cái gì riêng tư và dữ liệu nằm ở đâu?
5. Cả sáng lẫn tối đều trông có chủ đích, và RTL (Ả Rập) vẫn ổn?
