import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils.dart';

/// Số build, được GitHub Actions truyền vào lúc build (--dart-define=BUILD_NUMBER=...).
const int kBuild = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

const String kRepo = 'ccon91788-ux/applich';
const String kApkUrl = 'https://github.com/$kRepo/releases/latest/download/LifeSync.apk';

/// Lấy số build từ tên tag dạng "build-12". Trả về null nếu không đọc được.
int? parseBuild(String tag) {
  final m = RegExp(r'(\d+)$').firstMatch(tag.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

class UpdateService {
  static Future<bool> autoEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool('autoupdate') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAutoEnabled(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool('autoupdate', v);
    } catch (_) {}
  }

  /// Số build mới nhất trên GitHub, hoặc null nếu không kiểm tra được.
  /// Chỉ đọc thông tin phiên bản công khai, không gửi dữ liệu của người dùng.
  static Future<int?> latestBuild() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await c.getUrl(
        Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
      );
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body);
      if (j is! Map || j['tag_name'] is! String) return null;
      return parseBuild(j['tag_name'] as String);
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  /// [silent] = true: chỉ báo khi có bản mới (dùng lúc mở app).
  static Future<void> check(BuildContext context, {bool silent = false}) async {
    final latest = await latestBuild();
    if (!context.mounted) return;
    if (latest == null) {
      if (!silent) toast(context, 'Không kiểm tra được bản mới. Hãy kiểm tra kết nối mạng.');
      return;
    }
    if (kBuild == 0 || latest <= kBuild) {
      if (!silent) {
        toast(context, kBuild == 0
            ? 'Đây là bản thử nghiệm, không có số phiên bản để so sánh.'
            : 'Bạn đang dùng bản mới nhất (build $kBuild).');
      }
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Có bản cập nhật mới 🎉'),
        content: Text(
          'Bản mới: build $latest (bạn đang dùng build $kBuild).\n\n'
          'Bấm "Cập nhật", app sẽ tự tải bản mới. Khi tải xong, '
          'bấm "Cập nhật" ở màn hình cài đặt của Android. '
          'Dữ liệu của bạn được giữ nguyên.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Để sau')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cập nhật')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UpdateProgressDialog(),
    );
  }
}

/// Mở trang tải APK bằng trình duyệt (phương án dự phòng nếu tải trong app thất bại).
Future<void> _openInBrowser() async {
  try {
    await launchUrl(Uri.parse(kApkUrl), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog();
  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  StreamSubscription<OtaEvent>? _sub;
  double? _pct;
  String _msg = 'Đang kết nối...';
  bool _done = false; // chống đóng hộp thoại hai lần (sự kiện hệ thống có thể đến muộn)

  @override
  void initState() {
    super.initState();
    try {
      _sub = OtaUpdate()
          .execute(kApkUrl, destinationFilename: 'LifeSync.apk')
          .listen(_onEvent, onError: (_) => _fail());
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fail());
    }
  }

  void _onEvent(OtaEvent e) {
    if (_done || !mounted) return;
    final name = e.status.name;
    if (e.status == OtaStatus.DOWNLOADING) {
      final v = double.tryParse(e.value ?? '');
      setState(() {
        _pct = v == null ? null : (v / 100).clamp(0, 1).toDouble();
        _msg = 'Đang tải... ${v == null ? '' : '${v.round()}%'}';
      });
    } else if (e.status == OtaStatus.INSTALLING) {
      // Trình cài đặt của Android sẽ hiện lên, đóng hộp thoại tiến độ.
      if (_done) return;
      _done = true;
      Navigator.of(context).pop();
    } else if (name.contains('ERROR') || name == 'CANCELED') {
      _fail();
    }
  }

  void _fail() {
    if (_done || !mounted) return;
    _done = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Không cập nhật trực tiếp được. Đang mở trình duyệt để tải.')),
    );
    _openInBrowser();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Đang cập nhật'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _pct, minHeight: 10),
            const SizedBox(height: 12),
            Text(_msg),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_done) return;
              _done = true;
              OtaUpdate().cancel();
              Navigator.of(context).pop();
            },
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }
}
