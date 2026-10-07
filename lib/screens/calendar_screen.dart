import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../main.dart' show showLunar;
import '../services/finance_logic.dart';
import '../services/lunar_service.dart';
import '../ui.dart';
import '../utils.dart';

const reminderLabels = {
  -1: 'Không nhắc',
  0: 'Đúng giờ',
  5: 'Trước 5 phút',
  10: 'Trước 10 phút',
  15: 'Trước 15 phút',
  30: 'Trước 30 phút',
  60: 'Trước 1 giờ',
  1440: 'Trước 1 ngày',
};
const repeatLabels = {
  0: 'Không lặp',
  1: 'Mỗi ngày',
  2: 'Mỗi tuần',
  3: 'Mỗi tháng',
  4: 'Mỗi năm',
};

bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarState();
}

class _CalendarState extends State<CalendarScreen> {
  int mode = 0; // 0 tháng, 1 tuần, 2 ngày
  late DateTime sel;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    sel = DateTime(n.year, n.month, n.day);
  }

  void _shift(int dir) {
    setState(() {
      if (mode == 0) {
        final last = DateTime(sel.year, sel.month + dir + 1, 0).day;
        sel = DateTime(sel.year, sel.month + dir, sel.day > last ? last : sel.day);
      } else if (mode == 1) {
        sel = DateTime(sel.year, sel.month, sel.day + 7 * dir);
      } else {
        sel = DateTime(sel.year, sel.month, sel.day + dir);
      }
    });
  }

  String _title() {
    if (mode == 0) return DateFormat('MMMM yyyy', 'vi').format(sel);
    if (mode == 2) return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(sel);
    final s = DateTime(sel.year, sel.month, sel.day - (sel.weekday - 1));
    final e = DateTime(s.year, s.month, s.day + 6);
    return '${DateFormat('dd/MM').format(s)} – ${DateFormat('dd/MM/yyyy').format(e)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            tooltip: 'Hôm nay',
            icon: const Icon(Icons.today),
            onPressed: () {
              final n = DateTime.now();
              setState(() => sel = DateTime(n.year, n.month, n.day));
            },
          ),
          IconButton(
            tooltip: 'Chọn ngày',
            icon: const Icon(Icons.event),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: sel,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => sel = DateTime(d.year, d.month, d.day));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventForm(day: sel)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Sự kiện'),
      ),
      body: DataBuilder<List<Event>>(
        load: () => Repo.events(),
        builder: (context, data) {
            final events = data ?? <Event>[];
            return ValueListenableBuilder<bool>(
              valueListenable: showLunar,
              builder: (context, lunar, _) => ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  _hero(lunar),
                  if (mode == 0) _monthGrid(events, lunar),
                  ..._body(events, lunar),
                ],
              ),
            );
          },
      ),
    );
  }

  Widget _hero(bool lunar) {
    const w = Colors.white;
    return SoftCard(
      gradient: heroGradient(context),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Trước',
                color: w,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _title(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: w, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    if (lunar)
                      Text(
                        LunarService.toLunar(sel).label,
                        style: TextStyle(color: w.withAlpha(225), fontSize: 13),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sau',
                color: w,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Tháng')),
              ButtonSegment(value: 1, label: Text('Tuần')),
              ButtonSegment(value: 2, label: Text('Ngày')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Icon(Icons.circle, size: 6, color: c),
  );

  Widget _monthGrid(List<Event> evs, bool lunar) {
    final offset = DateTime(sel.year, sel.month, 1).weekday - 1;
    final days = DateTime(sel.year, sel.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        _cell(DateTime(sel.year, sel.month, d), evs, lunar),
    ];
    return SoftCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: lunar ? 0.74 : 1.0,
            children: cells,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 12,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _dot(pastelStrong(0)),
                  const Text(' Sự kiện', style: TextStyle(fontSize: 12)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, List<Event> evs, bool lunar) {
    final cs = Theme.of(context).colorScheme;
    final isSel = _same(date, sel);
    final isToday = _same(date, DateTime.now());
    final hasEv = evs.any((e) => e.occursOn(date));
    final fg = isSel ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      label: 'Ngày ${date.day} tháng ${date.month}',
      child: GestureDetector(
        onTap: () => setState(() => sel = date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSel
                ? cs.primary
                : (isToday ? cs.primaryContainer : cs.surfaceContainerHighest.withAlpha(70)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: (isToday || isSel) ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (lunar)
                    Text(
                      LunarService.toLunar(date).short,
                      style: TextStyle(fontSize: 10, color: fg.withAlpha(190)),
                    ),
                  SizedBox(
                    height: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasEv) _dot(isSel ? Colors.white : pastelStrong(0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(List<Event> evs, bool lunar) {
    if (mode != 1) {
      return [
        if (mode == 0)
          SectionTitle(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(sel)),
        ..._dayWidgets(sel, evs),
      ];
    }
    final start = DateTime(sel.year, sel.month, sel.day - (sel.weekday - 1));
    final out = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final isToday = _same(d, DateTime.now());
      var label = DateFormat('EEEE dd/MM', 'vi').format(d);
      if (lunar) label += '  ·  ${LunarService.toLunar(d).label}';
      out.add(
        InkWell(
          onTap: () => setState(() {
            sel = d;
            mode = 2;
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isToday ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
        ),
      );
      final items = _dayWidgets(d, evs, showEmpty: false);
      out.addAll(
        items.isEmpty
            ? [const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Trống'))]
            : items,
      );
    }
    return out;
  }

  List<Widget> _dayWidgets(DateTime d, List<Event> evs, {bool showEmpty = true}) {
    final list = evs.where((e) => e.occursOn(d)).toList()
      ..sort((a, b) => (a.start.hour * 60 + a.start.minute)
          .compareTo(b.start.hour * 60 + b.start.minute));
    if (list.isEmpty) {
      return showEmpty ? [const EmptyState('🌤️', 'Không có sự kiện trong ngày này')] : [];
    }
    return [for (final e in list) _eventTile(e)];
  }

  Widget _eventTile(Event e) {
    final t = DateFormat('HH:mm');
    final range = e.end == null ? t.format(e.start) : '${t.format(e.start)} – ${t.format(e.end!)}';
    return SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventForm(ev: e))),
      child: Row(
        children: [
          Badge3D('🗓️', color: e.id ?? 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('$range • ${repeatLabels[e.repeat] ?? ''}', style: const TextStyle(fontSize: 12)),
                if (e.description.isNotEmpty)
                  Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xóa sự kiện',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Repo.deleteEvent(e),
          ),
        ],
      ),
    );
  }
}

class EventForm extends StatefulWidget {
  final Event? ev;
  final DateTime? day;
  const EventForm({super.key, this.ev, this.day});
  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late DateTime date;
  late TimeOfDay time;
  TimeOfDay? endTime;
  int rem = 10;
  int rep = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.ev;
    if (e != null) {
      _title.text = e.title;
      _desc.text = e.description;
      date = DateTime(e.start.year, e.start.month, e.start.day);
      time = TimeOfDay(hour: e.start.hour, minute: e.start.minute);
      if (e.end != null) endTime = TimeOfDay(hour: e.end!.hour, minute: e.end!.minute);
      rem = e.reminderMin;
      rep = e.repeat;
    } else {
      final d = widget.day ?? DateTime.now();
      date = DateTime(d.year, d.month, d.day);
      time = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Vui lòng nhập tiêu đề.');
      return;
    }
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DateTime? end;
    if (endTime != null) {
      end = DateTime(date.year, date.month, date.day, endTime!.hour, endTime!.minute);
      if (!end.isAfter(start)) {
        toast(context, 'Giờ kết thúc phải sau giờ bắt đầu.');
        return;
      }
    }
    final e = widget.ev ?? Event(title: '', start: start);
    e.title = _title.text.trim();
    e.description = _desc.text.trim();
    e.start = start;
    e.end = end;
    e.reminderMin = rem;
    e.repeat = rep;
    try {
      await Repo.saveEvent(e);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Không thể lưu sự kiện.');
    }
  }

  Widget _pick(String emoji, String text, VoidCallback onTap, {VoidCallback? onClear}) => SoftCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    margin: const EdgeInsets.symmetric(vertical: 5),
    onTap: onTap,
    child: Row(
      children: [
        Badge3D(emoji, size: 38),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (onClear != null)
          IconButton(tooltip: 'Bỏ', icon: const Icon(Icons.close), onPressed: onClear),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ev == null ? 'Thêm sự kiện' : 'Sửa sự kiện')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tiêu đề')),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Chi tiết')),
          const SizedBox(height: 8),
          _pick('📅', DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date), () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => date = d);
          }),
          _pick('⏰', 'Bắt đầu: ${time.format(context)}', () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) setState(() => time = t);
          }),
          _pick(
            '🏁',
            endTime == null ? 'Giờ kết thúc (không bắt buộc)' : 'Kết thúc: ${endTime!.format(context)}',
            () async {
              final t = await showTimePicker(context: context, initialTime: endTime ?? time);
              if (t != null) setState(() => endTime = t);
            },
            onClear: endTime == null ? null : () => setState(() => endTime = null),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: rem,
            decoration: const InputDecoration(labelText: 'Nhắc nhở'),
            items: [for (final e in reminderLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => rem = v ?? rem),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: rep,
            decoration: const InputDecoration(labelText: 'Lặp lại'),
            items: [for (final e in repeatLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => rep = v ?? rep),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Lưu sự kiện')),
        ],
      ),
    );
  }
}
