# Thiết lập Google OAuth / Google OAuth setup

SPECACT không có “app chung”: **mỗi người tự tạo OAuth client của mình** (miễn phí, ~5 phút). Nhờ vậy khóa của bạn không bao giờ rời thiết bị và không ai khác (kể cả người triển khai trang) giữ được quyền truy cập Drive của bạn.

*SPECACT has no shared app: each person creates their own OAuth client (free, ~5 minutes), so your keys never leave your device.*

## 1. Tạo dự án và bật Drive API

1. Vào <https://console.cloud.google.com/projectcreate> → tạo một dự án (tên tùy ý).
2. Vào <https://console.cloud.google.com/apis/library/drive.googleapis.com> → **Enable** *Google Drive API*.

## 2. Màn hình đồng ý (OAuth consent screen)

1. **APIs & Services → OAuth consent screen** → User type **External** → điền tên ứng dụng và email.
2. Ở bước *Scopes* không cần thêm gì (SPECACT sẽ yêu cầu phạm vi `https://www.googleapis.com/auth/drive` khi đăng nhập).
3. Ở bước *Test users*: thêm **Gmail của bạn và của từng người bạn muốn chia sẻ** *nếu họ dùng chung dự án này*. Nếu mỗi người tự tạo dự án của mình (khuyến nghị) thì chỉ cần thêm chính họ vào dự án của họ.

> Khi ở trạng thái **Testing**, refresh token hết hạn sau 7 ngày — bạn chỉ cần bấm *Tiếp tục với Google* lần nữa; PIN và khóa vẫn còn trên thiết bị. Chuyển sang **In production** (không cần xác minh nếu chỉ bạn dùng, Google sẽ hiện cảnh báo “chưa xác minh”) để token không hết hạn sau 7 ngày.

## 3. Tạo OAuth client

1. **Credentials → Create credentials → OAuth client ID**.
2. Application type: **Web application**.
3. **Authorized JavaScript origins**: địa chỉ gốc của trang, ví dụ `http://localhost:5173` hoặc `https://specact.example.com` (SPECACT hiển thị sẵn giá trị đúng trong màn hình nhập khóa — có nút sao chép).
4. **Authorized redirect URIs**: đúng địa chỉ trang, **có dấu `/` cuối**, ví dụ `http://localhost:5173/` hoặc `https://specact.example.com/`.
5. Bấm **Create**, sao chép **Client ID** (`…apps.googleusercontent.com`) và **Client secret** (`GOCSPX-…`).

## 4. Nhập vào SPECACT

Mở ứng dụng → **Tiếp tục với Google** → tạo mã PIN 6 số → dán Client ID / Client secret → **Lưu và tiếp tục với Google**. Google hỏi quyền truy cập Drive → đồng ý. SPECACT tự tạo thư mục `SPECACT` trong Drive của bạn.

Khóa được lưu **mã hóa hai lớp trên thiết bị này** và không gửi đi đâu. Có thể sửa lại trong *Cài đặt → Bảo mật → Khóa Google*.

## Vì sao cần phạm vi `drive` đầy đủ?

Phạm vi `drive.file` chỉ cho thấy file do *chính OAuth client này* tạo ra. Vì mỗi người có client riêng, bài của người khác chia sẻ cho bạn sẽ không thấy được. Phạm vi `drive` là cách duy nhất để mở thư mục được chia sẻ. (Chỉ ghi/sửa trong cây `SPECACT` và các thư mục bài được chia sẻ; ứng dụng không đụng vào file khác.)

## Sự cố thường gặp

| Triệu chứng | Nguyên nhân |
|---|---|
| `redirect_uri_mismatch` | Redirect URI trong Google khác địa chỉ trang (thiếu `/` cuối, sai cổng, `http`/`https`). |
| `Error 403: access_denied` | Email chưa được thêm làm *test user* khi ứng dụng còn ở trạng thái Testing. |
| `invalid_client` | Client ID hoặc secret sai / đã bị xóa. |
| Không nhận được refresh token | Đã từng cấp quyền trước đó: vào <https://myaccount.google.com/permissions>, gỡ SPECACT rồi đăng nhập lại. |
| Hết phiên sau 7 ngày | Dự án đang ở *Testing* — đăng nhập lại hoặc chuyển *In production*. |
