import 'package:flutter/material.dart';
import 'stickers.dart';
import 'utils.dart';

/// Bảng màu viền sticker (ARGB). Giá trị 0 = không viền.
const borderPalette = <int>[
  0xFFD94A2F, 0xFFB86B2E, 0xFFE6AC1F, 0xFF8E4F9A, 0xFF4B8B57, 0xFF2F7BB5,
  0xFFC45A82, 0xFF6F6BAA, 0xFFE07A8A, 0xFF5BA687, 0xFFE0553A, 0xFFEF8A4A,
  0xFFE8B83D, 0xFF7DBB4A, 0xFF4FBAB4, 0xFF3D8F8F, 0xFF4A74CC, 0xFF7060B8,
  0xFFC4509A, 0xFFD9648A, 0xFF8FA662, 0xFF5A9E72, 0xFFA5834A, 0xFF8C8272,
  0xFF8A9BB0,
];

/// Chọn màu viền: ô đầu tiên là "không viền".
class BorderPalette extends StatelessWidget {
  const BorderPalette({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  Widget _dot(BuildContext context, int c, String label) {
    final sel = value == c;
    return Semantics(
      button: true,
      selected: sel,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(c),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c == 0 ? null : Color(c),
            border: Border.all(
              color: sel ? Theme.of(context).colorScheme.onSurface : Colors.black12,
              width: sel ? 3 : 1,
            ),
          ),
          child: c == 0
              ? const Icon(Icons.block, size: 20)
              : (sel ? const Icon(Icons.check, size: 20, color: Colors.white) : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _dot(context, 0, 'Không viền'),
      for (final c in borderPalette) _dot(context, c, 'Màu viền'),
    ],
  );
}

/// Lưới chọn sticker: [Mặc định] [+ Tải ảnh] [ảnh đã tải] [sticker có sẵn].
/// [value] = '' nghĩa là mặc định.
class StickerGrid extends StatefulWidget {
  const StickerGrid({
    super.key,
    required this.value,
    required this.onChanged,
    required this.defaultChild,
    this.border = 0,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final Widget defaultChild;
  final int border;

  @override
  State<StickerGrid> createState() => _StickerGridState();
}

class _StickerGridState extends State<StickerGrid> {
  List<String> mine = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    final l = await myStickers();
    if (mounted) setState(() => mine = l);
  }

  Future<void> _upload() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final s = await pickCustomSticker();
      if (s != null) {
        await _loadMine();
        widget.onChanged(s);
      }
    } catch (_) {
      if (mounted) toast(context, 'Không thể dùng ảnh này. Hãy thử ảnh khác.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _tile(BuildContext context, {required bool selected, required VoidCallback onTap, required Widget child, String? label}) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2.5),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [...mine, ...stickerNames];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _tile(
          context,
          selected: widget.value.isEmpty,
          onTap: () => widget.onChanged(''),
          label: 'Sticker mặc định',
          child: widget.defaultChild,
        ),
        _tile(
          context,
          selected: false,
          onTap: _upload,
          label: 'Tải ảnh của bạn',
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.add_photo_alternate_outlined), Text('Tải ảnh', style: TextStyle(fontSize: 11))],
                ),
        ),
        for (final s in all)
          _tile(
            context,
            selected: widget.value == s,
            onTap: () => widget.onChanged(s),
            child: StickerBadge(s, border: widget.border, size: 60),
          ),
      ],
    );
  }
}
