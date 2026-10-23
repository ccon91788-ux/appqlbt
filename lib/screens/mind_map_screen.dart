import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapNode {
  MindMapNode({required this.id, required this.title, List<MindMapNode>? children})
      : children = children ?? <MindMapNode>[];

  final String id;
  String title;
  final List<MindMapNode> children;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'children': children.map((node) => node.toJson()).toList(),
      };

  factory MindMapNode.fromJson(Map<String, dynamic> json) => MindMapNode(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        title: (json['title'] ?? '').toString(),
        children: (json['children'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => MindMapNode.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class MindMapDocument {
  MindMapDocument({required this.id, required this.title, required this.root});

  final String id;
  String title;
  MindMapNode root;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'root': root.toJson(),
      };

  factory MindMapDocument.fromJson(Map<String, dynamic> json) => MindMapDocument(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        title: (json['title'] ?? 'Sơ đồ tư duy').toString(),
        root: json['root'] is Map
            ? MindMapNode.fromJson(Map<String, dynamic>.from(json['root'] as Map))
            : MindMapNode(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: (json['title'] ?? 'Ý tưởng chính').toString(),
              ),
      );
}

class _MindMapStore {
  static const _key = 'lifesync_mind_maps_v1';

  static Future<List<MindMapDocument>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((item) => MindMapDocument.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<MindMapDocument> maps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(maps.map((map) => map.toJson()).toList()));
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  List<MindMapDocument> _maps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final maps = await _MindMapStore.load();
    if (!mounted) return;
    setState(() {
      _maps = maps;
      _loading = false;
    });
  }

  Future<String?> _ask(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Nhập nội dung...', border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _createMap() async {
    final title = await _ask('Tạo sơ đồ tư duy', initial: 'Sơ đồ mới');
    if (title == null) return;
    final doc = MindMapDocument(
      id: _newId(),
      title: title,
      root: MindMapNode(id: _newId(), title: title),
    );
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _MindMapEditor(document: doc, onChanged: _load)));
    await _load();
  }

  Future<void> _openMap(MindMapDocument map) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _MindMapEditor(document: map, onChanged: _load)));
    await _load();
  }

  Future<void> _deleteMap(MindMapDocument map) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sơ đồ?'),
        content: Text('Bạn có muốn xóa “${map.title}” không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    _maps.removeWhere((item) => item.id == map.id);
    await _MindMapStore.save(_maps);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sơ đồ tư duy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMap,
        icon: const Icon(Icons.add),
        label: const Text('Tạo sơ đồ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _maps.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_tree_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Sắp xếp ý tưởng theo nhánh', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text('Tạo sơ đồ cho kế hoạch học tập, mục tiêu cá nhân, dự án hoặc bất kỳ ý tưởng nào.', textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(onPressed: _createMap, icon: const Icon(Icons.add), label: const Text('Tạo sơ đồ đầu tiên')),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _maps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final map = _maps[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: const Icon(Icons.account_tree_outlined)),
                        title: Text(map.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${map.root.children.length} nhánh chính'),
                        onTap: () => _openMap(map),
                        trailing: IconButton(tooltip: 'Xóa sơ đồ', onPressed: () => _deleteMap(map), icon: const Icon(Icons.delete_outline)),
                      ),
                    );
                  },
                ),
    );
  }
}

class _MindMapEditor extends StatefulWidget {
  const _MindMapEditor({required this.document, required this.onChanged});
  final MindMapDocument document;
  final Future<void> Function() onChanged;

  @override
  State<_MindMapEditor> createState() => _MindMapEditorState();
}

class _MindMapEditorState extends State<_MindMapEditor> {
  static const _colors = [Color(0xFFDBEAFE), Color(0xFFD1FAE5), Color(0xFFFEF3C7), Color(0xFFFCE7F3), Color(0xFFEDE9FE), Color(0xFFCFFAFE)];
  bool _saving = false;

