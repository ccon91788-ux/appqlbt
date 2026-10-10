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
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static const _storage = FlutterSecureStorage();
  static const _keysName = 'gemini_api_keys_v1';
  static const _indexName = 'gemini_api_key_index_v1';
  static const _modelName = 'gemini-2.5-flash';

  Future<List<String>> keys() async {
    final raw = await _storage.read(key: _keysName);
    if (raw == null || raw.isEmpty) return [];
    try { return (jsonDecode(raw) as List).whereType<String>().toList(); }
    catch (_) { return []; }
  }

  Future<void> clearKeys() async {
    await _storage.delete(key: _keysName);
    await _storage.delete(key: _indexName);
  }

  Future<void> saveKeys(Iterable<String> values) async {
    final cleaned = <String>[];
    for (final value in values) {
      final key = value.trim().replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '');
      if (key.isNotEmpty && !cleaned.contains(key)) cleaned.add(key);
    }
    if (cleaned.isEmpty) throw Exception('Không tìm thấy API key hợp lệ trong tệp.');
    await _storage.write(key: _keysName, value: jsonEncode(cleaned));
    await _storage.write(key: _indexName, value: '0');
  }

  Future<void> importText(Uint8List bytes) async {
    final text = utf8.decode(bytes, allowMalformed: true);
    final keys = RegExp(r'AIza[0-9A-Za-z_-]{20,}').allMatches(text)
        .map((match) => match.group(0)!).toList();
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

  Future<String> _request(List<Map<String, String>> history) async {
    final apiKeys = await keys();
    if (apiKeys.isEmpty) throw Exception('Chưa có API key. Bấm biểu tượng bánh răng để nhập key từ TXT hoặc Excel.');
    final storageIndex = int.tryParse(await _storage.read(key: _indexName) ?? '0') ?? 0;
    final start = storageIndex.clamp(0, apiKeys.length - 1);
    String lastError = 'Không thể kết nối Gemini.';
    for (var offset = 0; offset < apiKeys.length; offset++) {
      final index = (start + offset) % apiKeys.length;
      final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$_modelName:generateContent', {'key': apiKeys[index]});
      try {
        final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {'parts': [{'text': _systemPrompt}]},
            'contents': history.map((m) => {'role': m['role'] == 'assistant' ? 'model' : 'user', 'parts': [{'text': m['text']}]}).toList(),
            'generationConfig': {'temperature': 0.4, 'responseMimeType': 'application/json'},
          })).timeout(const Duration(seconds: 45));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _storage.write(key: _indexName, value: '$index');
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final parts = ((body['candidates'] as List?)?.first as Map<String, dynamic>?)?['content']?['parts'] as List?;
          final output = parts?.map((p) => (p as Map)['text']?.toString() ?? '').join() ?? '';
          if (output.isEmpty) throw Exception('Gemini trả về nội dung trống.');
          return output;
        }
        lastError = 'Gemini HTTP ${response.statusCode}: ${_errorMessage(response.body)}';
        // Rotate for quota/rate limit and invalid/restricted keys. Other errors are likely request issues.
        if (response.statusCode != 429 && response.statusCode != 403 && response.statusCode != 401) {
          if (response.statusCode < 500) break;
        }
      } catch (e) {
        lastError = e.toString();
      }
    }
    throw Exception('$lastError\nĐã thử các API key đã nhập. Kiểm tra quota, quyền truy cập và model Gemini.');
  }

  String _errorMessage(String body) {
    try { return (jsonDecode(body)['error']?['message'] ?? 'Lỗi không xác định').toString(); }
    catch (_) { return 'Lỗi không xác định'; }
  }

  Future<GeminiReply> chat(List<Map<String, String>> history) async {
    final raw = await _request(history);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final text = (decoded['reply'] ?? decoded['message'] ?? '').toString().trim();
      final rawEvents = decoded['events'];
      final events = rawEvents is List
          ? rawEvents.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      return GeminiReply(text.isEmpty ? 'Tôi đã xử lý yêu cầu.' : text, events);
    } catch (_) {
      return GeminiReply(raw, const []);
    }
  }

  static const _systemPrompt = '''You are the scheduling assistant inside LifeSync, a Vietnamese calendar and reminders app. Reply in Vietnamese. Return ONLY valid JSON with this schema: {"reply":"brief helpful answer","events":[{"title":"event title","description":"details","start":"YYYY-MM-DDTHH:mm:ss","end":"YYYY-MM-DDTHH:mm:ss or empty string","reminder_min":10,"repeat":0}]}. Use local Vietnam time (UTC+7). repeat: 0 none, 1 daily, 2 weekly, 3 monthly, 4 yearly. reminder_min: -1 no reminder, otherwise minutes before event. Only include events when the user asks to create or change a schedule. Suggest realistic, safe, balanced plans and avoid claiming you have verified live location data. If location is requested, ask for an area or explain that nearby place results require location/search integration. Do not claim events were saved; they require user confirmation in the app. If dates/times are ambiguous, ask a concise clarifying question and return no events. Never schedule events in the past. For training plans, include rest days and beginner-appropriate progression.''';
}
