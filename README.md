# LifeSync – Lịch, nhắc nhở & quản lý tài chính (offline)

Ứng dụng Flutter/Android, dữ liệu lưu cục bộ bằng SQLite, không cần tài khoản hay Internet.

## Tính năng
- **Lịch**: xem tháng / tuần / ngày, Hôm nay, nhảy tới ngày, lịch âm (bật/tắt), sự kiện có giờ bắt đầu - kết thúc, nhắc trước (đúng giờ … 1 ngày), lặp ngày/tuần/tháng/năm (lặp thật), thông báo âm thanh + rung
- **Tài chính**: thu/chi, danh mục tự nhập, tiền lưu số nguyên VND (`50,000 ₫`), tìm kiếm, Nhập nhanh tiếng Việt (luôn có màn hình xác nhận)
- **Ngân sách tháng**: thanh tiến độ, còn lại, cảnh báo 80/90/100% (mỗi mức một lần mỗi tháng), bật/tắt, đặt lại
- **Mục tiêu tiết kiệm**: thanh tiến độ %, thêm/rút tiền, sửa/xóa, hạn chót và số tiền cần để dành mỗi tháng
- **Thống kê**: tổng thu/chi/số dư/tiết kiệm, biểu đồ tròn theo danh mục, cột thu-chi, xu hướng 6 tháng, lọc tháng này/trước/3/6 tháng/năm nay/tùy chọn
- **Ghi chú**: tạo/sửa/xóa, ghim, chọn màu pastel, tìm kiếm
- **Gemini AI**: màn hình chat riêng; nhập nhiều API key từ TXT/XLSX; lưu key bằng Android secure storage; tự chuyển key khi gặp quota/lỗi xác thực; AI có thể đề xuất lịch và nhắc nhở, chỉ ghi vào lịch sau khi người dùng xác nhận
- Ô nhập tiền tự thêm dấu phân cách (1500000 → 1,500,000)
- Sao lưu/khôi phục JSON (phiên bản 2, vẫn nhập được bản 1), xuất CSV UTF-8, giao diện sáng/tối/hệ thống

- **Sticker vịt**: 28 sticker trong `assets/stickers/`, danh mục mặc định hiển thị bằng sticker (đổi ở `lib/stickers.dart`), danh mục tự nhập dùng emoji

## Gemini AI
- Cần tự cung cấp Gemini API key từ Google AI Studio và kết nối Internet. API key có thể phát sinh giới hạn/quota riêng; chuyển key không giúp khi mọi key đều hết hạn mức.
- Tệp TXT hỗ trợ trích xuất key dạng `AIza...`; Excel hỗ trợ `.xlsx` và quét các ô có chứa key.
- AI tạo bản đề xuất sự kiện; người dùng phải bấm **Xem & thêm** để lưu và lập thông báo. Đề xuất địa điểm hiện chưa có tìm kiếm bản đồ/địa điểm trực tiếp, nên AI không xác nhận địa điểm đang mở hoặc gần vị trí hiện tại.
- API key được lưu trong vùng lưu trữ bảo mật của Android; không nên chia sẻ tệp chứa key.

## Hạn chế đã biết
- Sự kiện lặp theo năm vào ngày 29/2 chỉ nhắc ở năm nhuận.
- Ngân sách chỉ đặt cho tháng hiện tại; danh mục là chữ tự do (chưa có bảng danh mục riêng).
- Tìm kiếm chỉ áp dụng cho giao dịch.

## Build bằng GitHub Actions
1. Đẩy toàn bộ thư mục này lên một repo GitHub.
2. Tab **Actions** → workflow **Build APK** (tự chạy khi push, hoặc bấm *Run workflow*).
3. Khi xong, mở lần chạy → mục **Artifacts** → tải `LifeSync-release-apk` (chứa `app-release.apk`).

Workflow tự chạy `flutter create` để sinh thư mục `android/`, rồi `tool/patch_android.py` thêm quyền thông báo, receiver khởi động lại máy và core library desugaring.

## Build trên máy
```
flutter create --platform=android --org com.lifesync --project-name lifesync .
python3 tool/patch_android.py
flutter pub get && flutter test && flutter build apk --release
```

## Quyền thông báo
Android 13+: cho phép thông báo khi được hỏi. Nếu chưa cấp quyền báo thức chính xác, app dùng báo thức không chính xác (có thể trễ vài phút). Mở Cài đặt → Ứng dụng → LifeSync → Báo thức & lời nhắc để bật.

## Lưu ý
Múi giờ thông báo cố định Asia/Ho_Chi_Minh. APK release ký bằng khóa debug (đủ để cài thử).

## Cập nhật app mà không cần gỡ bản cũ
1. Tạo khóa ký cố định một lần (xem hướng dẫn trong cuộc trò chuyện) và lưu vào GitHub Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`.
2. Mỗi lần push, workflow ký APK bằng khóa đó và đánh số phiên bản tăng dần (`--build-number`).
3. Trong app, hộp thoại "Có bản cập nhật mới" -> "Cập nhật": app tự tải (có thanh tiến độ) rồi mở trình cài đặt của Android. Hoặc tải bản mới nhất tại: `https://github.com/<tài-khoản>/<repo>/releases/latest/download/LifeSync.apk` rồi cài đè.
Không làm mất khóa ký: mất khóa thì không thể cập nhật đè được nữa.

## Kiểm thử
`flutter test` gồm: logic thuần (nhập nhanh, ngân sách, tiết kiệm, lịch âm, định dạng tiền, sao lưu) và test **trên SQLite thật** (`test/db_test.dart`, dùng `sqflite_common_ffi`, cần `libsqlite3-dev` trên Linux — workflow đã cài sẵn), gồm cả kiểm tra nâng cấp CSDL từ phiên bản 1 lên 5.
