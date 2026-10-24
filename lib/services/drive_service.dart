import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repo.dart';
import 'backup_service.dart';

/// Sao lưu / khôi phục LifeSync lên Google Drive.
///
/// Chỉ dùng quyền `drive.appdata`: bản sao lưu nằm trong thư mục ẩn riêng của
/// app trên Drive (người dùng không thấy tệp này trong Drive của họ, app khác
/// cũng không đọc được). Nhờ vậy, sau khi xóa app cũ và cài bản mới, chỉ cần
/// đăng nhập lại Google trong Cài đặt rồi bấm "Khôi phục từ Drive" là lấy lại
/// toàn bộ dữ liệu.
///
/// Gói sao lưu trên Drive gồm cả dữ liệu SQLite (lịch, tài chính, ghi chú,
/// nhiệm vụ — qua [Repo.exportJson]) lẫn dữ liệu lưu ở SharedPreferences
/// (sơ đồ tư duy, flashcards). Các khóa prefs dưới đây phải khớp với khóa
/// trong `mind_map_screen.dart` và `flashcards_screen.dart`.
class DriveService {
  static const String _fileName = 'lifesync_backup.json';

  /// Quyền duy nhất app xin: đọc/ghi thư mục dữ liệu riêng của app.
  static const String _scope =
      'https://www.googleapis.com/auth/drive.appdata';

  static const String _mindMapsKey = 'lifesync_mind_maps_v1';
  static const String _flashcardsKey = 'lifesync_flashcards_v1';
  static const String _autoKey = 'drive_auto_backup';
  static const String _lastKey = 'drive_last_backup';

  static final GoogleSignIn _signIn = GoogleSignIn(scopes: <String>[_scope]);

  // ---------------- trạng thái đăng nhập ----------------

  static Future<bool> get isSignedIn async =>
      _signIn.currentUser != null || await _signIn.isSignedIn();

  /// Email tài khoản đã đăng nhập, hoặc null nếu chưa đăng nhập.
  /// Chỉ đăng nhập im lặng (không hiện màn hình chọn tài khoản).
  static Future<String?> get email async {
    var user = _signIn.currentUser;
    user ??= await _signIn.signInSilently();
    return user?.email;
  }

  /// Đăng nhập (hiện màn hình chọn tài khoản Google). Trả về email hoặc null
  /// nếu người dùng hủy.
  static Future<String?> signIn() async {
    final account = await _signIn.signIn();
    return account?.email;
  }

  static Future<void> signOut() async {
    await _signIn.signOut();
  }

  /// Ngắt kết nối hoàn toàn (thu hồi quyền của app trên tài khoản Google).
  static Future<void> disconnect() async {
    try {
      await _signIn.disconnect();
    } catch (_) {}
  }

  // ---------------- Drive API ----------------

  static Future<Map<String, String>?> _headers() async {
    var user = _signIn.currentUser;
    user ??= await _signIn.signInSilently();
    if (user == null) return null;
    return user.authHeaders;
  }

  static Future<drive.DriveApi?> _api() async {
    final headers = await _headers();
    if (headers == null) return null;
    return drive.DriveApi(_AuthClient(headers));
  }

