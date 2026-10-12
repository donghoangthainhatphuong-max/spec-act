# CLAUDE.md — quy tắc làm việc trong dự án SPECACT

Đọc hết trước khi sửa code. Mỗi quy tắc bên dưới tồn tại vì một lỗi đã xảy ra thật. Khi gặp lỗi mới, **thêm quy tắc vào đây trong cùng commit sửa lỗi**.

## 1. Bất biến của sản phẩm (không được phá)

1. **Không có backend.** Trình duyệt chỉ nói chuyện với `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`. Không thêm CDN, analytics, font ngoài, hay endpoint nào khác (CSP trong `docker/security-headers.conf` sẽ chặn; sửa CSP chỉ khi thật sự cần và phải nêu lý do).
2. **Drive là nguồn sự thật cho dữ liệu và quyền truy cập.** Không tự phát minh hệ thống quyền riêng. `post.json.audience` chỉ là bản sao để hiển thị.
3. **Mọi bí mật phía client** (client ID/secret, refresh token, khóa bài, cache chỉ mục) chỉ nằm trong `services/secureStore.js` (mã hóa 2 lớp: khóa thiết bị + PIN). Không bao giờ ghi chúng vào `localStorage`, URL, log, hay `.env`. Access token chỉ ở bộ nhớ.
4. **Công khai bằng liên kết chỉ cấp quyền trên TỆP** (`post.json` + ảnh), **không bao giờ trên thư mục** và không trên `comments.json`. Mọi thay đổi liên quan phải giữ test "link sharing opens FILES only".
5. **Người có quyền bình luận chỉ được `writer` trên `comments.json`**, không bao giờ trên thư mục hay `post.json`.
6. Bài có mật khẩu: nội dung, bình luận và byte ảnh mã hóa ở client; **không đưa nội dung vào `index.json`**.
7. Không `v-html`, không `innerHTML` với dữ liệu người dùng. Văn bản hiển thị qua `RichText.vue` (đoạn text/mention/link an toàn).
8. Việc xóa/thu hồi/ghi đè quyền phải **tường minh**: gỡ `@mention` khỏi văn bản không thu hồi quyền; chỉnh sửa không được thu hồi người được chia sẻ tay trong Drive (xem `updatePost`/`setAccess`).

## 2. Lỗi đã gặp → quy tắc

| Lỗi từng xảy ra | Quy tắc |
|---|---|
| `ui.openViewer(items, index)` bị gọi với object `{post, items}` → khung xem ảnh **trống**, không có slide. Chỉ test demo bằng mắt nên sót. | Khi đổi chữ ký hàm dùng chung, `grep` mọi nơi gọi và cập nhật. Mỗi store action phải có test đơn vị (`tests/ui.test.js` là ví dụ). Khi sửa UI, **mở trình duyệt và thao tác thật** (bấm ảnh, next/prev, zoom), không chỉ build/test. |
| Nút next/prev bị CSS thiết kế cũ `.viewer .icon-btn {top:16px}` đẩy lên góc trùng nút đóng. | CSS toàn cục của thiết kế (`src/styles/*.css`) có độ ưu tiên cao hơn CSS scoped. Style lớp phủ/overlay phải dùng selector đủ cụ thể (`.viewer .icon-btn.nav`) và **đo vị trí bằng `getBoundingClientRect`** sau khi sửa. |
| Công khai bài ban đầu yêu cầu mật khẩu, rồi cấp quyền `anyone` trên **thư mục** → lộ cấu trúc/bình luận. | Cấp quyền công khai ở mức tối thiểu cần thiết (từng tệp). Trước khi thêm bất kỳ quyền Drive nào, ghi rõ ai/đối tượng nào/cấp nào, và viết test kiểm tra thứ KHÔNG được mở. |
| Chức năng chỉ thêm ở màn hình chi tiết, quên màn hình tạo bài. | Tính năng ảnh hưởng nhiều luồng (tạo / sửa / chi tiết / demo) phải được thêm ở **cả** `ComposeView`, `PostView`, `repo.js` **và** `demoRepo.js`, rồi liệt kê trong mô tả commit. |
| Thao tác sửa audience từ form bị thu hồi người được chia sẻ tay trong Drive. | Không suy ra quyền từ bản sao `post.json`; đọc thực tế bằng `readAudience`. Chỉ đụng quyền khi caller truyền `audience`. |
| `expireSession` chạy bất đồng bộ không `await` → trạng thái UI sai khoảng ngắn (test phát hiện). | Mọi chuyển trạng thái xác thực phải `await` xong trước khi hàm gọi trả về. |
| vue-i18n coi `@` trong chuỗi là cú pháp liên kết → app crash khi mở trang. | Dùng lớp i18n tự viết (`src/i18n`); chuỗi dịch là JSON phẳng, chỉ có `{name}`. Không đưa vue-i18n trở lại. |
| `docker compose` dùng tên container/image `specact` trùng dự án khác của người dùng. | Tên Docker của dự án này luôn là `spec-act`; không động vào container/image khác (`docker ps` trước khi chạy). Cổng mặc định 8088. |
| Đợt đầu `FakeDrive` dùng `Buffer` → không chạy được trong trình duyệt. | Mã dùng chung giữa Node và trình duyệt không dùng API riêng của Node. |

