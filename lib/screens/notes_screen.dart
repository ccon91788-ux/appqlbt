import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../sticker_picker.dart';
import '../stickers.dart';
import '../ui.dart';
import '../utils.dart';

/// Màn hình "Ghi chú" gồm 2 tab: [Ghi chú] và [Nhiệm vụ].
/// Tab Nhiệm vụ lưu riêng trong bảng `tasks` (SQLite), không trộn với ghi chú,
/// và có nhắc nhở 1 lần qua thông báo — giống ảnh mẫu: checkbox, "Đặt nhắc nhở",
/// "Hoàn tất", nhóm "Hoàn tất N" thu gọn được.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesState();
}

class _NotesState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) {
        setState(() => _tabIndex = _tabs.index);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi chú'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.note_outlined), text: 'Ghi chú'),
            Tab(icon: Icon(Icons.checklist_outlined), text: 'Nhiệm vụ'),
          ],
        ),
      ),
      // Tab Nhiệm vụ tự có nút "Thêm nhiệm vụ" + ô soạn thảo ở dưới,
      // nên chỉ hiện FAB ở tab Ghi chú.
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteForm()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ghi chú'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [_NotesList(), _TasksTab()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Ghi chú (giữ nguyên hành vi cũ)
// ---------------------------------------------------------------------------