  static Future<drive.File?> _findFile(drive.DriveApi api) async {
    final list = await api.files.list(
      q: "name = '$_fileName' and trashed = false",
      spaces: 'appDataFolder',
      $fields: 'files(id,modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  /// Thời điểm bản sao lưu trên Drive được sửa lần cuối, hoặc null.
  static Future<DateTime?> backupTime() async {
    final api = await _api();
    if (api == null) return null;
    final file = await _findFile(api);
    return file?.modifiedTime;
  }

  /// Gói toàn bộ dữ liệu của app thành một chuỗi JSON để đưa lên Drive.
  static Future<String> buildEnvelope() async {
    final sp = await SharedPreferences.getInstance();
    return jsonEncode(<String, Object?>{
      'app': 'LifeSync',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'appBackup': await Repo.exportJson(),
      'mindMaps': sp.getString(_mindMapsKey),
      'flashcards': sp.getString(_flashcardsKey),
    });
  }

  /// Đưa bản sao lưu hiện tại lên Drive (tạo mới hoặc ghi đè bản cũ).
  static Future<void> uploadBackup() async {
    final api = await _api();
    if (api == null) {
      throw StateError('Chưa đăng nhập Google');
    }
    final data = utf8.encode(await buildEnvelope());
    final existing = await _findFile(api);
    final media = drive.Media(Stream<List<int>>.value(data), data.length,
        contentType: 'application/json');
    if (existing == null || existing.id == null) {
      await api.files.create(
        drive.File()
          ..name = _fileName
          ..mimeType = 'application/json'
          ..parents = <String>['appDataFolder'],
        uploadMedia: media,
      );
    } else {
      await api.files.update(
        drive.File()
          ..name = _fileName
          ..mimeType = 'application/json',
        existing.id!,
        uploadMedia: media,
      );
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_lastKey, DateTime.now().toIso8601String());
  }

  /// Tải chuỗi sao lưu từ Drive về, hoặc null nếu chưa có bản nào.
  static Future<String?> downloadBackup() async {
    final api = await _api();
    if (api == null) return null;
    final file = await _findFile(api);
    if (file == null || file.id == null) return null;
    final media = await api.files.get(file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  /// Khôi phục dữ liệu từ Drive, thay thế toàn bộ dữ liệu hiện tại.
  /// Trả về số lượng từng loại đã khôi phục (để hiển thị xác nhận).
  static Future<DriveRestoreResult> restoreFromDrive() async {
    final raw = await downloadBackup();
    if (raw == null) {
      throw StateError('Không tìm thấy bản sao lưu trên Drive');
    }
    final decoded = jsonDecode(raw);
    String? exportedAt;
    BackupData data;
    if (decoded is Map && decoded['appBackup'] is String) {
      exportedAt = decoded['exported_at'] as String?;
      data = BackupService.parse(decoded['appBackup'] as String);
      final sp = await SharedPreferences.getInstance();
      final mindMaps = decoded['mindMaps'];
      if (mindMaps is String) {
        await sp.setString(_mindMapsKey, mindMaps);
      }
      final flashcards = decoded['flashcards'];
      if (flashcards is String) {
        await sp.setString(_flashcardsKey, flashcards);
      }
    } else {
      // Tương thích: bản sao lưu JSON cũ (chỉ có dữ liệu SQLite).
      data = BackupService.parse(raw);
    }
    await Repo.restore(data);
    return DriveRestoreResult(
      events: data.events.length,
      txns: data.txns.length,
      budgets: data.budgets.length,
      goals: data.goals.length,
      notes: data.notes.length,
      tasks: data.tasks.length,
      exportedAt: exportedAt,
    );
  }

  // ---------------- tự động sao lưu ----------------

  static Future<bool> autoEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_autoKey) ?? false;
  }

  static Future<void> setAutoEnabled(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_autoKey, value);
  }

  /// Lần sao lưu lên Drive gần nhất (theo giờ máy), hoặc null.
  static Future<String?> lastBackupLabel() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_lastKey);
  }

  /// Sao lưu nền khi mở app (chỉ chạy khi người dùng đã bật tự động sao lưu
  /// và đã đăng nhập). Mọi lỗi đều được bỏ qua để không làm phiền app.
  static Future<void> maybeAutoBackup() async {
    try {
      if (!await autoEnabled()) return;
      if (!await isSignedIn) return;
      await uploadBackup();
    } catch (_) {}
  }
}

class DriveRestoreResult {
  const DriveRestoreResult({
    required this.events,
    required this.txns,
    required this.budgets,
    required this.goals,
    required this.notes,
    required this.tasks,
    this.exportedAt,
  });

  final int events;
  final int txns;
  final int budgets;
  final int goals;
  final int notes;
  final int tasks;
  final String? exportedAt;
}

/// Http client gắn sẵn header xác thực của tài khoản Google.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
