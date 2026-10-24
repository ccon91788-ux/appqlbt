import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'finance_screen.dart';
import 'settings_screen.dart';

/// Tab dưới "Tài chính" — gộp hai mục Tài chính và Thống kê vào một nơi
/// (trước đây là 2 tab dưới riêng). Nút bánh răng ở góc phải mở Cài đặt
/// (phần cài đặt trước nằm ở cuối tab Thống kê).
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  int _tab = 0; // 0 = Tài chính, 1 = Thống kê

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Tài chính' : 'Thống kê'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
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
              child: Row(
                children: [
                  _seg(cs, 0, 'Tài chính'),
                  _seg(cs, 1, 'Thống kê'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          FinanceScreen(embedded: true),
          AnalyticsScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _seg(ColorScheme cs, int i, String label) {
    final selected = _tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = i),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