class _NotesList extends StatefulWidget {
  const _NotesList();
  @override
  State<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<_NotesList> {
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
              if (n.sticker.isNotEmpty) ...[
                StickerBadge(n.sticker, border: n.border, size: 40),
                const SizedBox(width: 8),
              ],
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
    return Column(
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
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Nhiệm vụ
// ---------------------------------------------------------------------------

class _TasksTab extends StatefulWidget {
  const _TasksTab();
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String q = '';
  bool _showCompleted = true;

  // Trạng thái ô soạn thảo (như ảnh mẫu: checkbox + ô nhập + Đặt nhắc nhở + Hoàn tất).
  bool _editing = false;
  TaskItem? _editingTask; // null = tạo mới, khác null = đang sửa nhiệm vụ đó
  final _draftTitle = TextEditingController();
  DateTime? _draftReminder;

  @override
  void dispose() {
    _draftTitle.dispose();
    super.dispose();
  }

  void _startNew() {
    setState(() {
      _editing = true;
      _editingTask = null;
      _draftTitle.clear();
      _draftReminder = null;
    });
  }

  void _startEdit(TaskItem t) {
    setState(() {
      _editing = true;
      _editingTask = t;
      _draftTitle.text = t.title;
      _draftReminder = t.reminderAt;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _editingTask = null;
      _draftTitle.clear();
      _draftReminder = null;
    });
  }

  Future<void> _saveDraft() async {
    final title = _draftTitle.text.trim();
    if (title.isEmpty) {
      toast(context, 'Nhập tên nhiệm vụ trước đã.');
      return;
    }
    try {
      final editing = _editingTask;
      if (editing != null) {
        editing.title = title;
        editing.reminderAt = _draftReminder;
        await Repo.saveTask(editing);
      } else {
        await Repo.saveTask(
          TaskItem(title: title, created: DateTime.now(), reminderAt: _draftReminder),
        );
      }
      _cancelEdit();
    } catch (_) {
      if (mounted) toast(context, 'Không thể lưu nhiệm vụ.');
    }
  }

  Future<void> _toggle(TaskItem t, bool? value) async {
    await Repo.saveTask(t.toggled(value ?? !t.done));
  }

  Future<void> _delete(TaskItem t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa nhiệm vụ "${t.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await Repo.deleteTask(t);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initial = _draftReminder ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _draftReminder = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// "Hôm nay 20:18" / "Ngày mai 09:00" / "15/10/2026 • 20:18" — giống ảnh mẫu.
  String _reminderLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final hm = DateFormat('HH:mm').format(at);
    if (day == today) return 'Hôm nay $hm';
    if (day == today.add(const Duration(days: 1))) return 'Ngày mai $hm';
    return '${DateFormat('dd/MM/yyyy').format(at)} • $hm';
  }

  Widget _taskCard(TaskItem t) {
    final theme = Theme.of(context);
    final done = t.done;
    final overdue =
        !done && t.reminderAt != null && t.reminderAt!.isBefore(DateTime.now());
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      onTap: () => _startEdit(t),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: done,
            onChanged: (v) => _toggle(t, v),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? theme.colorScheme.onSurface.withAlpha(120)
                          : null,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (t.reminderAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 14,
                          color: overdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface.withAlpha(150),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _reminderLabel(t.reminderAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: overdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface.withAlpha(160),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sửa nhiệm vụ',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _startEdit(t),
          ),
          IconButton(
            tooltip: 'Xóa nhiệm vụ',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(t),
          ),
        ],
      ),
    );
  }

  Widget _editorCard() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Checkbox(value: false, onChanged: null),
                  Expanded(
                    child: TextField(
                      controller: _draftTitle,
                      autofocus: true,
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveDraft(),
                      decoration: const InputDecoration(
                        hintText: 'Nhiệm vụ mới...',
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ],
              ),
              if (_draftReminder != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 4),
                    child: Chip(
                      avatar: const Icon(Icons.alarm, size: 16),
                      label: Text(_reminderLabel(_draftReminder!)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _draftReminder = null),
                    ),
                  ),
                ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickReminder,
                    icon: const Icon(Icons.alarm, size: 18),
                    label: const Text('Đặt nhắc nhở'),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _cancelEdit, child: const Text('Hủy')),
                  FilledButton(
                    onPressed: _saveDraft,
                    child: Text(_editingTask == null ? 'Hoàn tất' : 'Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              hintText: 'Tìm nhiệm vụ...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: DataBuilder<List<TaskItem>>(
            load: Repo.tasks,
            builder: (context, data) {
              final all = data ?? <TaskItem>[];
              final ql = q.trim().toLowerCase();
              final filtered = ql.isEmpty
                  ? all
                  : all.where((t) => t.title.toLowerCase().contains(ql)).toList();
              final active = filtered.where((t) => !t.done).toList();
              final completed = filtered.where((t) => t.done).toList();

              if (filtered.isEmpty) {
                return ListView(
                  children: [
                    EmptyState(
                      '✅',
                      all.isEmpty
                          ? 'Chưa có nhiệm vụ nào.\nBấm "Thêm nhiệm vụ" để tạo.'
                          : 'Không tìm thấy nhiệm vụ',
                    ),
                  ],
                );
              }

              final children = <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nhiệm vụ',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                for (final t in active) _taskCard(t),
              ];

              if (completed.isNotEmpty) {
                children.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _showCompleted = !_showCompleted),
                      child: Row(
                        children: [
                          Icon(
                            _showCompleted
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hoàn tất ${completed.length}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (_showCompleted) {
                  for (final t in completed) {
                    children.add(_taskCard(t));
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: children,
              );
            },
          ),
        ),
        if (_editing)
          _editorCard()
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startNew,
                icon: const Icon(Icons.add),
                label: const Text('Thêm nhiệm vụ'),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Form ghi chú (giữ nguyên)
// ---------------------------------------------------------------------------

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
  String sticker = '';
  int border = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    if (n != null) {
      _title.text = n.title;
      _content.text = n.content;
      color = n.color;
      pinned = n.pinned;
      sticker = n.sticker;
      border = n.border;
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
    n.sticker = sticker;
    n.border = sticker.isEmpty ? 0 : border;
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
          const SizedBox(height: 16),
          const Text('Sticker', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StickerGrid(
            value: sticker,
            border: border,
            onChanged: (v) => setState(() => sticker = v),
            defaultChild: const Icon(Icons.block),
          ),
          if (sticker.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Màu viền sticker', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            BorderPalette(value: border, onChanged: (v) => setState(() => border = v)),
          ],
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
