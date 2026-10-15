import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../sticker_picker.dart';
import '../stickers.dart';
import '../utils.dart';

/// Mở bảng tạo / sửa danh mục. [existing] = null: tạo danh mục mới.
Future<void> openCategorySheet(BuildContext context, {CatStyle? existing, required bool income}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CategorySheet(existing: existing, income: income),
  );
}

class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key, this.existing, required this.income});
  final CatStyle? existing;
  final bool income;
  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  final _name = TextEditingController();
  String sticker = '';
  int border = 0;
  bool saving = false;

  CatStyle? get _e => widget.existing;
  bool get _isNew => _e == null;
  bool get _canRename => _isNew || _e!.custom;

  @override
  void initState() {
    super.initState();
    final e = _e;
    if (e != null) {
      _name.text = e.name;
      sticker = e.sticker;
      border = e.border;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Hãy nhập tên danh mục.');
      return;
    }
    setState(() => saving = true);
    try {
      final c = CatStyle(
        name: name,
        isIncome: _e?.isIncome ?? widget.income,
        sticker: sticker,
        border: border,
        custom: _e?.custom ?? true,
      );
      final ok = await Repo.saveCategory(c, oldName: _e?.name);
      if (!mounted) return;
      if (!ok) {
        toast(context, 'Tên danh mục đã tồn tại.');
        setState(() => saving = false);
        return;
      }
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        toast(context, 'Không thể lưu danh mục.');
        setState(() => saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Các giao dịch cũ vẫn giữ tên "${_e!.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    await Repo.deleteCategory(_e!.name);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _name.text.trim().isEmpty ? (_e?.name ?? '') : _name.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              CatBadge(previewName, size: 56, stickerOverride: sticker, borderOverride: border),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isNew ? 'Danh mục mới' : 'Sửa danh mục',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton(onPressed: saving ? null : _save, child: const Text('LƯU')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: _canRename,
            maxLength: 24,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Tên danh mục'),
          ),
          const SizedBox(height: 8),
          const Text('Màu viền sticker', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          BorderPalette(value: border, onChanged: (v) => setState(() => border = v)),
          const SizedBox(height: 16),
          const Text('Sticker', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Chọn sticker có sẵn, dùng mặc định, hoặc tải ảnh của bạn.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          StickerGrid(
            value: sticker,
            border: border,
            onChanged: (v) => setState(() => sticker = v),
            defaultChild: CatBadge(previewName, size: 56, stickerOverride: '', borderOverride: border),
          ),
          if (!_isNew && _e!.custom) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa danh mục'),
            ),
          ],
        ],
      ),
    );
  }
}
