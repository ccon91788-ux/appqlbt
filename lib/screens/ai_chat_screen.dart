import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../services/gemini_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  List<Map<String, dynamic>> _pendingEvents = [];
  bool _sending = false;
  int _keyCount = 0;
  String? _error;

  @override
  void initState() { super.initState(); _refreshKeyCount(); }
  @override
  void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _refreshKeyCount() async {
    final count = (await GeminiService.instance.keys()).length;
    if (mounted) setState(() => _keyCount = count);
  }

  Future<void> _settings() async {
    final choice = await showModalBottomSheet<String>(context: context, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Gemini API settings', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('API key được lưu trong vùng lưu trữ bảo mật của Android.')),
        ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Nhập API key từ tệp TXT'), onTap: () => Navigator.pop(ctx, 'txt')),
        ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Nhập API key từ tệp Excel'), subtitle: const Text('Đọc API key trong các ô của tệp .xlsx'), onTap: () => Navigator.pop(ctx, 'excel')),
        if (_keyCount > 0) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Xóa toàn bộ API key'), onTap: () => Navigator.pop(ctx, 'clear')),
        const SizedBox(height: 8),
      ])));
    if (choice == null || !mounted) return;
    try {
      if (choice == 'clear') {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Xóa API key?'), content: const Text('Bạn sẽ cần nhập lại key để dùng Gemini.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa'))]));
        if (ok == true) await GeminiService.instance.clearKeys();
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom,
          allowedExtensions: choice == 'txt' ? ['txt'] : ['xlsx'], withData: true);
        if (result == null || result.files.isEmpty) return;
        final bytes = result.files.single.bytes;
        if (bytes == null) throw Exception('Không đọc được tệp. Hãy chọn lại tệp.');
        if (choice == 'txt') { await GeminiService.instance.importText(bytes); }
        else { await GeminiService.instance.importExcel(bytes); }
      }
      await _refreshKeyCount();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_keyCount > 0 ? 'Đã lưu $_keyCount API key.' : 'Đã xóa API key.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể nhập key: $e')));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() { _messages.add({'role': 'user', 'text': text}); _sending = true; _error = null; _pendingEvents = []; });
    try {
      final reply = await GeminiService.instance.chat(List<Map<String, String>>.from(_messages));
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply.text});
        _pendingEvents = reply.events;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Future<void> _applyEvents() async {
    final valid = <Event>[];
    for (final data in _pendingEvents) {
      try {
        final start = DateTime.parse((data['start'] ?? '').toString());
        if (!start.isAfter(DateTime.now())) continue;
        final endText = (data['end'] ?? '').toString();
        final end = endText.isEmpty ? null : DateTime.tryParse(endText);
        final reminder = int.tryParse('${data['reminder_min'] ?? 10}') ?? 10;
        final repeat = int.tryParse('${data['repeat'] ?? 0}') ?? 0;
        valid.add(Event(title: (data['title'] ?? 'Sự kiện AI').toString(),
          description: (data['description'] ?? '').toString(), start: start, end: end,
          reminderMin: reminder.clamp(-1, 525600), repeat: repeat.clamp(0, 4)));
      } catch (_) {}
    }
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có lịch hợp lệ trong tương lai để thêm.')));
      return;
    }
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Thêm ${valid.length} lịch vào LifeSync?'),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [
        const Text('Kiểm tra các thời điểm bên dưới trước khi lưu:'),
        const SizedBox(height: 8),
        for (final event in valid) ListTile(contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available), title: Text(event.title),
          subtitle: Text(DateFormat('EEE, dd/MM/yyyy • HH:mm', 'vi').format(event.start) +
            (event.description.isEmpty ? '' : '\n${event.description}'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thêm lịch'))]));
    if (accepted != true) return;
    for (final event in valid) { await Repo.saveEvent(event); }
    if (!mounted) return;
    setState(() => _pendingEvents = []);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${valid.length} sự kiện và thiết lập nhắc nhở.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini AI'), actions: [
        IconButton(tooltip: 'Cài đặt API', onPressed: _settings, icon: const Icon(Icons.settings_outlined)),
      ]),
      body: Column(children: [
        if (_keyCount == 0) MaterialBanner(
          leading: const Icon(Icons.key_outlined), content: const Text('Chưa có Gemini API key. Nhấn bánh răng để nhập tệp TXT hoặc Excel.'),
          actions: [TextButton(onPressed: _settings, child: const Text('CÀI ĐẶT'))]),
        Expanded(child: _messages.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12), const Text('Bạn muốn sắp xếp điều gì hôm nay?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8), const Text('Ví dụ: “Lập lịch calisthenics cho người mới vào 3 buổi mỗi tuần, lúc 18:00 và nhắc trước 10 phút.”', textAlign: TextAlign.center),
            ])))
          : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index]; final mine = m['role'] == 'user';
              return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
                  decoration: BoxDecoration(color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16)),
                  child: SelectableText(m['text'] ?? '')));
            }),),
        if (_pendingEvents.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const Icon(Icons.event_note), const SizedBox(width: 8), Expanded(child: Text('AI đề xuất ${_pendingEvents.length} sự kiện.')), 
          FilledButton(onPressed: _applyEvents, child: const Text('Xem & thêm')),
        ])))),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
        if (_sending) const LinearProgressIndicator(minHeight: 2),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 5, textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Nhắn Gemini...', border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 8), IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}
