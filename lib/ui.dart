import 'package:flutter/material.dart';
import 'data/repo.dart';
import 'utils.dart';

const _pastels = [
  Color(0xFFFFD6C2), // đào
  Color(0xFFC6E7F8), // xanh trời
  Color(0xFFFFEFB0), // vàng bơ
  Color(0xFFF9CFE0), // hồng
  Color(0xFFCFEFDC), // bạc hà
  Color(0xFFDAD0FA), // tím nhạt
];
const _strong = [
  Color(0xFFFF9B71),
  Color(0xFF5BB5E0),
  Color(0xFFF5C542),
  Color(0xFFF07BA5),
  Color(0xFF5CC38B),
  Color(0xFF8E7CF0),
];

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color pastel(BuildContext c, int i) {
  final base = _pastels[i.abs() % _pastels.length];
  return isDark(c)
      ? Color.alphaBlend(base.withAlpha(60), const Color(0xFF1F1F2B))
      : base;
}

Color pastelStrong(int i) => _strong[i.abs() % _strong.length];

LinearGradient heroGradient(BuildContext c) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: isDark(c)
      ? const [Color(0xFF5B49C9), Color(0xFF2F7FA8)]
      : const [Color(0xFF9D8CFF), Color(0xFF6CC5F2)],
);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF8E7CF0), brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: dark ? const Color(0xFF14141C) : const Color(0xFFF6F2FF),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark ? const Color(0xFF1B1B26) : Colors.white,
      indicatorColor: dark ? const Color(0xFF3A3560) : const Color(0xFFDAD0FA),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2A3A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
  });
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final bg = color ?? (dark ? const Color(0xFF232331) : Colors.white);
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? bg : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(dark ? 70 : 20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Ô biểu tượng kiểu "đồ chơi 3D" pastel: nền gradient, bóng đổ mềm, emoji.
class Badge3D extends StatelessWidget {
  const Badge3D(this.emoji, {super.key, this.color = 0, this.size = 46});
  final String emoji;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(dark ? 40 : 210), pastel(context, color)],
        ),
        boxShadow: [
          BoxShadow(
            color: pastelStrong(color).withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.emoji, this.text, {super.key});
  final String emoji;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Badge3D(emoji, size: 72),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
  );
}

Future<int?> askAmount(
  BuildContext context,
  String title, {
  int? initial,
  String label = 'Số tiền (₫)',
}) => showDialog<int>(
  context: context,
  builder: (_) => _AmountDialog(title: title, initial: initial, label: label),
);

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, this.initial, required this.label});
  final String title;
  final int? initial;
  final String label;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _c;
  String? _err;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
      text: widget.initial == null ? '' : groupDigits('${widget.initial}'),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [const ThousandsFormatter()],
        decoration: InputDecoration(labelText: widget.label, errorText: _err),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            final v = parseMoney(_c.text);
            if (v == null || v <= 0) {
              setState(() => _err = 'Số tiền không hợp lệ');
              return;
            }
            Navigator.pop(context, v);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

/// Tải dữ liệu một lần, giữ kết quả trong bộ nhớ và chỉ tải lại khi dữ liệu thay đổi
/// (dataTick tăng). Bấm chọn ngày, gõ tìm kiếm... không còn truy vấn lại CSDL.
class DataBuilder<T> extends StatefulWidget {
  const DataBuilder({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T? data) builder;

  @override
  State<DataBuilder<T>> createState() => _DataBuilderState<T>();
}

class _DataBuilderState<T> extends State<DataBuilder<T>> {
  late Future<T> _future;
  T? _last;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
    dataTick.addListener(_reload);
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = widget.load());
  }

  @override
  void dispose() {
    dataTick.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) _last = snap.data;
        return widget.builder(context, snap.data ?? _last);
      },
    );
  }
}
