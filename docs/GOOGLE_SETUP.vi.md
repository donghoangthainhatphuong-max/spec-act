# Thiết lập Google OAuth

[English](GOOGLE_SETUP.md)

SPECACT không có “app chung”: **mỗi người tự tạo OAuth client của mình** (miễn phí, khoảng 5 phút). Nhờ vậy khóa của bạn không bao giờ rời thiết bị và không ai khác — kể cả người host trang — giữ được quyền truy cập Drive của bạn.

## 1. Tạo dự án và bật Drive API

1. Vào <https://console.cloud.google.com/projectcreate> → tạo một dự án (tên tùy ý).
2. Vào <https://console.cloud.google.com/apis/library/drive.googleapis.com> → **Enable** *Google Drive API*.

## 2. Màn hình đồng ý (OAuth consent screen)

1. **APIs & Services → OAuth consent screen** → User type **External** → điền tên ứng dụng và email.
2. Không cần thêm scope ở đây (SPECACT yêu cầu `https://www.googleapis.com/auth/drive` khi đăng nhập).
3. *Test users*: thêm **Gmail của bạn** (và Gmail của những người đăng nhập qua cùng dự án này). Nếu mỗi người tự tạo dự án (khuyến nghị) thì mỗi người chỉ cần thêm chính mình.

> Khi ở trạng thái **Testing**, refresh token hết hạn sau 7 ngày — chỉ cần bấm *Tiếp tục với Google* lần nữa; PIN và khóa vẫn còn trên thiết bị. Chuyển sang **In production** để không bị hết hạn 7 ngày (Google hiện cảnh báo “chưa xác minh”, không sao với dùng cá nhân).

## 3. Tạo OAuth client

1. **Credentials → Create credentials → OAuth client ID**.
2. Application type: **Web application**.
3. **Authorized JavaScript origins**: địa chỉ gốc của trang, ví dụ `http://localhost:5173` hoặc `https://specact.example.com` (SPECACT hiển thị sẵn giá trị đúng ở màn hình nhập khóa, có nút sao chép).
4. **Authorized redirect URIs**: đúng địa chỉ trang, **có dấu `/` cuối**, ví dụ `http://localhost:5173/` hoặc `https://specact.example.com/`.
5. **Create**, rồi sao chép **Client ID** (`…apps.googleusercontent.com`) và **Client secret** (`GOCSPX-…`).

## 4. Nhập vào SPECACT

Mở ứng dụng → **Tiếp tục với Google** → tạo mã PIN 6 số → dán Client ID / Client secret → **Lưu và tiếp tục với Google** → đồng ý quyền Drive. SPECACT tự tạo thư mục `SPECACT` trong Drive của bạn.

Khóa được lưu **mã hóa hai lớp chỉ trên thiết bị này**. Sửa lại trong *Cài đặt → Bảo mật → Khóa Google*.

## 5. Dùng client nào cho app nào

SPECACT có hai bản nói chuyện với Google theo cách khác nhau nên cần **loại client khác nhau** (có thể cùng nằm trong một project Google Cloud; bước 1–2 dùng chung):

| Ứng dụng | Loại client | Redirect URI cần khai báo |
|---|---|---|
| Bản web (`npm run dev`, Docker, host riêng) | **Web application** | Địa chỉ trang kèm dấu `/` ở cuối (bước 3) |
| App Android (APK Flutter) | **Desktop app** | Không cần — Google chấp nhận mọi `http://127.0.0.1:<cổng>` |
| Xem thử Flutter web (`flutter run -d chrome --web-port 8099`) | **Web application** (hoặc Desktop) | `http://localhost:8099/` |

### App Android (Flutter)

1. **Credentials → Create credentials → OAuth client ID → Application type: Desktop app** → đặt tên, ví dụ *SPECACT Android* → **Create**. Sao chép **Client ID** và **Client secret**. (**Đừng** dùng lại client Web: app Android đăng nhập qua một địa chỉ cục bộ có cổng ngẫu nhiên, client Web sẽ từ chối với lỗi `redirect_uri_mismatch`.)
2. Đảm bảo Gmail của bạn nằm trong danh sách *test user* (bước 2).
3. Cài APK, mở app, dán Client ID / Client secret, chọn PIN 6 số, rồi **Continue with Google**. Trình duyệt hệ thống sẽ mở; bạn chấp nhận quyền rồi quay lại SPECACT.
4. "Secret" của client Desktop vốn không phải bí mật tuyệt đối; SPECACT vẫn chỉ lưu nó trong vault mã hóa trên thiết bị.

Nếu đăng nhập bị treo sau khi bạn đồng ý trong trình duyệt, có thể điện thoại đã tạm dừng SPECACT khi nó chạy nền — mở lại SPECACT và thử lại (xem [../flutter/README.vi.md](../flutter/README.vi.md)).

### Xem thử Flutter web

Thêm `http://localhost:8099/` (có dấu `/` cuối) vào **Authorized redirect URIs** của client Web, cho phép pop-up với `localhost:8099`, rồi đăng nhập; pop-up tự đóng khi xong. Dùng *Try the demo* để xem thử không cần Google.

## Vì sao cần phạm vi `drive` đầy đủ?

`drive.file` chỉ thấy file do *chính OAuth client này* tạo. Vì mỗi người một client, bài người khác chia sẻ cho bạn sẽ không thấy được. `drive` là cách duy nhất để mở thư mục được chia sẻ. (SPECACT chỉ đọc/ghi trong cây `SPECACT` và các thư mục bài được chia sẻ; không đụng file khác.)

## Sự cố thường gặp

| Triệu chứng | Nguyên nhân |
|---|---|
| `redirect_uri_mismatch` | Redirect URI trong Google khác địa chỉ trang (thiếu `/` cuối, sai cổng, `http`/`https`). |
| `Error 403: access_denied` | Email chưa được thêm làm *test user* khi ứng dụng ở trạng thái Testing. |
| `invalid_client` | Client ID hoặc secret sai / đã bị xóa. |
| Không nhận được refresh token | Đã từng cấp quyền: vào <https://myaccount.google.com/permissions>, gỡ SPECACT rồi đăng nhập lại. |
| Hết phiên sau 7 ngày | Dự án đang ở *Testing* — đăng nhập lại hoặc chuyển *In production*. |
| `redirect_uri_mismatch` trên app Android | Bạn dùng client loại *Web application*; hãy tạo client **Desktop app** (bước 5). |
