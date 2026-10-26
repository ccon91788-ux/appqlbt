import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapNode {
  MindMapNode({
    required this.id,
    required this.title,
    List<MindMapNode>? children,
    this.color,
    this.collapsed = false,
    this.dx = 0,
    this.dy = 0,
  }) : children = children ?? <MindMapNode>[];

  final String id;
  String title;
  final List<MindMapNode> children;

  /// Màu tự chọn (chỉ số trong bảng màu của trình sửa); null = theo màu nhánh.
  int? color;

  /// true = đang thu gọn, ẩn toàn bộ nhánh con.
  bool collapsed;

  /// Độ lệch tự do so với vị trí tự động xếp (khi kéo thả nút bằng tay).
  double dx;
  double dy;

  int get totalCount => 1 + children.fold<int>(0, (s, c) => s + c.totalCount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'color': color,
        'collapsed': collapsed,
        'dx': dx,
        'dy': dy,
        'children': children.map((node) => node.toJson()).toList(),
      };

  factory MindMapNode.fromJson(Map<String, dynamic> json) => MindMapNode(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        title: (json['title'] ?? '').toString(),
        color: (json['color'] as num?)?.toInt(),
        collapsed: json['collapsed'] == true,
        dx: (json['dx'] as num?)?.toDouble() ?? 0,
        dy: (json['dy'] as num?)?.toDouble() ?? 0,
        children: (json['children'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => MindMapNode.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class MindMapDocument {
  MindMapDocument(
      {required this.id,
      required this.title,
      required this.root,
      this.layout = 'two-sided'});

  final String id;
  String title;
  MindMapNode root;

  /// Kiểu bố cục: 'two-sided' (hai phía), 'right' (sang phải),
  /// 'left' (sang trái), 'vertical' (từ trên xuống). Sơ đồ cũ không có
  /// trường này sẽ dùng mặc định 'two-sided'.
  String layout;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'layout': layout,
        'root': root.toJson(),
      };

  factory MindMapDocument.fromJson(Map<String, dynamic> json) => MindMapDocument(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        title: (json['title'] ?? 'Sơ đồ tư duy').toString(),
        layout: (json['layout'] ?? 'two-sided').toString(),
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
                        subtitle: Text('${map.root.children.length} nhánh chính • ${map.root.totalCount} nút'),
                        onTap: () => _openMap(map),
                        trailing: IconButton(tooltip: 'Xóa sơ đồ', onPressed: () => _deleteMap(map), icon: const Icon(Icons.delete_outline)),
                      ),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trình sửa sơ đồ dạng canvas (giống các app mind map):
// - Kéo nền để di chuyển khung nhìn, chụm 2 ngón hoặc nút +/- để phóng to /
//   thu nhỏ (có % và nút căn giữa), nút trung tâm ở giữa, các nhánh tỏa 2 bên
//   với đường nối cong theo màu nhánh.
// - Kéo thả từng nút để dời vị trí tự do, chạm để chọn rồi thêm nhánh con /
//   nhánh ngang, sửa nội dung, đổi màu, thu gọn / mở rộng, xóa.
// - Hoàn tác / làm lại, mở rộng / thu gọn tất cả, sắp xếp lại tự động.
// ---------------------------------------------------------------------------

const _mmPalette = <Color>[
  Color(0xFFEF4444), // đỏ — nút trung tâm
  Color(0xFFF59E0B), // cam
  Color(0xFFFACC15), // vàng
  Color(0xFF4ADE80), // xanh lá
  Color(0xFF38BDF8), // xanh dương
  Color(0xFFA78BFA), // tím
  Color(0xFFF472B6), // hồng
  Color(0xFF2DD4BF), // ngọc
];

Color _mmTextOn(Color bg) =>
    bg.computeLuminance() > 0.55 ? const Color(0xFF1F2937) : Colors.white;

class _NodeGeom {
  _NodeGeom(this.node, this.depth, this.side, this.color, this.parentId);

  final MindMapNode node;
  final int depth;
  int side; // 1 = nhánh bên phải, -1 = bên trái, 0 = trung tâm
  final Color color;
  final String? parentId;
  Size size = Size.zero;
  Rect rect = Rect.zero;
  double extent = 0; // chiều cao cả cây con khi đang mở
}

class _MindMapEditor extends StatefulWidget {
  const _MindMapEditor({required this.document, required this.onChanged});
  final MindMapDocument document;
  final Future<void> Function() onChanged;

  @override
  State<_MindMapEditor> createState() => _MindMapEditorState();
}

class _MindMapEditorState extends State<_MindMapEditor> {
  static const double _canvas = 4400;
  static const double _hGap = 64;
  static const double _vGap = 20;

  final TransformationController _tc = TransformationController();
  double _scale = 1;
  Size _viewSize = Size.zero;
  bool _initView = false;
  bool _saving = false;
  String? _selectedId;
  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];

  MindMapNode get _root => widget.document.root;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransform);
    _tc.dispose();
    super.dispose();
  }

  void _onTransform() {
    final s = _tc.value.getMaxScaleOnAxis();
    if ((s - _scale).abs() > 0.005 && mounted) setState(() => _scale = s);
  }

  // ---------------- lưu trữ + hoàn tác / làm lại ----------------

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

  String _snapshot() => jsonEncode(_root.toJson());

  void _pushHistory() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restore(String snap) {
    final node =
        MindMapNode.fromJson(Map<String, dynamic>.from(jsonDecode(snap) as Map));
    setState(() {
      widget.document.root = node;
      widget.document.title = node.title;
      _selectedId = null;
    });
    _persist();
  }

  void _doUndo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
  }

  void _doRedo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
  }

  // ---------------- bố cục tự động (2 phía) ----------------

  List<MindMapNode> _vis(MindMapNode n) =>
      n.collapsed ? const <MindMapNode>[] : n.children;

  TextStyle _styleFor(int depth) => TextStyle(
        fontSize: depth == 0 ? 18 : (depth == 1 ? 15.5 : 14),
        fontWeight: depth == 0
            ? FontWeight.w800
            : (depth == 1 ? FontWeight.w700 : FontWeight.w500),
        height: 1.25,
      );

  Size _measure(MindMapNode n, int depth) {
    final tp = TextPainter(
      text: TextSpan(
          text: n.title.isEmpty ? ' ' : n.title, style: _styleFor(depth)),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 168);
    var w = tp.width + 34;
    if (n.collapsed && n.children.isNotEmpty) w += 30; // chỗ cho huy hiệu +N
    return Size(w.clamp(92, 232).toDouble(), tp.height + 20);
  }

  Map<String, _NodeGeom> _layout() {
    final geoms = <String, _NodeGeom>{};

    void collect(MindMapNode n, int depth, int side, Color inherited,
        String? parentId) {
      final g = _NodeGeom(
        n,
        depth,
        side,
        n.color != null
            ? _mmPalette[n.color! % _mmPalette.length]
            : inherited,
        parentId,
      )..size = _measure(n, depth);
      geoms[n.id] = g;
      final kids = _vis(n);
      for (var i = 0; i < kids.length; i++) {
        // Nhánh chính lấy màu theo thứ tự trong bảng màu, nút sâu hơn theo nhánh.
        final childInherited =
            depth == 0 ? _mmPalette[(i + 1) % _mmPalette.length] : g.color;
        collect(kids[i], depth + 1, side, childInherited, n.id);
      }
    }

    collect(_root, 0, 0, _mmPalette[_root.color ?? 0], null);

    double extentOf(_NodeGeom g) {
      final kids = _vis(g.node);
      if (kids.isEmpty) return g.extent = g.size.height;
      var total = 0.0;
      for (final c in kids) {
        total += extentOf(geoms[c.id]!);
      }
      total += _vGap * (kids.length - 1);
      return g.extent = math.max(g.size.height, total);
    }

    for (final g in geoms.values) {
      extentOf(g);
    }

    // Kiểu từ trên xuống dùng bố cục riêng, không chia trái/phải.
    if (widget.document.layout == 'vertical') {
      return _layoutVertical(geoms);
    }

    // Chia các nhánh chính sang 2 phía (cân bằng theo chiều cao cây con),
    // hoặc dồn hết sang một phía nếu kiểu đã chọn là 'right' / 'left'.
    final mode = widget.document.layout;
    var rightTotal = 0.0;
    var leftTotal = 0.0;
    for (final b in _vis(_root)) {
      final g = geoms[b.id]!;
      if (mode == 'right') {
        g.side = 1;
      } else if (mode == 'left') {
        g.side = -1;
      } else if (rightTotal <= leftTotal) {
        g.side = 1;
        rightTotal += g.extent;
      } else {
        g.side = -1;
        leftTotal += g.extent;
      }
    }
    void fixSides(MindMapNode n, int side) {
      for (final c in _vis(n)) {
        geoms[c.id]!.side = side;
        fixSides(c, side);
      }
    }

    for (final b in _vis(_root)) {
      fixSides(b, geoms[b.id]!.side);
    }

    void place(_NodeGeom g, Rect? parentRect, double topY) {
      final n = g.node;
      final cy = g.depth == 0 ? _canvas / 2 : topY + g.extent / 2;
      final double cx;
      if (g.depth == 0) {
        cx = _canvas / 2;
      } else if (g.side >= 0) {
        cx = parentRect!.right + _hGap + g.size.width / 2;
      } else {
        cx = parentRect!.left - _hGap - g.size.width / 2;
      }
      g.rect = Rect.fromLTWH(cx - g.size.width / 2 + n.dx,
          cy - g.size.height / 2 + n.dy, g.size.width, g.size.height);
      final kids = _vis(n).map((c) => geoms[c.id]!).toList();
      if (kids.isEmpty) return;
      if (g.depth == 0) {
        for (final side in [1, -1]) {
          final group = kids.where((k) => k.side == side).toList();
          if (group.isEmpty) continue;
          final total =
              group.fold<double>(0, (s, k) => s + k.extent) +
                  _vGap * (group.length - 1);
          var t = _canvas / 2 - total / 2;
          for (final k in group) {
            place(k, g.rect, t);
            t += k.extent + _vGap;
          }
        }
      } else {
        final total =
            kids.fold<double>(0, (s, k) => s + k.extent) +
                _vGap * (kids.length - 1);
        var t = topY + (g.extent - total) / 2;
        for (final k in kids) {
          place(k, g.rect, t);
          t += k.extent + _vGap;
        }
      }
    }

    place(geoms[_root.id]!, null, 0);
    return geoms;
  }

  /// Bố cục từ trên xuống: nút trung tâm ở trên cùng, các nhánh tỏa xuống
  /// dưới. Mỗi cây con chiếm một khoảng ngang bằng chiều rộng lớn nhất của
  /// nó (hoặc tổng các cây con), nút được căn giữa khoảng của mình.
  Map<String, _NodeGeom> _layoutVertical(Map<String, _NodeGeom> geoms) {
    final depthH = <int, double>{};
    for (final g in geoms.values) {
      depthH[g.depth] = math.max(depthH[g.depth] ?? 0, g.size.height);
    }
    var maxDepth = 0;
    for (final d in depthH.keys) {
      if (d > maxDepth) maxDepth = d;
    }
    final yOff = <int, double>{};
    var y = 160.0;
    for (var d = 0; d <= maxDepth; d++) {
      yOff[d] = y;
      y += (depthH[d] ?? 60) + _vGap * 2;
    }

    double spanOf(_NodeGeom g) {
      final kids = _vis(g.node).map((c) => geoms[c.id]!).toList();
      if (kids.isEmpty) return g.size.width;
      var s = kids.fold<double>(0, (a, k) => a + spanOf(k));
      s += _hGap * 0.6 * (kids.length - 1);
      return math.max(g.size.width, s);
    }

    void placeV(_NodeGeom g, double spanLeft) {
      final span = spanOf(g);
      final cx = spanLeft + span / 2;
      final rowH = depthH[g.depth] ?? g.size.height;
      final top = (yOff[g.depth] ?? 160) + (rowH - g.size.height) / 2;
      g.rect = Rect.fromLTWH(cx - g.size.width / 2 + g.node.dx,
          top + g.node.dy, g.size.width, g.size.height);
      var x = spanLeft;
      for (final c in _vis(g.node).map((e) => geoms[e.id]!)) {
        final cs = spanOf(c);
        placeV(c, x);
        x += cs + _hGap * 0.6;
      }
    }

    final root = geoms[_root.id]!;
    placeV(root, _canvas / 2 - spanOf(root) / 2);
    return geoms;
  }

  // ---------------- tìm nút ----------------

  MindMapNode? _find(String id, [MindMapNode? from]) {
    final start = from ?? _root;
    if (start.id == id) return start;
    for (final c in start.children) {
      final r = _find(id, c);
      if (r != null) return r;
    }
    return null;
  }

  MindMapNode? _parentOf(String id, [MindMapNode? from]) {
    final start = from ?? _root;
    for (final c in start.children) {
      if (c.id == id) return start;
      final r = _parentOf(id, c);
      if (r != null) return r;
    }
    return null;
  }

  // ---------------- hộp thoại ----------------

  Future<String?> _askNode(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'Ví dụ: Ôn tập Toán', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Lưu')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  // ---------------- thao tác trên nút ----------------

  Future<void> _addChild(MindMapNode parent) async {
    final value = await _askNode(
        parent.id == _root.id ? 'Thêm nhánh chính' : 'Thêm nhánh con');
    if (value == null) return;
    _pushHistory();
    setState(() {
      parent.collapsed = false;
      parent.children.add(MindMapNode(id: _newId(), title: value));
      _selectedId = parent.children.last.id;
    });
    await _persist();
  }

  Future<void> _addSibling(MindMapNode node) async {
    final parent = _parentOf(node.id);
    if (parent == null) return;
    final value = await _askNode('Thêm nhánh ngang');
    if (value == null) return;
    _pushHistory();
    setState(() {
      final i = parent.children.indexWhere((c) => c.id == node.id);
      final created = MindMapNode(id: _newId(), title: value);
      parent.children.insert(i + 1, created);
      _selectedId = created.id;
    });
    await _persist();
  }

  Future<void> _editNode(MindMapNode node) async {
    final value = await _askNode('Sửa nội dung', node.title);
    if (value == null) return;
    _pushHistory();
    setState(() => node.title = value);
    if (node.id == _root.id) widget.document.title = value;
    await _persist();
  }

  Future<void> _deleteNode(MindMapNode node) async {
    final parent = _parentOf(node.id);
    if (parent == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhánh?'),
        content: Text('Xóa “${node.title}” cùng toàn bộ nhánh con?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    _pushHistory();
    setState(() {
      parent.children.removeWhere((item) => item.id == node.id);
      _selectedId = parent.id;
    });
    await _persist();
  }

  Future<void> _pickColor(MindMapNode node) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Màu của nút'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _mmPalette.length; i++)
              GestureDetector(
                onTap: () => Navigator.pop(context, i),
                child: CircleAvatar(
                  backgroundColor: _mmPalette[i],
                  radius: 19,
                  child: node.color == i
                      ? Icon(Icons.check,
                          color: _mmTextOn(_mmPalette[i]), size: 18)
                      : null,
                ),
              ),
          ],
        ),
        actions: [
          if (node.id != _root.id)
            TextButton(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Tự động theo nhánh'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
        ],
      ),
    );
    if (result == null) return;
    _pushHistory();
    setState(() => node.color = result == -1 ? null : result);
    await _persist();
  }

  void _toggleCollapse(MindMapNode node) {
    if (node.children.isEmpty) return;
    _pushHistory();
    setState(() {
      node.collapsed = !node.collapsed;
      _selectedId = node.id;
    });
    _persist();
  }

  void _setAllCollapsed(bool collapsed) {
    _pushHistory();
    void walk(MindMapNode n) {
      // Thu gọn tất cả: giữ nút trung tâm đang mở để còn thấy các nhánh chính.
      // Mở rộng tất cả: mở cả nút trung tâm.
      if (n.children.isNotEmpty && (!collapsed || n.id != _root.id)) {
        n.collapsed = collapsed;
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    setState(() => walk(_root));
    _persist();
  }

  void _resetLayout() {
    _pushHistory();
    void walk(MindMapNode n) {
      n.dx = 0;
      n.dy = 0;
      for (final c in n.children) {
        walk(c);
      }
    }

    setState(() => walk(_root));
    _persist();
  }

  /// Chọn kiểu bố cục cho sơ đồ (lưu theo từng sơ đồ).
  Future<void> _pickLayout() async {
    const options = <(String, String, String)>[
      (
        'two-sided',
        'Hai phía',
        'Nhánh tỏa đều sang hai bên nút trung tâm',
      ),
      ('right', 'Sang phải', 'Toàn bộ nhánh nằm bên phải'),
      ('left', 'Sang trái', 'Toàn bộ nhánh nằm bên trái'),
      (
        'vertical',
        'Từ trên xuống',
        'Nút trung tâm ở trên, nhánh tỏa xuống dưới',
      ),
    ];
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kiểu sơ đồ'),
        children: [
          for (final o in options)
            RadioListTile<String>(
              value: o.$1,
              groupValue: widget.document.layout,
              title: Text(o.$2),
              subtitle: Text(o.$3),
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (picked == null || picked == widget.document.layout) return;
    setState(() => widget.document.layout = picked);
    await _persist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitView(_layout());
    });
  }

  void _onMenu(String v) {
    switch (v) {
      case 'expand':
        _setAllCollapsed(false);
        break;
      case 'collapse':
        _setAllCollapsed(true);
        break;
      case 'reset':
        _resetLayout();
        break;
      case 'rename':
        _editNode(_root);
        break;
    }
  }

  // ---------------- phóng to / thu nhỏ ----------------

  void _zoomBy(double factor) {
    if (_viewSize == Size.zero) return;
    final next = _scale * factor;
    if (next < 0.2 || next > 3) return;
    final focal = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final q = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(factor)
      ..translate(-focal.dx, -focal.dy);
    _tc.value = q * _tc.value;
  }

  void _fitView(Map<String, _NodeGeom> geoms) {
    if (_viewSize == Size.zero || geoms.isEmpty) return;
    var bounds = geoms.values.first.rect;
    for (final g in geoms.values) {
      bounds = bounds.expandToInclude(g.rect);
    }
    bounds = bounds.inflate(70);
    final s = math
        .min(_viewSize.width / bounds.width, _viewSize.height / bounds.height)
        .clamp(0.2, 1.15)
        .toDouble();
    _tc.value = Matrix4.identity()
      ..translate(_viewSize.width / 2, _viewSize.height / 2)
      ..scale(s)
      ..translate(-bounds.center.dx, -bounds.center.dy);
  }

  // ---------------- widget nút + thanh công cụ ----------------

  Widget _collapseBadge(_NodeGeom g, Color fg) {
    final node = g.node;
    final hidden = node.totalCount - 1;
    return GestureDetector(
      onTap: () => _toggleCollapse(node),
      child: Container(
        constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fg.withAlpha(38),
          borderRadius: BorderRadius.circular(11),
        ),
        child: node.collapsed
            ? Text('+$hidden',
                style: TextStyle(
                    color: fg, fontSize: 10.5, fontWeight: FontWeight.w800))
            : Icon(Icons.remove, size: 13, color: fg),
      ),
    );
  }

  Widget _nodeWidget(_NodeGeom g) {
    final node = g.node;
    final selected = _selectedId == node.id;
    final fg = _mmTextOn(g.color);
    return GestureDetector(
      onTap: () => setState(() => _selectedId = node.id),
      onDoubleTap: () => _editNode(node),
      onPanStart: (_) {
        _pushHistory();
        if (_selectedId != node.id) setState(() => _selectedId = node.id);
      },
      onPanUpdate: (d) => setState(() {
        node.dx += d.delta.dx / _scale;
        node.dy += d.delta.dy / _scale;
      }),
      onPanEnd: (_) => _persist(),
      child: Container(
        decoration: BoxDecoration(
          color: g.color,
          borderRadius: BorderRadius.circular(g.depth == 0 ? 26 : 19),
          border: Border.all(
            color: selected ? Colors.white : Colors.black.withAlpha(26),
            width: selected ? 2.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? g.color.withAlpha(130)
                  : const Color(0x22000000),
              blurRadius: selected ? 16 : 6,
              spreadRadius: selected ? 2 : 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Text(
                  node.title,
                  style: _styleFor(g.depth).copyWith(color: fg),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (node.children.isNotEmpty)
              Positioned(
                right: 3,
                top: 0,
                bottom: 0,
                child: Center(child: _collapseBadge(g, fg)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(IconData icon, String label, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: enabled ? cs.primary : cs.onSurface.withAlpha(90)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? cs.onSurface
                        : cs.onSurface.withAlpha(90))),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(MindMapNode node) {
    final cs = Theme.of(context).colorScheme;
    final isRoot = node.id == _root.id;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 12)
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _barBtn(Icons.add_circle_outline, 'Nhánh con',
                () => _addChild(node)),
            _barBtn(Icons.playlist_add, 'Nhánh ngang',
                isRoot ? null : () => _addSibling(node)),
            _barBtn(Icons.edit_outlined, 'Sửa', () => _editNode(node)),
            _barBtn(Icons.palette_outlined, 'Màu', () => _pickColor(node)),
            if (node.children.isNotEmpty)
              _barBtn(
                  node.collapsed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  node.collapsed ? 'Hiện con' : 'Thu gọn',
                  () => _toggleCollapse(node)),
            _barBtn(Icons.delete_outline, 'Xóa',
                isRoot ? null : () => _deleteNode(node)),
          ],
        ),
      ),
    );
  }

  Widget _zoomControls() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Thu nhỏ',
            visualDensity: VisualDensity.compact,
            onPressed: () => _zoomBy(0.8),
            icon: const Icon(Icons.remove),
          ),
          Text('${(_scale * 100).round()}%',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          IconButton(
            tooltip: 'Phóng to',
            visualDensity: VisualDensity.compact,
            onPressed: () => _zoomBy(1.25),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Vừa khung hình',
            visualDensity: VisualDensity.compact,
            onPressed: () => _fitView(_layout()),
            icon: const Icon(Icons.fit_screen_outlined),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final geoms = _layout();
    final vertical = widget.document.layout == 'vertical';
    final links = <({
      Rect parent,
      Rect child,
      Color color,
      double width,
      int side,
      bool vertical,
    })>[];
    for (final g in geoms.values) {
      if (g.parentId == null) continue;
      final p = geoms[g.parentId]!;
      links.add((
        parent: p.rect,
        child: g.rect,
        color: g.color,
        width: g.depth == 1 ? 3.4 : 2.4,
        side: g.side,
        vertical: vertical,
      ));
    }
    final selected = _selectedId == null ? null : _find(_selectedId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Hoàn tác',
            onPressed: _undoStack.isEmpty ? null : _doUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Làm lại',
            onPressed: _redoStack.isEmpty ? null : _doRedo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Kiểu sơ đồ',
            onPressed: _pickLayout,
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            tooltip: 'Thêm nữa',
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'expand', child: Text('Mở rộng tất cả')),
              PopupMenuItem(value: 'collapse', child: Text('Thu gọn tất cả')),
              PopupMenuItem(
                  value: 'reset', child: Text('Sắp xếp lại tự động')),
              PopupMenuItem(
                  value: 'rename', child: Text('Đổi chủ đề trung tâm')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addChild(_root),
        icon: const Icon(Icons.add),
        label: const Text('Thêm nhánh'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, cons) {
                _viewSize = cons.biggest;
                if (!_initView) {
                  _initView = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _fitView(_layout());
                  });
                }
                return InteractiveViewer(
                  transformationController: _tc,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(2400),
                  constrained: false,
                  child: SizedBox(
                    width: _canvas,
                    height: _canvas,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                setState(() => _selectedId = null),
                            child: CustomPaint(
                                painter: _DotsPainter(cs.outlineVariant)),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _LinksPainter(links)),
                        ),
                        for (final g in geoms.values)
                          Positioned.fromRect(
                              rect: g.rect, child: _nodeWidget(g)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Chạm vào nút để sửa • Kéo nút để di chuyển • Kéo nền hoặc chụm để phóng to / thu nhỏ',
                    style: TextStyle(fontSize: 11.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 12, bottom: 12, child: _zoomControls()),
          if (selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 66,
              child: Center(child: _actionBar(selected)),
            ),
        ],
      ),
    );
  }
}

class _LinksPainter extends CustomPainter {
  _LinksPainter(this.links);

  final List<({
    Rect parent,
    Rect child,
    Color color,
    double width,
    int side,
    bool vertical,
  })> links;

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in links) {
      if (l.vertical) {
        final start = l.parent.bottomCenter;
        final end = l.child.topCenter;
        final midY = (start.dy + end.dy) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
        canvas.drawPath(
          path,
          Paint()
            ..color = l.color.withAlpha(190)
            ..style = PaintingStyle.stroke
            ..strokeWidth = l.width
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final start = l.side >= 0 ? l.parent.centerRight : l.parent.centerLeft;
      final end = l.side >= 0 ? l.child.centerLeft : l.child.centerRight;
      final dx = (end.dx - start.dx).abs() * 0.5 + 12;
      final dir = l.side >= 0 ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + dir * dx, start.dy, end.dx - dir * dx, end.dy,
            end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = l.color.withAlpha(190)
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinksPainter oldDelegate) => true;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withAlpha(70);
    const step = 30.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => false;
}
