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
| `404` | Model chưa khả dụng cho key/project đó. Bản sửa này tự fallback `gemini-2.5-flash` -> `gemini-2.0-flash`. |
| `SAFETY / trống` | Gemini chặn nội dung. Diễn đạt lại yêu cầu. |

## Đã sửa trong bản này

- `GeminiService.addSingleKey()` + `importPastedText()` — dán 1 key hoặc cả đoạn text mà không cần file.
- `GeminiService._callModel()` + `HttpGeminiException` — tách 1 lần gọi API ra riêng, xử lý `SAFETY/BLOCKED`, fallback model 404.
- `AiChatScreen._pasteKey()` + nút **Xóa đoạn chat** — UX cho người dùng mới.
- Không đổi contract JSON, không đổi cách lưu key, không thêm dependency mới.

## Build / test

```bash
flutter pub get
flutter test
flutter build apk --release
```

## Bảo mật

- Key nằm trong app -> ai giải mã APK vẫn có thể lấy được. Đây là mức chấp nhận được cho app cá nhân/offline.
- Nếu phát hành công khai: chuyển sang gọi Gemini qua backend của bạn (backend giữ key, app gọi backend bằng token người dùng), và bật giới hạn quota / IP trong Google Cloud Console.
