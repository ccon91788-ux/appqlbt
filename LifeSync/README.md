# LifeSync – Lịch, nhắc nhở & quản lý tài chính (offline)

Ứng dụng Flutter/Android, dữ liệu lưu cục bộ bằng SQLite, không cần tài khoản hay Internet.

## Tính năng
- **Lịch**: xem tháng / tuần / ngày, Hôm nay, nhảy tới ngày, lịch âm (bật/tắt), sự kiện có giờ bắt đầu - kết thúc, nhắc trước (đúng giờ … 1 ngày), lặp ngày/tuần/tháng/năm (lặp thật), thông báo âm thanh + rung
- **Tài chính**: thu/chi, danh mục tự nhập, tiền lưu số nguyên VND (`50,000 ₫`), tìm kiếm, Nhập nhanh tiếng Việt (luôn có màn hình xác nhận)
- **Ngân sách tháng**: thanh tiến độ, còn lại, cảnh báo 80/90/100% (mỗi mức một lần mỗi tháng), bật/tắt, đặt lại
- **Mục tiêu tiết kiệm**: thanh tiến độ %, thêm/rút tiền, sửa/xóa, hạn chót và số tiền cần để dành mỗi tháng
- **Thống kê**: tổng thu/chi/số dư/tiết kiệm, biểu đồ tròn theo danh mục, cột thu-chi, xu hướng 6 tháng, lọc tháng này/trước/3/6 tháng/năm nay/tùy chọn
- **Ghi chú**: tạo/sửa/xóa, ghim, chọn màu pastel, tìm kiếm
- **Nhiệm vụ** (tab trong Ghi chú): thêm/sửa/xóa, tick hoàn tất, nhóm "Hoàn tất N" thu gọn được, **Đặt nhắc nhở** (ngày + giờ, thông báo 1 lần, hiển thị "Hôm nay 20:18" / "Ngày mai ..."), tìm kiếm, lưu SQLite + kèm sao lưu/khôi phục
- **Sơ đồ tư duy**: tạo nhiều sơ đồ, thêm/sửa/xóa chủ đề và nhánh con; dữ liệu được lưu cục bộ trên thiết bị.
- **Sơ đồ tư duy**: 4 kiểu bố cục chuyển đổi được (hai phía, sang phải, sang trái, từ trên xuống — nút bánh răng kiểu sơ đồ trên thanh công cụ, lưu theo từng sơ đồ).
- **Google Drive**: kết nối trong Cài đặt (biểu tượng bánh răng) để sao lưu lên Drive (thư mục ẩn riêng của app) và khôi phục sau khi xóa app cài lại; có chế độ tự động sao lưu khi mở app. Cách tạo OAuth client xem `DRIVE_SETUP.md`.
- **Flashcards**: học tiếng Anh kiểu Quizlet — tạo bộ thẻ (từ — nghĩa — ví dụ), chế độ Học lật thẻ (Đã nhớ / Chưa nhớ, xáo trộn, chỉ học thẻ chưa nhớ) và Trắc nghiệm 4 lựa chọn có chấm điểm và làm lại câu sai; mở lần đầu có sẵn bộ mẫu 20 từ.
- **Flashcards**: nhập nhiều thẻ cùng lúc từ văn bản dán vào (nút tải lên trong bộ thẻ): chọn dấu phân cách giữa từ và nghĩa (Tab / phẩy / hai chấm / tùy chỉnh) và giữa các thẻ (xuống dòng / chấm phẩy / tùy chỉnh), xem trước rồi mới nhập; phiên âm dạng /.../ được tách riêng và hiển thị dưới từ khi học.
- **Flashcards — Ôn tập kiểu Anki (Spaced Repetition)**: mỗi thẻ có lịch ôn riêng (ngày ôn tiếp theo, khoảng cách ôn, hệ số dễ); danh sách bộ thẻ và trang bộ thẻ hiện Mới / Đang học / Đến hạn; nút **Ôn tập** chỉ ôn thẻ đến hạn + tối đa 20 thẻ mới mỗi phiên, sau khi lật thẻ chấm **Lại / Khó / Tốt / Dễ** (mỗi nút hiện sẵn lần ôn tiếp theo, ví dụ Lại 10 phút nữa, Tốt 3 ngày, Dễ 7 ngày; thẻ chấm Lại được ôn lại cuối phiên); thẻ có thêm ảnh minh họa (link, không bắt buộc) và nút đặt lại lịch ôn cả bộ. Thẻ cũ vẫn giữ nguyên: thẻ đã nhớ thành thẻ đang ôn, đến hạn hôm nay.
- **Flashcards — bản đơn giản cho bé (dễ dùng, dễ nhớ)**: mỗi bộ thẻ có chủ đề (tag: Động vật, Thức ăn, Màu sắc, Gia đình, Trường học, Cơ thể, Thiên nhiên, Đồ chơi, Khác) + hình đại diện + màu riêng, chọn khi tạo hoặc sửa bộ thẻ; mỗi thẻ có thêm 1 emoji giúp nhớ bằng hình; thẻ chữ to, nút to; chế độ Ôn tập chỉ còn 3 nút mặt cười to — 😢 Chưa nhớ (lát nữa ôn lại), 🙂 Nhớ rồi, 😄 Nhớ rất rõ — mỗi nút hiện lần ôn tiếp theo bằng lời đơn giản (Lát nữa / Ngày mai / Sau N ngày), lịch ôn Anki bên dưới vẫn giữ nguyên; nút loa 🔊 trên thẻ để nghe đọc từ tiếng Anh (giọng đọc của máy, đọc chậm, tự động đọc khi sang thẻ mới), có ở Ôn tập, Học và Trắc nghiệm; Trắc nghiệm có sao ⭐ theo điểm. Tạo bộ thẻ có thể đính kèm file .txt, và nhập từ văn bản cũng có nút chọn file .txt — file có hơn 100 thẻ vẫn nhập hết trong một lần, thẻ trùng bị bỏ qua. File `sample_120_words.txt` kèm theo là ví dụ 120 từ để thử nhập file. Lần mở đầu tiên có sẵn 3 bộ mẫu theo chủ đề: Động vật, Màu sắc, Thức ăn (mỗi bộ 10 thẻ).
- **Thi thử (đề thi thật, có tính giờ)**: mở bằng nút **Thi thử** trên thanh công cụ của tab Flashcards (`lib/screens/exam_screen.dart`). Khác với Trắc nghiệm (không tính giờ, chỉ hỏi từ trong một bộ thẻ), Thi thử làm cả một đề: chọn thời gian trước khi thi (mặc định theo đề, ví dụ 50 phút; có thể đổi 15 / 30 / 45 / 50 / 60 phút hoặc tự nhập 5–180 phút), đồng hồ đếm ngược dạng giờ:phút:giây (đỏ khi còn dưới 5 phút), hết giờ tự động nộp bài. Giao diện giống app thi trên điện thoại: hàng trên là đồng hồ + nút **NỘP BÀI**, hàng dưới là nút **< DANH SÁCH CÂU HỎI >** để mở bảng chọn câu và nhảy tới câu bất kỳ, xem câu nào chưa làm. Làm câu nào trước cũng được, chạm đáp án khác để đổi ý bất cứ lúc nào còn thời gian, có nút **Bỏ chọn đáp án này** để bỏ đáp án đã chọn. Nút **Giấy nháp** (biểu tượng ghi chú trên thanh công cụ) mở tờ nháp để ghi công thức, từ vựng cần nhớ trong lúc thi; nháp được lưu theo từng đề, mở lại vẫn còn. Chỉ sau khi nộp bài hoặc hết giờ mới hiện điểm (số câu đúng/tổng, %, sao ⭐), thời gian đã dùng, và giải thích từng câu bằng tiếng Việt (đúng/sai, đáp án đúng, lý do) — trong lúc thi không có gợi ý đúng/sai nào. Đề thi lưu riêng ở SharedPreferences và được đưa vào bản sao lưu Google Drive. Đề mẫu kèm sẵn: **Đề thi thử THPT 2026 – Mã 1101** (40 câu, 50 phút) trong `assets/exams/de_thi_1101.txt`, được chép từ ảnh đề thi. Đề khác nhập bằng file .txt hoặc dán văn bản theo định dạng ghi ở đầu file mẫu: dòng `#ĐỀ:`, `#PHÚT:`, khối `[ĐOẠN id]...[/ĐOẠN]`, câu `Q|số|id_đoạn|câu hỏi|A|B|C|D|đáp án|giải thích` (xuống dòng trong câu hỏi viết bằng `\n`).
- Ô nhập tiền tự thêm dấu phân cách (1500000 → 1,500,000)
- Sao lưu/khôi phục JSON (phiên bản 2, vẫn nhập được bản 1), xuất CSV UTF-8, giao diện sáng/tối/hệ thống

- **Sticker vịt**: 28 sticker trong `assets/stickers/`, danh mục mặc định hiển thị bằng sticker (đổi ở `lib/stickers.dart`), danh mục tự nhập dùng emoji


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
`flutter test` gồm: logic thuần (nhập nhanh, ngân sách, tiết kiệm, lịch âm, định dạng tiền, sao lưu) và test **trên SQLite thật** (`test/db_test.dart`, dùng `sqflite_common_ffi`, cần `libsqlite3-dev` trên Linux — workflow đã cài sẵn), gồm cả kiểm tra nâng cấp CSDL từ phiên bản 1 lên 6 và CRUD nhiệm vụ.
