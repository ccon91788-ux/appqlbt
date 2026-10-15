# Tích hợp Gemini API — LifeSync

Code của bạn **đã có sẵn** tích hợp Gemini. File đã sửa ở bản này chỉ thêm 2 thứ còn thiếu: dán key trực tiếp + fallback model.

## Luồng hoạt động (đã có trong code)

1. **UI:** `lib/screens/ai_chat_screen.dart` — tab `Gemini AI` (đã gắn trong `lib/main.dart` -> `Shell._pages`).
   - Nhập tin nhắn -> `_send()` -> `GeminiService.instance.chat(history)`
   - AI trả JSON -> hiển thị `reply`, nếu có `events` thì hiện nút **Xem & thêm**
   - Người dùng bấm **Xem & thêm** -> kiểm tra -> `Repo.saveEvent()` mới lưu vào lịch + đặt nhắc nhở.
2. **Service:** `lib/services/gemini_service.dart`
   - `POST https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent?key=<API_KEY>`
   - Body: `system_instruction` + `contents` (role user/model) + `generationConfig: {temperature: 0.4, responseMimeType: application/json}`
   - System prompt bắt AI trả **duy nhất JSON** `{reply, events[]}` với `start` dạng `YYYY-MM-DDTHH:mm:ss`, giờ Việt Nam UTC+7.
   - Key lưu bằng `flutter_secure_storage` (Android EncryptedSharedPreferences), tự xoay key khi gặp 429 / 401 / 403.
   - `pubspec.yaml` đã có: `http`, `flutter_secure_storage`, `excel`, `file_picker` — không cần thêm package.

## Cách dùng (3 bước)

1. Lấy key miễn phí tại https://aistudio.google.com/ -> **Get API key** -> **Create API key**.
   - Đừng commit key vào git, đừng gửi key cho người khác.
2. Trong app: tab **Gemini AI** -> icon bánh răng -> **Dán API key trực tiếp** (mới) hoặc **Nhập từ TXT / Excel**.
   - TXT: file chứa key dạng `AIza...` (có thể nhiều key, mỗi key 1 dòng).
   - Excel: file `.xlsx` quét các ô chứa `AIza...`.
3. Nhắn thử: `Lập lịch calisthenics cho người mới 3 buổi/tuần lúc 18:00, nhắc trước 10 phút`
   - AI trả lời + đề xuất sự kiện -> bấm **Xem & thêm** -> **Thêm lịch**.

## Lỗi thường gặp

| Lỗi | Nghĩa / Cách sửa |
|---|---|
| `Chưa có API key` | Chưa nhập key. Vào bánh răng để dán/nhập. |
| `400` | Request lỗi — thường do lịch sử chat rỗng hoặc JSON sai. Thử nhắn lại câu mới. |
| `401 / 403` | Key sai, bị vô hiệu hoá, hoặc project chưa bật Generative Language API. Tạo key mới, kiểm tra quota trong AI Studio. App sẽ tự thử key tiếp theo. |
| `429` | Hết quota / quá nhiều request. Đợi 1 phút, hoặc thêm key khác. |
| `404` / `... is no longer available. Please update your code to use models/gemini-3.8-flash` | **Key của bạn vẫn đúng — model cũ đã bị Google ngừng hỗ trợ.** `gemini-2.0-flash` rồi `gemini-2.5-flash` đều đã bị ngừng cho key mới. Bản sửa 15/10/2026 dùng alias lăn `gemini-flash-latest` (tự trỏ sang Flash mới nhất) + fallback `gemini-3.8-flash` -> `gemini-3.6-flash` -> `gemini-flash-lite-latest`, và tự đọc model Google gợi ý trong thông báo 404 để thử ngay. Chỉ cần cập nhật app, không cần đổi key. |
| `SAFETY / trống` | Gemini chặn nội dung. Diễn đạt lại yêu cầu. |

## Đã sửa trong bản này

- `GeminiService.addSingleKey()` + `importPastedText()` — dán 1 key hoặc cả đoạn text mà không cần file.
- `GeminiService._callModel()` + `HttpGeminiException` — tách 1 lần gọi API ra riêng, xử lý `SAFETY/BLOCKED`, fallback model 404.
- `AiChatScreen._pasteKey()` + nút **Xóa đoạn chat** — UX cho người dùng mới.
- Không đổi contract JSON, không đổi cách lưu key, không thêm dependency mới.

## Sửa lỗi 404 ngày 15/10/2026 — model bị ngừng hỗ trợ

- Nguyên nhân: code cũ ghim `gemini-2.5-flash` -> `gemini-2.0-flash`. Google đã ngừng cả 2 cho key mới, nên mọi request đều 404 dù key đúng. Lỗi này **không phải** do hết quota hay sai key.
- Sửa trong `lib/services/gemini_service.dart`:
  - `_models = [gemini-flash-latest, gemini-3.8-flash, gemini-3.6-flash, gemini-flash-lite-latest]` — alias `gemini-flash-latest` không bị "thối" khi Google đổi model.
  - `_suggestedModel()` — đọc model Google gợi ý trong thông báo 404 (ví dụ `models/gemini-3.8-flash`) và thử ngay, chống lỗi tương tự trong tương lai.
  - Thông báo lỗi 404 giờ ngắn gọn, bằng tiếng Việt, thay vì in nguyên đoạn dài của Google.
  - `testKey()` thử hết danh sách model, không chỉ model đầu.
- Về gợi ý "use the Interactions API" trong thông báo lỗi: đó chỉ là khuyến nghị của Google, **không bắt buộc**. `generateContent` (v1beta) vẫn chạy với model mới, nên bản này không chuyển API — tránh thay đổi lớn không cần thiết.

## Build / test

```bash
flutter pub get
flutter test
flutter build apk --release
```

## Bảo mật

- Key nằm trong app -> ai giải mã APK vẫn có thể lấy được. Đây là mức chấp nhận được cho app cá nhân/offline.
- Nếu phát hành công khai: chuyển sang gọi Gemini qua backend của bạn (backend giữ key, app gọi backend bằng token người dùng), và bật giới hạn quota / IP trong Google Cloud Console.
