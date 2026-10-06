import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../ui.dart';
import '../utils.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesState();
}

class _NotesState extends State<NotesScreen> {
  String q = '';

  Future<void> _delete(Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa ghi chú "${n.title.isEmpty ? 'không tiêu đề' : n.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await Repo.deleteNote(n);
  }

  Widget _card(Note n) {
    return SoftCard(
      color: pastel(context, n.color),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteForm(note: n))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (n.pinned) const Text('📌 '),
              Expanded(
                child: Text(
                  n.title.isEmpty ? '(Không tiêu đề)' : n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: n.pinned ? 'Bỏ ghim' : 'Ghim ghi chú',
                icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () {
                  n.pinned = !n.pinned;
                  Repo.saveNote(n);
                },
              ),
              IconButton(
                tooltip: 'Xóa ghi chú',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(n),
              ),
            ],
          ),
          if (n.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: Text(n.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          Text(DateFormat('dd/MM/yyyy HH:mm').format(n.updated), style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi chú')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteForm())),
        icon: const Icon(Icons.add),
        label: const Text('Ghi chú'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                hintText: 'Tìm ghi chú...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: DataBuilder<List<Note>>(
              load: Repo.notes,
              builder: (context, data) {
                final all = data ?? <Note>[];
                final ql = q.trim().toLowerCase();
                final list = ql.isEmpty
                    ? all
                    : all
                          .where((n) =>
                              n.title.toLowerCase().contains(ql) ||
                              n.content.toLowerCase().contains(ql))
                          .toList();
                if (list.isEmpty) {
                  return ListView(
                    children: [
                      EmptyState('📝', all.isEmpty ? 'Chưa có ghi chú nào.\nBấm "Ghi chú" để thêm.' : 'Không tìm thấy ghi chú'),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _card(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NoteForm extends StatefulWidget {
  final Note? note;
  const NoteForm({super.key, this.note});
  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  int color = 0;
  bool pinned = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    if (n != null) {
      _title.text = n.title;
      _content.text = n.content;
      color = n.color;
      pinned = n.pinned;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
      toast(context, 'Ghi chú đang trống.');
      return;
    }
    final n = widget.note ?? Note(updated: DateTime.now());
    n.title = _title.text.trim();
    n.content = _content.text.trim();
    n.color = color;
    n.pinned = pinned;
    try {
      await Repo.saveNote(n);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Không thể lưu ghi chú.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.note == null ? 'Thêm ghi chú' : 'Sửa ghi chú')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tiêu đề')),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(labelText: 'Nội dung', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          const Text('Màu ghi chú', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < 6; i++)
                Semantics(
                  button: true,
                  selected: color == i,
                  label: 'Màu ${i + 1}',
                  child: GestureDetector(
                    onTap: () => setState(() => color = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pastel(context, i),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == i ? pastelStrong(i) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: color == i ? const Icon(Icons.check, size: 20) : null,
                    ),
                  ),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ghim lên đầu'),
            value: pinned,
            onChanged: (v) => setState(() => pinned = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Lưu ghi chú')),
        ],
      ),
    );
  }
}
