import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'data/models.dart';
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

/// Kiểu danh mục người dùng đã tùy chỉnh (tên -> kiểu). Được nạp bởi Repo.categories().
final Map<String, CatStyle> catStyles = {};

/// Sticker của danh mục: bản người dùng chọn, nếu không thì sticker mặc định.
String? catStickerName(String category) {
  final s = catStyles[category]?.sticker;
  if (s != null && s.isNotEmpty) return s;
  return _catSticker[category];
}

/// Màu viền sticker của danh mục (ARGB), 0 = không viền.
int catBorder(String category) => catStyles[category]?.border ?? 0;

bool isFileSticker(String name) => name.startsWith('file:');

String stickerAsset(String name) => 'assets/stickers/$name.png';

// ---------- Sticker do người dùng tải lên ----------

Future<Directory> _stickerDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'stickers'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Chọn ảnh từ máy, thu nhỏ còn 256px, lưu vào bộ nhớ app.
/// Trả về 'file:<đường dẫn>', hoặc null nếu người dùng hủy. Ném lỗi nếu ảnh hỏng.
Future<String?> pickCustomSticker() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  final bytes = (r == null || r.files.isEmpty) ? null : r.files.first.bytes;
  if (bytes == null) return null;
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw const FormatException('image');
  final f = File(p.join((await _stickerDir()).path, '${DateTime.now().millisecondsSinceEpoch}.png'));
  await f.writeAsBytes(data.buffer.asUint8List());
  return 'file:${f.path}';
}

/// Các sticker người dùng đã tải lên trước đó (mới nhất trước), để dùng lại.
Future<List<String>> myStickers() async {
  try {
    final files = (await _stickerDir())
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => 'file:${f.path}').toList();
  } catch (_) {
    return [];
  }
}

/// Hiển thị một sticker: có sẵn (assets) hoặc do người dùng tải lên (file).
class StickerImage extends StatelessWidget {
  const StickerImage(this.name, {super.key, this.size = 46});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget blank(BuildContext c, Object e, StackTrace? s) => SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.image_not_supported_outlined, size: size * 0.5),
    );
    if (isFileSticker(name)) {
      return Image.file(
        File(name.substring(5)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        filterQuality: FilterQuality.medium,
        errorBuilder: blank,
      );
    }
    return Image.asset(
      stickerAsset(name),
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (c, e, s) => SizedBox(width: size, height: size),
    );
  }
}

/// Sticker có viền màu hình tròn. [border] = 0 và là sticker có sẵn -> không viền,
/// giữ nguyên kiểu cũ. Ảnh tải lên luôn được cắt tròn cho gọn.
class StickerBadge extends StatelessWidget {
  const StickerBadge(this.sticker, {super.key, this.border = 0, this.size = 46});
  final String sticker;
  final int border;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (border == 0 && !isFileSticker(sticker)) return StickerImage(sticker, size: size);
    final w = border == 0 ? 0.0 : (size * 0.07).clamp(1.5, 4.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        border: border == 0 ? null : Border.all(color: Color(border), width: w),
      ),
      child: ClipOval(child: StickerImage(sticker, size: size - 2 * w)),
    );
  }
}

/// Ô biểu tượng của danh mục: sticker nếu có, không thì quay về Badge3D emoji.
/// [stickerOverride] / [borderOverride] dùng để xem trước khi đang chỉnh sửa
/// (stickerOverride '' = sticker mặc định).
class CatBadge extends StatelessWidget {
  const CatBadge(
    this.category, {
    super.key,
    this.color = 0,
    this.size = 46,
    this.stickerOverride,
    this.borderOverride,
  });
  final String category;
  final int color;
  final double size;
  final String? stickerOverride;
  final int? borderOverride;

  @override
  Widget build(BuildContext context) {
    final o = stickerOverride;
    final s = o != null ? (o.isEmpty ? _catSticker[category] : o) : catStickerName(category);
    final b = borderOverride ?? catBorder(category);
    if (s == null) {
      if (b == 0) return Badge3D(catEmoji(category), color: color, size: size);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: Color(b), width: 3),
        ),
        child: Badge3D(catEmoji(category), color: color, size: size - 6),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: (b != 0 || isFileSticker(s)) ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: (b != 0 || isFileSticker(s)) ? null : BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: pastelStrong(color).withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: StickerBadge(s, border: b, size: size),
    );
  }
}

/// Biểu tượng nhỏ cho ActionChip danh mục.
Widget catAvatar(String category, {double size = 24}) {
  final s = catStickerName(category);
  if (s == null) return Text(catEmoji(category));
  return StickerBadge(s, border: catBorder(category), size: size);
}