  Future<void> _persist() async {
    if (_saving) return;
    _saving = true;
    try {
      final maps = await _MindMapStore.load();
      final index = maps.indexWhere((map) => map.id == widget.document.id);
      if (index == -1) {
        maps.add(widget.document);
      } else {
        maps[index] = widget.document;
      }
      await _MindMapStore.save(maps);
      await widget.onChanged();
    } finally {
      _saving = false;
    }
  }

  Future<void> _renameRoot() async {
    final value = await _askNode('Đổi chủ đề trung tâm', widget.document.root.title);
    if (value == null) return;
    setState(() {
      widget.document.root.title = value;
      widget.document.title = value;
    });
    await _persist();
  }

  Future<String?> _askNode(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Ví dụ: Ôn tập Toán', border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu'))],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _addChild(MindMapNode parent) async {
    final value = await _askNode(parent == widget.document.root ? 'Thêm nhánh chính' : 'Thêm nhánh con');
    if (value == null) return;
    setState(() => parent.children.add(MindMapNode(id: _newId(), title: value)));
    await _persist();
  }

  Future<void> _editNode(MindMapNode node) async {
    final value = await _askNode('Sửa nội dung', node.title);
    if (value == null) return;
    setState(() => node.title = value);
    if (node.id == widget.document.root.id) widget.document.title = value;
    await _persist();
  }

  Future<void> _deleteNode(MindMapNode parent, MindMapNode node) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Xóa nhánh?'),
      content: Text('Xóa “${node.title}” cùng toàn bộ nhánh con?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa'))],
    ));
    if (ok != true) return;
    setState(() => parent.children.removeWhere((item) => item.id == node.id));
    await _persist();
  }

  Widget _nodeCard(MindMapNode node, MindMapNode? parent, int depth) {
    final color = _colors[depth % _colors.length];
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 18, top: 6, bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (depth > 0) Padding(padding: const EdgeInsets.only(top: 17, right: 7), child: Container(width: 12, height: 2, color: Theme.of(context).colorScheme.outlineVariant)),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: color.withOpacity(Theme.of(context).brightness == Brightness.dark ? .22 : .9), border: Border.all(color: color.withOpacity(.95)), borderRadius: BorderRadius.circular(depth == 0 ? 18 : 13)),
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 4, 8), child: Row(children: [
                Expanded(child: Text(node.title, style: TextStyle(fontWeight: depth <= 1 ? FontWeight.w600 : FontWeight.normal, fontSize: depth == 0 ? 17 : 14))),
                IconButton(tooltip: 'Thêm nhánh con', visualDensity: VisualDensity.compact, onPressed: () => _addChild(node), icon: const Icon(Icons.add_circle_outline, size: 20)),
                IconButton(tooltip: 'Sửa', visualDensity: VisualDensity.compact, onPressed: () => _editNode(node), icon: const Icon(Icons.edit_outlined, size: 18)),
                if (parent != null) IconButton(tooltip: 'Xóa', visualDensity: VisualDensity.compact, onPressed: () => _deleteNode(parent, node), icon: const Icon(Icons.close, size: 18)),
              ])),
            ),
          ),
        ]),
        if (node.children.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 8, top: 3), child: Container(width: 2, height: 12, color: Theme.of(context).colorScheme.outlineVariant)),
        for (final child in node.children) _nodeCard(child, node, depth + 1),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: 'Đổi chủ đề', onPressed: _renameRoot, icon: const Icon(Icons.drive_file_rename_outline))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addChild(widget.document.root), icon: const Icon(Icons.add), label: const Text('Thêm nhánh')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [Icon(Icons.account_tree_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('Chạm + để tạo nhánh con; dùng biểu tượng sửa hoặc xóa để chỉnh sơ đồ.')),])),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 100), children: [_nodeCard(widget.document.root, null, 0)])),
      ]),
    );
  }
}
