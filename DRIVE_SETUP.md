# Kết nối Google Drive cho LifeSync

App dùng quyền duy nhất `drive.appdata`: bản sao lưu nằm trong thư mục ẩn
riêng của app trên Drive (bạn không thấy tệp này khi mở Drive, app khác cũng
không đọc được). Nhờ vậy, sau khi xóa app cũ và cài bản mới, chỉ cần đăng
nhập lại Google trong Cài đặt rồi bấm **Khôi phục từ Drive** là lấy lại toàn
bộ dữ liệu: lịch, tài chính, ghi chú, nhiệm vụ, sơ đồ tư duy và flashcards.

## 1. Tạo OAuth client trên Google Cloud (làm một lần)

1. Vào [Google Cloud Console](https://console.cloud.google.com/) → tạo project
   mới (ví dụ tên `LifeSync`) → bật API **Google Drive API**
   (APIs & Services → Library → tìm "Google Drive API" → Enable).
2. APIs & Services → **OAuth consent screen** → User Type **External** →
   **Testing** → ở mục Test users, bấm **Add users** và thêm chính Gmail của
   bạn. (Dùng cá nhân thì để ở chế độ Testing là đủ, không cần xác minh app.)
3. APIs & Services → **Credentials** → **Create Credentials** →
   **OAuth client ID** → Application type **Android**:
   - Package name: `com.lifesync.lifesync` (do workflow build với
     `--org com.lifesync --project-name lifesync`).
   - SHA-1 certificate fingerprint: lấy từ keystore dùng để ký APK.
     - Build local bằng khóa debug:
       `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
     - Build bằng GitHub Actions với khóa ký cố định (secrets
       `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS`): dùng SHA-1
       của chính keystore đó.
     - Mỗi keystore khác nhau cần một OAuth client riêng — nếu đổi keystore,
       tạo thêm một client Android mới với SHA-1 mới.
4. Tải **google-services.json** của project (Credentials → OAuth client vừa
   tạo, hoặc project settings) và đặt vào `android/app/google-services.json`
   trong repo, rồi push. Lưu ý: workflow chạy `flutter create` để sinh thư mục
   `android/` — sau lần build đầu tiên hãy kiểm tra tệp này vẫn còn trong
   `android/app/` (đây là tệp của bạn, `flutter create` không xóa nó, nhưng
   nếu mất thì copy lại).

## 2. Dùng trong app

1. Cài app mới → mở tab **Tài chính** → bấm biểu tượng **bánh răng** ⚙️ →
   mục **Google Drive** → **Kết nối Google Drive** → chọn tài khoản Gmail
   (tài khoản đã thêm ở Test users).
2. Bấm **Sao lưu ngay** để đưa dữ liệu hiện tại lên Drive. Bật
   **Tự động sao lưu khi mở app** để mỗi lần mở app là có một bản mới trên
   Drive.
3. Sau này xóa app và cài lại: vào Cài đặt → Google Drive → **Kết nối
   Google Drive** bằng cùng tài khoản. Nếu đã có bản sao lưu, app hỏi ngay
   **"Tìm thấy bản sao lưu trên Drive — Khôi phục ngay?"** → bấm Khôi phục.
   Bạn cũng có thể bấm **Khôi phục từ Drive** bất cứ lúc nào.

## 3. Sự cố thường gặp

- **"Access blocked" / lỗi 403 khi đăng nhập**: tài khoản chưa nằm trong danh
  sách Test users của OAuth consent screen → thêm Gmail đó vào rồi thử lại.
- **Lỗi 10 (DEVELOPER_ERROR) khi đăng nhập**: sai package name hoặc SHA-1,
  hoặc thiếu `google-services.json` trong `android/app/` → kiểm tra lại
  bước 1 (mục 3 và 4).
- **Không thấy bản sao lưu**: bản sao lưu nằm trong thư mục appDataFolder
  (ẩn) nên không hiện trong ứng dụng Drive — bấm **Khôi phục từ Drive** trong
  app để kiểm tra, đừng tìm tệp bằng tay.
- **Đăng xuất** chỉ ngắt phiên trên máy; dữ liệu trên Drive vẫn còn cho đến
  khi bạn xóa quyền của app tại
  https://myaccount.google.com/permissions (mục "LifeSync").
