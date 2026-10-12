# Bảo mật / Security

## Ai thấy được gì

| Bên | Thấy |
|---|---|
| Người chủ trang web (host file tĩnh) | Chỉ log truy cập tệp tĩnh. Không bao giờ thấy token, khóa, nội dung (trình duyệt không gọi về host sau khi tải). |
| Google | Dữ liệu bạn lưu trên Drive như mọi file Drive (nội dung bài **có mật khẩu** thì chỉ là bản mã). |
| Người được chia sẻ | Chỉ thư mục bài được cấp. Bài có mật khẩu còn cần mật khẩu. |
| Người khác | Không gì cả (Drive từ chối). |

## Kho khóa cục bộ (vault)

Mọi bí mật trên thiết bị — client ID/secret, refresh token, khóa của bài, bộ nhớ đệm chỉ mục, danh bạ — nằm trong IndexedDB, mỗi bản ghi được **mã hóa hai lớp**:

```
bản ghi = AES-256-GCM_{khóa PIN}( AES-256-GCM_{khóa thiết bị}( JSON ) )
```

- **Khóa thiết bị**: khóa AES ngẫu nhiên `extractable: false` sinh bằng WebCrypto, gắn với hồ sơ trình duyệt này; JavaScript không đọc/xuất được.
- **Khóa PIN**: PBKDF2-SHA256 (mặc định 600 000 vòng, salt ngẫu nhiên 16 byte) từ mã PIN.
- Mỗi lớp có *additional data* gắn với tên bản ghi → không thể hoán đổi bản ghi.
- Đoán sai PIN: 3 lần miễn phí, sau đó chờ 5 s, 10 s, 20 s … tối đa 15 phút (lưu bền, sống sót qua tải lại); sai `VITE_PIN_MAX_ATTEMPTS` lần thì **xóa vault**.
- Access token chỉ ở **bộ nhớ**. Khóa ứng dụng (tự động sau N phút không thao tác / khi tab ẩn lâu / bấm khóa) xóa mọi khóa khỏi bộ nhớ.
- Ảnh tải về chỉ giữ trong bộ nhớ dưới dạng blob URL; không ghi đĩa.

### Giới hạn thật thà

- PIN 6 số chỉ có 10⁶ khả năng. PBKDF2 làm mỗi lần đoán tốn thời gian, nhưng nếu kẻ tấn công **sao chép được toàn bộ hồ sơ trình duyệt** *và* lấy được khóa thiết bị, họ có thể dò PIN ngoại tuyến. Bộ đếm sai/xóa vault chỉ chặn kẻ dùng giao diện. Dùng khóa màn hình/mã hóa ổ đĩa của hệ điều hành; PIN không thay thế chúng.
- Nếu máy chủ phát file tĩnh bị chiếm, nó có thể phát mã độc ở lần tải sau. Tự host, ghim phiên bản, và dùng HTTPS + CSP mặc định kèm theo.
- Script bên thứ ba bị chặn bởi CSP (`script-src 'self'`); không có CDN, không analytics, font được đóng gói.

## OAuth

- *Authorization code + PKCE (S256)*, `state` ngẫu nhiên kiểm tra lúc quay lại, mã chỉ dùng một lần và xóa khỏi thanh địa chỉ ngay.
- Client secret do chính người dùng tạo; Google yêu cầu secret cho client “Web application” nên nó được lưu **mã hóa trong vault** và gửi **chỉ** tới `oauth2.googleapis.com`.
- Đăng xuất gọi `oauth2.googleapis.com/revoke` rồi xóa refresh token.

## Bài viết có mật khẩu

- Khóa nội dung 256-bit ngẫu nhiên; bọc bằng khóa dẫn xuất từ mật khẩu (PBKDF2-SHA256, mặc định 310 000 vòng).
- Văn bản, danh sách ảnh, bình luận và **cả byte ảnh** được mã hóa AES-256-GCM trên trình duyệt trước khi lên Drive.
- Còn lộ ra: chủ bài, thời điểm, danh sách người được chia sẻ, kích thước tệp, số tệp ảnh. Nội dung chỉ mục của bài này luôn rỗng.
- Mật khẩu yếu có thể bị dò ngoại tuyến nếu ai đó có file. Hãy dùng cụm từ dài. Mất mật khẩu = mất nội dung (người chủ trên thiết bị đã mở còn khóa trong vault).
- Liên kết + mật khẩu: bất kỳ ai đăng nhập Google có liên kết đọc được **bản mã**; không có mật khẩu thì vô nghĩa.

## Quyền riêng tư ảnh

Ảnh được vẽ lại qua canvas trước khi tải lên → **EXIF (GPS, thiết bị, thời gian chụp) bị loại bỏ**. Ảnh được xoay đúng chiều và giới hạn kích thước.

## Giới hạn mô hình chia sẻ

- Người có quyền bình luận có quyền `writer` trên `comments.json`, nên về mặt kỹ thuật có thể sửa/xóa bình luận người khác trực tiếp qua Drive. Ứng dụng chỉ cho xóa bình luận của mình (hoặc chủ bài xóa mọi bình luận).
- Hai người ghi `comments.json` cùng lúc: bản ghi sau thắng (đọc–sửa–ghi, không khóa).
- Người xem có thể sao chép/chụp màn hình — thu hồi quyền không xóa được điều đã thấy.

## Báo lỗi bảo mật

Mở issue riêng tư trên kho mã hoặc liên hệ người duy trì dự án. Vui lòng không đưa khóa thật vào báo cáo.
