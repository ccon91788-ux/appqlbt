import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../services/finance_logic.dart';
import '../ui.dart';
import '../utils.dart';

Future<bool> _confirm(BuildContext context, String text) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Xác nhận'),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
      ],
    ),
  );
  return r == true;
}

Widget _progress(BuildContext context, double v, int color) => ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: LinearProgressIndicator(
    value: v,
    minHeight: 12,
    backgroundColor: pastel(context, color).withAlpha(150),
    valueColor: AlwaysStoppedAnimation(pastelStrong(color)),
  ),
);

// ======================= NGÂN SÁCH =======================
class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

  Future<void> _edit(BuildContext context, Budget? cur) async {
    final now = DateTime.now();
    final v = await askAmount(
      context,
      'Ngân sách tháng ${DateFormat('MM/yyyy').format(now)}',
      initial: cur?.limit,
    );
    if (v != null) await Repo.setBudget(now, v);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit),
        label: const Text('Đặt ngân sách'),
        onPressed: () async {
          final st = await Repo.budgetStatus(now);
          if (context.mounted) await _edit(context, st.budget);
        },
      ),
      body: DataBuilder<BudgetStatus>(
        load: () => Repo.budgetStatus(now),
        builder: (context, data) {
            final st = data;
            final b = st?.budget;
            if (st == null || b == null) {
              return ListView(
                children: const [EmptyState('🐷', 'Chưa đặt ngân sách cho tháng này.\nBấm "Đặt ngân sách" để bắt đầu.')],
              );
            }
            final pct = b.limit == 0 ? 0 : st.spent * 100 ~/ b.limit;
            final remaining = b.limit - st.spent;
            final icon = pct >= 100 ? '⛔' : (pct >= 80 ? '⚠️' : '✅');
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                SoftCard(
                  gradient: heroGradient(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngân sách tháng ${DateFormat('MM/yyyy').format(now)}',
                          style: const TextStyle(color: Colors.white70)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(fmtMoney(b.limit),
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0, 1).toDouble(),
                          minHeight: 14,
                          backgroundColor: Colors.white.withAlpha(70),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$icon Đã dùng $pct%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SoftCard(
                        color: pastel(context, 3),
                        margin: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đã chi'),
                            FittedBox(fit: BoxFit.scaleDown, child: Text(fmtMoney(st.spent),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SoftCard(
                        color: pastel(context, 4),
                        margin: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(remaining >= 0 ? 'Còn lại' : 'Vượt ngân sách'),
                            FittedBox(fit: BoxFit.scaleDown, child: Text(fmtMoney(remaining.abs()),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cảnh báo ngân sách', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Báo khi dùng 80%, 90%, 100% (mỗi mức một lần mỗi tháng)'),
                        value: b.enabled,
                        onChanged: (v) => Repo.setBudgetEnabled(now, v),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final e in const {80: 1, 90: 2, 100: 4}.entries)
                            Chip(label: Text('${e.key}%: ${(b.notified & e.value) != 0 ? '✓ đã báo' : 'chưa báo'}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Repo.resetBudgetAlerts(now),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Đặt lại cảnh báo'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
      ),
    );
  }
}

// ======================= MỤC TIÊU TIẾT KIỆM =======================
class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key});

  Widget _card(BuildContext context, Goal g) {
    final p = goalProgress(g.saved, g.target);
    final remain = g.target - g.saved;
    final need = monthlyNeeded(g.target, g.saved, g.deadline, DateTime.now());
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Badge3D('🎯', color: g.id ?? 0),
              const SizedBox(width: 12),
              Expanded(
                child: Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Text('${(p * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _progress(context, p, g.id ?? 0),
          const SizedBox(height: 10),
          Text('Đã có: ${fmtMoney(g.saved)} / ${fmtMoney(g.target)}'),
          Text(remain > 0 ? 'Còn thiếu: ${fmtMoney(remain)}' : '🎉 Đã đạt mục tiêu!'),
          if (g.deadline != null) Text('Hạn: ${DateFormat('dd/MM/yyyy').format(g.deadline!)}'),
          if (need > 0) Text('Cần để dành khoảng ${fmtMoney(need)}/tháng'),
          if (g.note.isNotEmpty) Text(g.note, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: () async {
                  final v = await askAmount(context, 'Thêm tiền vào "${g.name}"');
                  if (v != null) await Repo.adjustGoal(g, v);
                },
                child: const Text('+ Thêm'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final v = await askAmount(context, 'Rút tiền khỏi "${g.name}"');
                  if (v == null) return;
                  if (v > g.saved) {
                    if (context.mounted) toast(context, 'Số tiền rút vượt quá số đã tiết kiệm.');
                    return;
                  }
                  await Repo.adjustGoal(g, -v);
                },
                child: const Text('− Rút'),
              ),
              IconButton(
                tooltip: 'Sửa mục tiêu',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalForm(goal: g))),
              ),
              IconButton(
                tooltip: 'Xóa mục tiêu',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await _confirm(context, 'Xóa mục tiêu "${g.name}"?')) await Repo.deleteGoal(g);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Mục tiêu'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalForm())),
      ),
      body: DataBuilder<List<Goal>>(
        load: () => Repo.goals(),
        builder: (context, data) {
            final gs = data ?? <Goal>[];
            if (gs.isEmpty) {
              return ListView(children: const [EmptyState('🎯', 'Chưa có mục tiêu tiết kiệm.\nVí dụ: mua laptop, du lịch...')]);
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [for (final g in gs) _card(context, g)],
            );
          },
      ),
    );
  }
}

class GoalForm extends StatefulWidget {
  final Goal? goal;
  const GoalForm({super.key, this.goal});
  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  final _note = TextEditingController();
  DateTime? deadline;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _name.text = g.name;
      _target.text = groupDigits('${g.target}');
      _saved.text = groupDigits('${g.saved}');
      _note.text = g.note;
      deadline = g.deadline;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = parseMoney(_target.text);
    final s = _saved.text.trim().isEmpty ? 0 : parseMoney(_saved.text);
    if (_name.text.trim().isEmpty) {
      toast(context, 'Vui lòng nhập tên mục tiêu.');
      return;
    }
    if (t == null || t <= 0) {
      toast(context, 'Số tiền mục tiêu không hợp lệ.');
      return;
    }
    if (s == null || s < 0) {
      toast(context, 'Số tiền đã có không hợp lệ.');
      return;
    }
    final g = widget.goal ?? Goal(name: '', target: t, created: DateTime.now());
    g.name = _name.text.trim();
    g.target = t;
    g.saved = s;
    g.deadline = deadline;
    g.note = _note.text.trim();
    try {
      await Repo.saveGoal(g);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Không thể lưu mục tiêu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.goal == null ? 'Thêm mục tiêu' : 'Sửa mục tiêu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên mục tiêu (vd: Mua laptop)')),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [const ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'Số tiền mục tiêu (₫)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _saved,
            keyboardType: TextInputType.number,
            inputFormatters: [const ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'Số tiền đã có (₫)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú')),
          SoftCard(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: deadline ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => deadline = d);
            },
            child: Row(
              children: [
                const Badge3D('📅', size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deadline == null ? 'Hạn chót (không bắt buộc)' : DateFormat('dd/MM/yyyy').format(deadline!),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (deadline != null)
                  IconButton(tooltip: 'Bỏ hạn chót', icon: const Icon(Icons.close), onPressed: () => setState(() => deadline = null)),
              ],
            ),
          ),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Lưu mục tiêu')),
        ],
      ),
    );
  }
}
