import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repo.dart';
import '../main.dart' show themeMode, showLunar;
import '../services/backup_service.dart';
import '../services/csv_service.dart';
import '../services/drive_service.dart';
import '../services/update_service.dart';
import '../ui.dart';
import '../utils.dart';

/// Màn hình Cài đặt — trước đây nằm ở cuối tab Thống kê,
/// nay tách riêng và mở bằng biểu tượng bánh răng (Icons.settings).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool autoUpd = true;

  @override
  void initState() {
    super.initState();
    UpdateService.autoEnabled().then((v) {
      if (mounted) setState(() => autoUpd = v);
    });
  }

  Future<File> _tmp(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    return f.writeAsString(content, encoding: utf8);
  }

  Future<void> _export() async {
    try {
      final f = await _tmp(
        'LifeSync_Backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
        await Repo.exportJson(),
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    } catch (_) {
      if (mounted) toast(context, 'Không thể xuất sao lưu.');
    }
  }

  Future<void> _csv() async {
    try {
      final f = await _tmp(
        'LifeSync_Transactions_${DateFormat('yyyy-MM').format(DateTime.now())}.csv',
        CsvService.build(await Repo.txns()),
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    } catch (_) {
      if (mounted) toast(context, 'Không thể xuất CSV.');
    }
  }

  Future<void> _import() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.first.bytes;
      if (bytes == null) throw const FormatException('empty');
      final data = BackupService.parse(utf8.decode(bytes));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Khôi phục dữ liệu?'),
          content: Text(
            'Toàn bộ dữ liệu hiện tại sẽ bị thay thế bằng: ${data.events.length} sự kiện, '
            '${data.txns.length} giao dịch, ${data.budgets.length} ngân sách, '
            '${data.goals.length} mục tiêu, ${data.notes.length} ghi chú.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Khôi phục')),
          ],
        ),
      );
      if (ok != true) return;
      await Repo.restore(data);
      if (mounted) toast(context, 'Đã khôi phục dữ liệu.');
    } catch (_) {
      if (mounted) toast(context, 'Không thể nhập dữ liệu. Tệp sao lưu không hợp lệ.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Giao diện', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeMode,
                builder: (context, m, _) => SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Hệ thống')),
                    ButtonSegment(value: 1, label: Text('Sáng')),
                    ButtonSegment(value: 2, label: Text('Tối')),
                  ],
                  selected: {m.index},
                  onSelectionChanged: (s) async {
                    themeMode.value = ThemeMode.values[s.first];
                    try {
                      final sp = await SharedPreferences.getInstance();
                      await sp.setInt('theme', s.first);
                    } catch (_) {}
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: showLunar,
                builder: (context, on, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị lịch âm'),
                  value: on,
                  onChanged: (v) async {
                    showLunar.value = v;
                    try {
                      final sp = await SharedPreferences.getInstance();
                      await sp.setBool('lunar', v);
                    } catch (_) {}
                  },
                ),
              ),
            ],
          ),
        ),
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Badge3D('🔄', size: 40, color: 2),
                title: const Text('Tự kiểm tra cập nhật khi mở app'),
                subtitle: Text(kBuild == 0 ? 'Bản thử nghiệm' : 'Phiên bản hiện tại: build $kBuild'),
                value: autoUpd,
                onChanged: (v) async {
                  setState(() => autoUpd = v);
                  await UpdateService.setAutoEnabled(v);
                },
              ),
              ListTile(
                leading: const Badge3D('⬆️', size: 40, color: 2),
                title: const Text('Kiểm tra cập nhật ngay'),
                onTap: () => UpdateService.check(context),
              ),
              ListTile(
                leading: const Badge3D('📤', size: 40),
                title: const Text('Xuất sao lưu (JSON)'),
                onTap: _export,
              ),
              ListTile(
                leading: const Badge3D('📥', size: 40, color: 1),
                title: const Text('Nhập / khôi phục sao lưu'),
                onTap: _import,
              ),
              ListTile(
                leading: const Badge3D('📑', size: 40, color: 4),
                title: const Text('Xuất giao dịch (CSV)'),
                onTap: _csv,
              ),
            ],
          ),
        ),
        const SectionTitle('Google Drive'),
        const _DriveSection(),
        ],
      ),
    );
  }
}

