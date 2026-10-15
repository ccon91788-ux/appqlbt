import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../services/quick_input_service.dart';
import '../stickers.dart';
import '../ui.dart';
import '../utils.dart';
import 'category_sheet.dart';
import 'finance_extras.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tài chính'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(140),
                  borderRadius: BorderRadius.circular(22),
                ),
                // 3 ô cùng độ rộng, căn đều hai bên (không cuộn, không lệch trái)
                child: TabBar(
                  isScrollable: false,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  splashBorderRadius: BorderRadius.circular(18),
                  labelPadding: EdgeInsets.zero,
                  labelColor: cs.onPrimaryContainer,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  indicator: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tabs: const [
                    Tab(text: 'Giao dịch'),
                    Tab(text: 'Ngân sách'),
                    Tab(text: 'Tiết kiệm'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [TxnTab(), BudgetTab(), GoalsTab()],
        ),
      ),
    );
  }
}

class TxnTab extends StatefulWidget {
  const TxnTab({super.key});
  @override
  State<TxnTab> createState() => _TxnTabState();
}

class _TxnTabState extends State<TxnTab> {
  String q = '';

  Future<void> _quick() async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nhập nhanh'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ví dụ: Chi 50k ăn sáng'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Phân tích')),
        ],
      ),
    );
    ctl.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    final r = parseQuick(text);
    // Luôn hiển thị màn hình xác nhận, không tự lưu.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TxnForm(
          initial: Txn(
            isIncome: r.isIncome ?? false,
            amount: r.amount ?? 0,
            category: r.category,
            note: r.note,
            date: DateTime.now(),
          ),
          fromQuick: true,
          uncertain: !r.certain,
        ),
      ),
    );
  }

  Widget _pill(String label, int v) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(50),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            fmtMoney(v),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _hero(int inc, int exp) => SoftCard(
    gradient: heroGradient(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Số dư', style: TextStyle(color: Colors.white70)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            fmtMoney(inc - exp),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _pill('⬇️ Thu', inc)),
            const SizedBox(width: 10),
            Expanded(child: _pill('⬆️ Chi', exp)),
          ],
        ),
      ],
    ),
  );

  Widget _tile(Txn t) => SoftCard(
    padding: const EdgeInsets.all(12),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TxnForm(initial: t)),
    ),
    child: Row(
      children: [
        CatBadge(t.category, color: t.category.length),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.category, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                '${DateFormat('dd/MM/yyyy').format(t.date)}${t.note.isEmpty ? '' : ' • ${t.note}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${t.isIncome ? '+' : '-'}${fmtMoney(t.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: t.isIncome ? const Color(0xFF2E9E6B) : const Color(0xFFE0556F),
              ),
            ),
            InkWell(
              onTap: () => Repo.deleteTxn(t),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 20, semanticLabel: 'Xóa giao dịch'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxnForm())),
        icon: const Icon(Icons.add),
        label: const Text('Giao dịch'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => q = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm giao dịch...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Nhập nhanh',
                  icon: const Icon(Icons.bolt),
                  onPressed: _quick,
                ),
              ],
            ),
          ),
          Expanded(
            child: DataBuilder<List<Txn>>(
              load: Repo.txns,
              builder: (context, data) {
                final all = data ?? <Txn>[];
                var inc = 0;
                var exp = 0;
                for (final t in all) {
                  if (t.isIncome) {
                    inc += t.amount;
                  } else {
                    exp += t.amount;
                  }
                }
                final ql = q.trim().toLowerCase();
                final list = ql.isEmpty
                    ? all
                    : all
                          .where((t) =>
                              t.category.toLowerCase().contains(ql) ||
                              t.note.toLowerCase().contains(ql))
                          .toList();
                // ListView.builder chỉ dựng các dòng đang hiển thị -> mượt với hàng nghìn giao dịch.
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.isEmpty ? 2 : list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return _hero(inc, exp);
                    if (list.isEmpty) {
                      return EmptyState('🐷', all.isEmpty ? 'Chưa có giao dịch nào' : 'Không tìm thấy giao dịch');
                    }
                    return _tile(list[i - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TxnForm extends StatefulWidget {
  final Txn? initial;
  final bool fromQuick;
  final bool uncertain;
  const TxnForm({super.key, this.initial, this.fromQuick = false, this.uncertain = false});
  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  late bool income;
  late DateTime date;
  final _amount = TextEditingController();
  final _cat = TextEditingController();
  final _note = TextEditingController();
  List<CatStyle> custom = [];

  Future<void> _loadCats() async {
    final l = await Repo.categories();
    if (mounted) setState(() => custom = l.where((c) => c.custom).toList());
  }

  /// Mở bảng sửa danh mục. Danh mục mặc định chỉ đổi được sticker/màu viền.
  Future<void> _editCat(String name, {required bool isIncome}) async {
    final e = catStyles[name] ?? CatStyle(name: name, isIncome: isIncome);
    await openCategorySheet(context, existing: e, income: isIncome);
    await _loadCats();
  }

  @override
  void initState() {
    super.initState();
    _loadCats();
    final t = widget.initial;
    income = t?.isIncome ?? false;
    date = t?.date ?? DateTime.now();
    if (t != null) {
      if (t.amount > 0) _amount.text = groupDigits('${t.amount}');
      _cat.text = t.category;
      _note.text = t.note;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _cat.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = parseMoney(_amount.text);
    if (a == null || a <= 0) {
      toast(context, 'Số tiền không hợp lệ.');
      return;
    }
    final cat = _cat.text.trim().isEmpty ? (income ? 'Thu nhập khác' : 'Chi tiêu khác') : _cat.text.trim();
    final t = widget.initial ?? Txn(isIncome: income, amount: a, category: cat, date: date);
    t.isIncome = income;
    t.amount = a;
    t.category = cat;
    t.note = _note.text.trim();
    t.date = date;
    try {
      await Repo.saveTxn(t);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Không thể lưu giao dịch.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = [
      ...(income ? incomeCats : expenseCats),
      ...custom.where((c) => c.isIncome == income).map((c) => c.name),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.fromQuick ? 'Xác nhận giao dịch' : 'Giao dịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.uncertain)
            const SoftCard(
              margin: EdgeInsets.only(bottom: 12),
              child: Text('⚠️ Chưa chắc chắn về kết quả phân tích. Vui lòng kiểm tra lại trước khi lưu.'),
            ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Chi'), icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: true, label: Text('Thu'), icon: Icon(Icons.arrow_downward)),
            ],
            selected: {income},
            onSelectionChanged: (s) => setState(() => income = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [const ThousandsFormatter()],
            decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cat,
            decoration: const InputDecoration(labelText: 'Danh mục (có thể tự nhập)'),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in cats)
                GestureDetector(
                  onLongPress: () => _editCat(c, isIncome: income),
                  child: ActionChip(
                    avatar: catAvatar(c),
                    label: Text(c),
                    onPressed: () => setState(() => _cat.text = c),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Mới'),
                onPressed: () async {
                  await openCategorySheet(context, income: income);
                  await _loadCats();
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Nhấn giữ một danh mục để đổi sticker và màu viền.', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú')),
          SoftCard(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => date = d);
            },
            child: Row(
              children: [
                const Badge3D('📅', size: 38),
                const SizedBox(width: 12),
                Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Lưu giao dịch')),
        ],
      ),
    );
  }
}
