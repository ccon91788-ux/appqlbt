import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../main.dart' show themeMode, showLunar;
import '../services/backup_service.dart';
import '../services/csv_service.dart';
import '../services/update_service.dart';
import '../ui.dart';
import '../utils.dart';

const _palette = [
  Color(0xFFFF9B71), Color(0xFF5BB5E0), Color(0xFFF5C542), Color(0xFFF07BA5),
  Color(0xFF5CC38B), Color(0xFF8E7CF0), Color(0xFF9C7B5B), Color(0xFF45C4C4),
  Color(0xFFE0556F), Color(0xFF7A8CA3),
];

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<AnalyticsScreen> {
  int r = 0;
  DateTimeRange? custom;
  bool autoUpd = true;

  @override
  void initState() {
    super.initState();
    UpdateService.autoEnabled().then((v) {
      if (mounted) setState(() => autoUpd = v);
    });
  }
  static const _rl = ['Tháng này', 'Tháng trước', '3 tháng', '6 tháng', 'Năm nay', 'Tùy chọn'];

  (DateTime, DateTime) _range() {
    final n = DateTime.now();
    switch (r) {
      case 0:
        return (DateTime(n.year, n.month), DateTime(n.year, n.month + 1));
      case 1:
        return (DateTime(n.year, n.month - 1), DateTime(n.year, n.month));
      case 2:
        return (DateTime(n.year, n.month - 2), DateTime(n.year, n.month + 1));
      case 3:
        return (DateTime(n.year, n.month - 5), DateTime(n.year, n.month + 1));
      case 4:
        return (DateTime(n.year), DateTime(n.year + 1));
      default:
        final c = custom;
        if (c == null) return (DateTime(n.year, n.month), DateTime(n.year, n.month + 1));
        return (
          DateTime(c.start.year, c.start.month, c.start.day),
          DateTime(c.end.year, c.end.month, c.end.day + 1),
        );
    }
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

  Widget _stat(String label, int v, int color) => Expanded(
    child: SoftCard(
      color: pastel(context, color),
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(fmtMoney(v), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    ),
  );

  Widget _chartCard(String title, Widget child) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: DataBuilder<({List<Txn> txns, BudgetStatus budget, int savings})>(
        load: () => Repo.analytics(),
        builder: (context, data) {
            final (a, b) = _range();
            final all = data?.txns ?? <Txn>[];
            final bs = data?.budget;
            final savings = data?.savings ?? 0;
            final list = all.where((t) => !t.date.isBefore(a) && t.date.isBefore(b)).toList();
            final inc = list.where((t) => t.isIncome).fold<int>(0, (s, t) => s + t.amount);
            final exp = list.where((t) => !t.isIncome).fold<int>(0, (s, t) => s + t.amount);
            final byCat = <String, int>{};
            for (final t in list.where((t) => !t.isIncome)) {
              byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
            }
            final cats = byCat.entries.toList()..sort((x, y) => y.value.compareTo(x.value));

            final now = DateTime.now();
            final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
            final trend = [
              for (final m in months)
                all
                    .where((t) => !t.isIncome && t.date.year == m.year && t.date.month == m.month)
                    .fold<int>(0, (s, t) => s + t.amount),
            ];
            final trendMax = trend.fold<int>(0, (s, v) => v > s ? v : s);

            final budget = bs?.budget;
            final pct = (budget == null || budget.limit == 0) ? 0 : (bs!.spent * 100 ~/ budget.limit);

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _rl.length; i++)
                        ChoiceChip(
                          label: Text(i == 5 && custom != null && r == 5
                              ? '${DateFormat('dd/MM').format(custom!.start)}–${DateFormat('dd/MM').format(custom!.end)}'
                              : _rl[i]),
                          selected: r == i,
                          onSelected: (_) async {
                            if (i == 5) {
                              final rg = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (rg != null) {
                                setState(() {
                                  custom = rg;
                                  r = 5;
                                });
                              }
                            } else {
                              setState(() => r = i);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                SoftCard(
                  gradient: heroGradient(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chênh lệch thu - chi', style: TextStyle(color: Colors.white70)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(fmtMoney(inc - exp),
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [_stat('⬇️ Tổng thu', inc, 4), _stat('⬆️ Tổng chi', exp, 3)]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    _stat('🎯 Đã tiết kiệm', savings, 5),
                    _stat('👛 Số dư tổng', all.fold<int>(0, (s, t) => s + (t.isIncome ? t.amount : -t.amount)), 1),
                  ]),
                ),
                _chartCard(
                  'Ngân sách tháng này',
                  budget == null
                      ? const Text('Chưa đặt ngân sách. Vào Tài chính → Ngân sách để đặt.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (pct / 100).clamp(0, 1).toDouble(),
                                minHeight: 12,
                                valueColor: AlwaysStoppedAnimation(
                                  pct >= 100 ? const Color(0xFFE0556F) : (pct >= 80 ? const Color(0xFFF5A623) : const Color(0xFF5CC38B)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${pct >= 100 ? '⛔' : (pct >= 80 ? '⚠️' : '✅')} Đã dùng $pct% '
                                '(${fmtMoney(bs!.spent)} / ${fmtMoney(budget.limit)})'),
                          ],
                        ),
                ),
                _chartCard(
                  'Chi tiêu theo danh mục',
                  cats.isEmpty
                      ? const EmptyState('🍩', 'Chưa có dữ liệu chi tiêu')
                      : Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 32,
                                  sections: [
                                    for (var i = 0; i < cats.length; i++)
                                      PieChartSectionData(
                                        value: cats[i].value.toDouble(),
                                        color: _palette[i % _palette.length],
                                        radius: 70,
                                        title: cats[i].value / exp >= 0.05
                                            ? '${(cats[i].value / exp * 100).round()}%'
                                            : '',
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < cats.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.square_rounded, size: 14, color: _palette[i % _palette.length]),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(cats[i].key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text(fmtMoney(cats[i].value)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                _chartCard(
                  'Thu và chi',
                  (inc == 0 && exp == 0)
                      ? const EmptyState('📉', 'Chưa có dữ liệu')
                      : SizedBox(
                          height: 190,
                          child: BarChart(
                            BarChartData(
                              maxY: max(inc, exp).toDouble() * 1.15,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(v == 0 ? 'Thu' : 'Chi'),
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: [
                                BarChartGroupData(x: 0, barRods: [
                                  BarChartRodData(toY: inc.toDouble(), width: 40, color: const Color(0xFF5CC38B), borderRadius: BorderRadius.circular(8)),
                                ]),
                                BarChartGroupData(x: 1, barRods: [
                                  BarChartRodData(toY: exp.toDouble(), width: 40, color: const Color(0xFFE0556F), borderRadius: BorderRadius.circular(8)),
                                ]),
                              ],
                            ),
                          ),
                        ),
                ),
                _chartCard(
                  'Xu hướng chi tiêu 6 tháng',
                  trendMax == 0
                      ? const EmptyState('📈', 'Chưa có dữ liệu')
                      : SizedBox(
                          height: 190,
                          child: BarChart(
                            BarChartData(
                              maxY: trendMax * 1.2,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= months.length) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text('T${months[i].month}'),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (var i = 0; i < trend.length; i++)
                                  BarChartGroupData(x: i, barRods: [
                                    BarChartRodData(
                                      toY: trend[i].toDouble(),
                                      width: 22,
                                      color: pastelStrong(i),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                ),
                const SectionTitle('Cài đặt'),
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
              ],
            );
          },
      ),
    );
  }
}