class _DriveSection extends StatefulWidget {
  const _DriveSection();

  @override
  State<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<_DriveSection> {
  String? _email;
  DateTime? _driveTime;
  String? _lastLocal;
  bool _auto = false;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    String? email;
    DateTime? driveTime;
    try {
      email = await DriveService.email;
      if (email != null) driveTime = await DriveService.backupTime();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _email = email;
      _driveTime = driveTime;
      _loading = false;
    });
    final auto = await DriveService.autoEnabled();
    final last = await DriveService.lastBackupLabel();
    if (!mounted) return;
    setState(() {
      _auto = auto;
      _lastLocal = last;
    });
  }

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  String _fmtLast(String raw) {
    try {
      return _fmt(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final email = await DriveService.signIn();
      if (email == null) return; // Người dùng hủy chọn tài khoản.
      DateTime? driveTime;
      try {
        driveTime = await DriveService.backupTime();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _email = email;
        _driveTime = driveTime;
      });
      if (driveTime != null) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Tìm thấy bản sao lưu trên Drive'),
            content: Text(
              'Tài khoản $email đã có bản sao lưu ngày ${_fmt(driveTime!)}. '
              'Khôi phục ngay để lấy lại dữ liệu?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Khôi phục'),
              ),
            ],
          ),
        );
        if (restore == true) await _restore();
      } else if (mounted) {
        toast(context,
            'Đã kết nối Google Drive. Bấm "Sao lưu ngay" để đưa dữ liệu lên Drive.');
      }
    } catch (_) {
      if (mounted) {
        toast(context,
            'Không thể kết nối Google Drive. Kiểm tra mạng rồi thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DriveService.uploadBackup();
      if (mounted) toast(context, 'Đã sao lưu lên Google Drive.');
    } catch (_) {
      if (mounted) toast(context, 'Không thể sao lưu lên Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Khôi phục từ Drive?'),
        content: const Text(
          'Toàn bộ dữ liệu hiện tại sẽ bị thay thế bằng bản sao lưu trên Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await DriveService.restoreFromDrive();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Đã khôi phục'),
          content: Text(
            'Đã khôi phục: ${r.events} sự kiện, ${r.txns} giao dịch, '
            '${r.budgets} ngân sách, ${r.goals} mục tiêu, '
            '${r.notes} ghi chú, ${r.tasks} nhiệm vụ, '
            'kèm sơ đồ tư duy và flashcards (nếu có).\n\n'
            'Khởi động lại app để cập nhật nhắc nhở.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Xong'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) toast(context, 'Không thể khôi phục từ Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Badge3D('☁️', size: 40, color: 2),
            title: Text(
              _loading ? 'Đang kiểm tra…' : (_email ?? 'Chưa kết nối Google Drive'),
            ),
            subtitle: Text(
              _email == null
                  ? 'Sao lưu lên Drive để không mất dữ liệu khi xóa app và cài lại'
                  : (_driveTime == null
                      ? 'Đã kết nối — chưa có bản sao lưu trên Drive'
                      : 'Bản sao lưu trên Drive: ${_fmt(_driveTime!)}'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _email == null
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _connect,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Kết nối Google Drive'),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Sao lưu ngay'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Khôi phục từ Drive'),
                      ),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await DriveService.signOut();
                                await _refresh();
                              },
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
          ),
          SwitchListTile(
            secondary: const Badge3D('🔄', size: 40, color: 2),
            title: const Text('Tự động sao lưu khi mở app'),
            subtitle: Text(_lastLocal == null
                ? 'Chỉ sao lưu khi đã kết nối'
                : 'Lần sao lưu gần nhất: ${_fmtLast(_lastLocal!)}'),
            value: _auto,
            onChanged: _busy
                ? null
                : (v) async {
                    setState(() => _auto = v);
                    await DriveService.setAutoEnabled(v);
                  },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Bản sao lưu trên Drive gồm lịch, tài chính, ghi chú, nhiệm vụ, '
              'sơ đồ tư duy và flashcards. Sau khi cài lại app, chỉ cần kết nối '
              'lại Drive và bấm "Khôi phục từ Drive".',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