## 3. Quy trình bắt buộc cho mỗi thay đổi

1. **Hiểu trước, sửa sau**: đọc file liên quan và nơi gọi (`grep`), không đoán.
2. **Viết/cập nhật test** cùng lúc với code. Logic Drive/quyền → thêm ca vào `tests/repo.test.js` (dùng `tests/fakeDrive.js`). Nếu hành vi thật của Drive khác giả lập, sửa giả lập trước.
3. Chạy đủ: `npm run lint && npm test && npm run build`. Không commit khi đỏ.
4. **Kiểm tra bằng giao diện thật** (`npm run dev`): demo ở `#/demo`; luồng Drive dùng `tests/browserHarness.js`. Kiểm tra cả sáng/tối, mobile (390px) và desktop. Đợi ~1–2 giây trước khi chụp màn hình (ảnh có animation/tải lười).
5. **i18n**: thêm khóa vào `src/locales/en.json` **và đủ 14 ngôn ngữ** (`tests/i18n.test.js` bắt thiếu khóa, thừa khóa, sai placeholder). Đổi ý nghĩa một chuỗi → cập nhật bản dịch của mọi ngôn ngữ, không để chuỗi cũ sai nghĩa.
6. **Cấu hình**: tham số mới đi qua `src/config.js` + `.env.example` + `.env` + README. Không hard-code.
7. Cập nhật tài liệu (`README*.md`, `docs/`) khi đổi hành vi/giới hạn. Không hứa điều chưa kiểm chứng; nói rõ phần nào chưa thử với Google Drive thật.
8. Commit nhỏ, thông điệp tiếng Anh nêu **vì sao**. Không push khi chưa được yêu cầu; không commit `.env` chứa bí mật, `node_modules`, `dist`.

## 4. Quy ước mã

- Vue 3 `<script setup>`, Pinia (setup stores), JS thuần (không TypeScript). Tên tệp component `PascalCase.vue`.
- Mọi gọi Drive đi qua `services/drive.js`; mọi nghiệp vụ qua `services/repo.js` (và `demoRepo.js` có **cùng giao diện**). Component không gọi `fetch` trực tiếp.
- Mọi chuỗi hiển thị qua `t('...')`; không hard-code tiếng Anh/Việt trong template.
- Lỗi nghiệp vụ dùng `RepoError(code)`; UI ánh xạ `code` sang chuỗi i18n, không hiển thị `error.message` thô.
- Giữ giao diện theo thiết kế v3 (token màu trong `styles/base.css`, phông Bricolage/Newsreader, accent xanh lục). Thêm CSS mới vào `styles/extra.css` hoặc scoped; không viết lại CSS thiết kế.
- Hỗ trợ RTL (dùng thuộc tính logic `inset-inline-*`, `margin-inline-*`).

## 5. Dọn dẹp sau khi làm

- Dừng dev server (`pkill -f "vite --port"`) và container tự bật (`docker compose down`); không dừng container của dự án khác.
- Không để file tạm trong repo.
