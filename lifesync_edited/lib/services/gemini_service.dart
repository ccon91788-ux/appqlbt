import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class GeminiReply {
  final String text;
  final List<Map<String, dynamic>> events;
  const GeminiReply(this.text, this.events);
}

/// Stores Gemini keys in Android encrypted storage and rotates on quota/auth failures.
///
/// How integration works:
/// 1. User supplies 1+ API keys from Google AI Studio (aistudio.google.com).
///    Keys are kept ONLY in FlutterSecureStorage, never hard-coded, never in git.
/// 2. [chat] sends the conversation history to
///    POST https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent
///    with `?key=<apiKey>` and a system prompt that forces JSON:
///    {"reply": "...", "events": [...] }.
/// 3. The chat screen parses that JSON, shows `reply`, and only saves `events`
///    after the user taps "Xem & thêm" and confirms.
/// No extra package is needed — plain `http` is enough and keeps the APK small.
/// If you prefer the official SDK, replace the HTTP call with
/// `google_generative_ai` — the JSON contract in [_systemPrompt] stays the same.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static const _storage = FlutterSecureStorage();
  static const _keysName = 'gemini_api_keys_v1';
  static const _indexName = 'gemini_api_key_index_v1';

  // Primary model first, fallback second (used when the primary returns 404
  // for a key / project that does not have access to it yet).
  static const _models = ['gemini-2.5-flash', 'gemini-2.0-flash'];

  Future<List<String>> keys() async {
    final raw = await _storage.read(key: _keysName);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> hasKeys() async => (await keys()).isNotEmpty;

  Future<void> clearKeys() async {
    await _storage.delete(key: _keysName);
    await _storage.delete(key: _indexName);
  }

  static String _cleanKey(String value) =>
      value.trim().replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '');

  /// Replace the whole key list (used by file import).
  Future<void> saveKeys(Iterable<String> values) async {
    final cleaned = <String>[];
    for (final value in values) {
      final key = _cleanKey(value);
      if (key.isNotEmpty && !cleaned.contains(key)) cleaned.add(key);
    }
    if (cleaned.isEmpty) {
      throw Exception('Không tìm thấy API key hợp lệ trong tệp.');
    }
    await _storage.write(key: _keysName, value: jsonEncode(cleaned));
    await _storage.write(key: _indexName, value: '0');
  }

  /// Add one pasted key without wiping the existing ones.
  /// Returns true if the key was new, false if it already existed.
  Future<bool> addSingleKey(String value) async {
    final key = _cleanKey(value);
    if (key.isEmpty) throw Exception('API key trống.');
    if (!key.startsWith('AIza') || key.length < 20) {
      throw Exception('API key không đúng định dạng. Key Gemini thường bắt đầu bằng AIza...');
    }
    final existing = await keys();
    if (existing.contains(key)) return false;
    existing.add(key);
    await _storage.write(key: _keysName, value: jsonEncode(existing));
    return true;
  }

  /// Extract keys from pasted text (allows pasting a whole .txt content).
  Future<int> importPastedText(String text) async {
    final found = RegExp(r'AIza[0-9A-Za-z_-]{20,}')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (found.isEmpty) throw Exception('Không tìm thấy key dạng AIza... trong nội dung đã dán.');
    final before = (await keys()).length;
    for (final k in found) {
      await addSingleKey(k);
    }
    return (await keys()).length - before;
  }

  Future<void> importText(Uint8List bytes) async {
    final text = utf8.decode(bytes, allowMalformed: true);
    final keys = RegExp(r'AIza[0-9A-Za-z_-]{20,}')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
    await saveKeys(keys);
  }

  Future<void> importExcel(Uint8List bytes) async {
    final book = Excel.decodeBytes(bytes);
    final values = <String>[];
    for (final sheet in book.tables.values) {
      for (final row in sheet.rows) {
        for (final cell in row) {
          final value = cell?.value?.toString().trim() ?? '';
          if (value.startsWith('AIza')) values.add(value);
        }
      }
    }
    await saveKeys(values);
  }

  /// One HTTP call for one key + one model. Throws on non-2xx.
  Future<String> _callModel(
    List<Map<String, String>> history,
    String apiKey,
    String model,
  ) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': apiKey},
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': _systemPrompt}
              ]
            },
            'contents': history
                .map((m) => {
                      'role': m['role'] == 'assistant' ? 'model' : 'user',
                      'parts': [
                        {'text': m['text']}
                      ],
                    })
                .toList(),
            'generationConfig': {
              'temperature': 0.4,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpGeminiException(
        response.statusCode,
        _errorMessage(response.body),
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    final first = candidates?.isNotEmpty == true
        ? candidates!.first as Map<String, dynamic>
        : null;

    // Safety / blocked responses come back with no usable parts.
    final finishReason = first?['finishReason']?.toString() ?? '';
    if (finishReason == 'SAFETY' || finishReason == 'BLOCKED') {
      throw Exception(
        'Gemini đã chặn câu trả lời vì lý do an toàn. Hãy thử diễn đạt lại yêu cầu.',
      );
    }

    final parts = first?['content']?['parts'] as List?;
    final output =
        parts?.map((p) => (p as Map)['text']?.toString() ?? '').join() ?? '';
    if (output.isEmpty) {
      throw Exception('Gemini trả về nội dung trống.');
    }
    return output;
  }

  Future<String> _request(List<Map<String, String>> history) async {
    final apiKeys = await keys();
    if (apiKeys.isEmpty) {
      throw Exception(
        'Chưa có API key. Bấm biểu tượng bánh răng để nhập key — dán trực tiếp, hoặc nhập từ TXT / Excel.',
      );
    }
    final storageIndex =
        int.tryParse(await _storage.read(key: _indexName) ?? '0') ?? 0;
    final start = storageIndex.clamp(0, apiKeys.length - 1);
    String lastError = 'Không thể kết nối Gemini.';

    for (var offset = 0; offset < apiKeys.length; offset++) {
      final index = (start + offset) % apiKeys.length;
      for (final model in _models) {
        try {
          final output = await _callModel(history, apiKeys[index], model);
          // Remember the working key so the next call starts from it.
          await _storage.write(key: _indexName, value: '$index');
          return output;
        } on HttpGeminiException catch (e) {
          lastError = 'Gemini HTTP ${e.statusCode}: ${e.message}';
          // 404 on the primary model -> try the fallback model before rotating keys.
          if (e.statusCode == 404) continue;
          // Rotate for quota / rate-limit / invalid / restricted keys.
          if (e.statusCode == 429 || e.statusCode == 403 || e.statusCode == 401) {
            break; // break model loop -> try next key
          }
          // Other 4xx are likely request issues — don't burn through all keys.
          if (e.statusCode < 500) throw Exception(lastError);
          // 5xx: try next key / model.
          break;
        } catch (e) {
          lastError = e.toString();
          break; // network / timeout / parse error — try next key
        }
      }
    }
    throw Exception(
      '$lastError\nĐã thử các API key đã nhập. Kiểm tra quota, quyền truy cập và model Gemini.',
    );
  }

  String _errorMessage(String body) {
    try {
      return (jsonDecode(body)['error']?['message'] ?? 'Lỗi không xác định')
          .toString();
    } catch (_) {
      return 'Lỗi không xác định';
    }
  }

  /// Quick check: does this single key work? Used by the settings UI.
  Future<bool> testKey(String apiKey) async {
    try {
      await _callModel(
        [
          {'role': 'user', 'text': 'Hi'}
        ],
        _cleanKey(apiKey),
        _models.first,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<GeminiReply> chat(List<Map<String, String>> history) async {
    final raw = await _request(history);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final text =
          (decoded['reply'] ?? decoded['message'] ?? '').toString().trim();
      final rawEvents = decoded['events'];
      final events = rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      return GeminiReply(
        text.isEmpty ? 'Tôi đã xử lý yêu cầu.' : text,
        events,
      );
    } catch (_) {
      // Model returned plain text instead of JSON — still show it.
      return GeminiReply(raw, const []);
    }
  }

  static const _systemPrompt = '''You are the scheduling assistant inside LifeSync, a Vietnamese calendar and reminders app. Reply in Vietnamese. Return ONLY valid JSON with this schema: {"reply":"brief helpful answer","events":[{"title":"event title","description":"details","start":"YYYY-MM-DDTHH:mm:ss","end":"YYYY-MM-DDTHH:mm:ss or empty string","reminder_min":10,"repeat":0}]}. Use local Vietnam time (UTC+7). repeat: 0 none, 1 daily, 2 weekly, 3 monthly, 4 yearly. reminder_min: -1 no reminder, otherwise minutes before event. Only include events when the user asks to create or change a schedule. Suggest realistic, safe, balanced plans and avoid claiming you have verified live location data. If location is requested, ask for an area or explain that nearby place results require location/search integration. Do not claim events were saved; they require user confirmation in the app. If dates/times are ambiguous, ask a concise clarifying question and return no events. Never schedule events in the past. For training plans, include rest days and beginner-appropriate progression.''';
}

/// Typed HTTP error so [_request] can decide rotate vs. fail-fast.
class HttpGeminiException implements Exception {
  final int statusCode;
  final String message;
  HttpGeminiException(this.statusCode, this.message);
  @override
  String toString() => 'Gemini HTTP $statusCode: $message';
}
