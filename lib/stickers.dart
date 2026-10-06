import 'package:flutter/material.dart';
import 'ui.dart';
import 'utils.dart';

/// Tên các sticker vịt trong assets/stickers/<tên>.png
const stickerNames = <String>[
  'food',
  'coffee',
  'transport',
  'shopping',
  'home',
  'idea',
  'entertainment',
  'health',
  'travel',
  'tools',
  'education',
  'study',
  'stress',
  'family',
  'gift',
  'cleaning',
  'insurance',
  'work',
  'chat',
  'rest',
  'baby',
  'pet',
  'sale',
  'groceries',
  'phone',
  'search',
  'repair',
  'water',
];

/// Danh mục mặc định -> sticker. Danh mục tự nhập không có ở đây sẽ dùng emoji.
const _catSticker = <String, String>{
  'Lương': 'work',
  'Trợ cấp': 'gift',
  'Kinh doanh': 'groceries',
  'Thu nhập khác': 'sale',
  'Ăn uống': 'food',
  'Di chuyển': 'transport',
  'Giáo dục': 'education',
  'Mua sắm': 'shopping',
  'Giải trí': 'entertainment',
  'Hóa đơn': 'home',
  'Sức khỏe': 'health',
  'Chi tiêu khác': 'sale',
};

String? catStickerName(String category) => _catSticker[category];

String stickerAsset(String name) => 'assets/stickers/$name.png';

/// Hiển thị một sticker (có sẵn nền bo góc, trong suốt ở 4 góc).
class StickerImage extends StatelessWidget {
  const StickerImage(this.name, {super.key, this.size = 46});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    stickerAsset(name),
    width: size,
    height: size,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.medium,
    errorBuilder: (context, error, stack) => SizedBox(width: size, height: size),
  );
}

/// Ô biểu tượng của danh mục: dùng sticker nếu có, không thì quay về Badge3D emoji.
class CatBadge extends StatelessWidget {
  const CatBadge(this.category, {super.key, this.color = 0, this.size = 46});
  final String category;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = catStickerName(category);
    if (s == null) return Badge3D(catEmoji(category), color: color, size: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: pastelStrong(color).withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: StickerImage(s, size: size),
    );
  }
}

/// Biểu tượng nhỏ cho ActionChip danh mục.
Widget catAvatar(String category, {double size = 24}) {
  final s = catStickerName(category);
  return s == null ? Text(catEmoji(category)) : StickerImage(s, size: size);
}
