import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Flashcards học tiếng Anh kiểu Quizlet:
// - Bộ thẻ: tạo nhiều bộ, mỗi bộ nhiều thẻ (từ tiếng Anh — nghĩa tiếng Việt —
//   ví dụ). Lần mở đầu tiên có sẵn một bộ mẫu 20 từ để thử ngay.
// - Học: lật thẻ (chạm để lật), đánh dấu "Đã nhớ / Chưa nhớ", xáo trộn,
//   chỉ học thẻ chưa nhớ, thanh tiến độ.
// - Trắc nghiệm: mỗi câu 4 lựa chọn nghĩa (đáp án đúng + 3 đáp án nhiễu lấy
//   từ chính bộ thẻ), chấm điểm ngay, xem lại các câu sai, làm lại câu sai.
// Dữ liệu lưu ở SharedPreferences (cùng cách với sơ đồ tư duy) và được đưa
// lên Google Drive chung với bản sao lưu của app (xem DriveService).
// ---------------------------------------------------------------------------

const String kFlashcardsPrefsKey = 'lifesync_flashcards_v1';
const String _seededKey = 'flashcards_seeded';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

class Flashcard {
  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.example = '',
    this.known = false,
  });

  final String id;
  String front; // Từ tiếng Anh
  String back; // Nghĩa tiếng Việt
  String example;
  bool known;

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'example': example,
        'known': known,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: (json['id'] ?? _newId()).toString(),
        front: (json['front'] ?? '').toString(),
        back: (json['back'] ?? '').toString(),
        example: (json['example'] ?? '').toString(),
        known: json['known'] == true,
      );
}

class FlashDeck {
  FlashDeck({required this.id, required this.title, List<Flashcard>? cards})
      : cards = cards ?? <Flashcard>[];

  final String id;
  String title;
  final List<Flashcard> cards;

  int get knownCount => cards.where((c) => c.known).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory FlashDeck.fromJson(Map<String, dynamic> json) => FlashDeck(
        id: (json['id'] ?? _newId()).toString(),
        title: (json['title'] ?? 'Bộ thẻ').toString(),
        cards: (json['cards'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );
}

class _FlashStore {
  static Future<List<FlashDeck>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(kFlashcardsPrefsKey);
    if (raw == null || raw.isEmpty) return <FlashDeck>[];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((d) => FlashDeck.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    } catch (_) {
      return <FlashDeck>[];
    }
  }

  static Future<void> save(List<FlashDeck> decks) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        kFlashcardsPrefsKey, jsonEncode(decks.map((d) => d.toJson()).toList()));
  }
}

List<FlashDeck> _sampleDecks() {
  const words = <(String, String, String)>[
    ('hello', 'xin chào', 'Hello, how are you?'),
    ('thank you', 'cảm ơn', 'Thank you for your help.'),
    ('please', 'làm ơn', 'Please sit down.'),
    ('sorry', 'xin lỗi', "Sorry, I'm late."),
    ('good morning', 'chào buổi sáng', 'Good morning, everyone!'),
    ('friend', 'bạn bè', 'She is my best friend.'),
    ('family', 'gia đình', 'My family is very big.'),
    ('house', 'ngôi nhà', 'This is my house.'),
    ('water', 'nước', 'I drink water every day.'),
    ('food', 'thức ăn', 'Vietnamese food is delicious.'),
    ('book', 'quyển sách', 'I read a book before bed.'),
    ('school', 'trường học', 'He goes to school by bike.'),
    ('happy', 'vui vẻ', 'I feel happy today.'),
    ('love', 'yêu thương', 'I love my family.'),
    ('time', 'thời gian', 'What time is it now?'),
    ('day', 'ngày', 'Today is a beautiful day.'),
    ('work', 'công việc', 'I work from Monday to Friday.'),
    ('travel', 'du lịch', 'I love to travel by train.'),
    ('beautiful', 'đẹp', 'Da Lat is a beautiful city.'),
    ('important', 'quan trọng', 'Health is important.'),
  ];
  return <FlashDeck>[
    FlashDeck(
      id: _newId(),
      title: '100 từ tiếng Anh cơ bản',
      cards: words
          .map((w) => Flashcard(
              id: _newId(), front: w.$1, back: w.$2, example: w.$3))
          .toList(),
    ),
  ];
}

// ============================ Danh sách bộ thẻ ============================

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<FlashDeck> _decks = <FlashDeck>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var decks = await _FlashStore.load();
    if (decks.isEmpty) {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_seededKey) != true) {
        decks = _sampleDecks();
        await _FlashStore.save(decks);
        await sp.setBool(_seededKey, true);
      }
    }
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _loading = false;
    });
  }

  Future<String?> _askTitle(String title, [String initial = '']) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'Ví dụ: Từ vựng Unit 1', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Lưu')),
        ],
      ),
    );
    c.dispose();
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<void> _createDeck() async {
    final title = await _askTitle('Tạo bộ thẻ', 'Bộ thẻ mới');
    if (title == null) return;
    _decks.add(FlashDeck(id: _newId(), title: title));
    await _FlashStore.save(_decks);
    await _load();
  }

  Future<void> _deleteDeck(FlashDeck deck) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bộ thẻ?'),
        content: Text('Xóa "${deck.title}" cùng ${deck.cards.length} thẻ?'),
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
    _decks.removeWhere((d) => d.id == deck.id);
    await _FlashStore.save(_decks);
    if (mounted) setState(() {});
  }

  Future<void> _openDeck(FlashDeck deck) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _DeckPage(deck: deck, onChanged: _load)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDeck,
        icon: const Icon(Icons.add),
        label: const Text('Tạo bộ thẻ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _decks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_outlined,
                            size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('Học tiếng Anh bằng thẻ ghi nhớ',
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                          'Tạo bộ thẻ, lật thẻ để học và làm trắc nghiệm kiểu Quizlet.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _createDeck,
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo bộ thẻ đầu tiên'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final deck = _decks[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.style_outlined)),
                        title: Text(deck.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${deck.cards.length} thẻ • ${deck.knownCount} đã nhớ'),
                        onTap: () => _openDeck(deck),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Học ngay',
                              onPressed: deck.cards.isEmpty
                                  ? null
                                  : () => _openDeck(deck),
                              icon: const Icon(Icons.play_arrow),
                            ),
                            IconButton(
                              tooltip: 'Xóa bộ thẻ',
                              onPressed: () => _deleteDeck(deck),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================ Chi tiết bộ thẻ ============================

class _DeckPage extends StatefulWidget {
  const _DeckPage({required this.deck, required this.onChanged});

  final FlashDeck deck;
  final Future<void> Function() onChanged;

  @override
  State<_DeckPage> createState() => _DeckPageState();
}

class _DeckPageState extends State<_DeckPage> {
  FlashDeck get _deck => widget.deck;

  Future<void> _persist() async {
    final decks = await _FlashStore.load();
    final i = decks.indexWhere((d) => d.id == _deck.id);
    if (i == -1) {
      decks.add(_deck);
    } else {
      decks[i] = _deck;
    }
    await _FlashStore.save(decks);
    await widget.onChanged();
  }

  Future<String?> _askText(String title, String label,
      [String initial = '']) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(hintText: label, border: const OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Lưu')),
        ],
      ),
    );
    c.dispose();
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<void> _renameDeck() async {
    final title = await _askText('Đổi tên bộ thẻ', 'Tên bộ thẻ', _deck.title);
    if (title == null) return;
    setState(() => _deck.title = title);
    await _persist();
  }

  Future<void> _editCard([Flashcard? card]) async {
    final frontC = TextEditingController(text: card?.front ?? '');
    final backC = TextEditingController(text: card?.back ?? '');
    final exC = TextEditingController(text: card?.example ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(card == null ? 'Thêm thẻ mới' : 'Sửa thẻ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: frontC,
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                    labelText: 'Từ tiếng Anh',
                    hintText: 'Ví dụ: beautiful',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: backC,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nghĩa tiếng Việt',
                    hintText: 'Ví dụ: đẹp',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: exC,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Ví dụ (không bắt buộc)',
                    hintText: 'Ví dụ: Da Lat is a beautiful city.',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu')),
        ],
      ),
    );
    final front = frontC.text.trim();
    final back = backC.text.trim();
    final example = exC.text.trim();
    frontC.dispose();
    backC.dispose();
    exC.dispose();
    if (saved != true || front.isEmpty || back.isEmpty) return;
    setState(() {
      if (card == null) {
        _deck.cards.add(Flashcard(
            id: _newId(), front: front, back: back, example: example));
      } else {
        card.front = front;
        card.back = back;
        card.example = example;
      }
    });
    await _persist();
  }

  Future<void> _deleteCard(Flashcard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thẻ?'),
        content: Text('Xóa thẻ "${card.front}"?'),
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
    setState(() => _deck.cards.removeWhere((c) => c.id == card.id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _deck.cards.length;
    final known = _deck.knownCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(_deck.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Đổi tên bộ thẻ',
            onPressed: _renameDeck,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCard(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thẻ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: total == 0
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _StudyPage(
                                        deck: _deck, onChanged: _persist),
                                  ),
                                ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Học'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: total < 2
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _QuizPage(deck: _deck),
                                  ),
                                ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('Trắc nghiệm'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : known / total,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$known/$total đã nhớ',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: total == 0
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Bộ thẻ chưa có thẻ nào. Bấm "Thêm thẻ" để bắt đầu.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: total,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final card = _deck.cards[index];
                      return Card(
                        child: ListTile(
                          title: Text(card.front,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            card.example.isEmpty
                                ? card.back
                                : '${card.back} • ${card.example}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _editCard(card),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: card.known
                                    ? 'Đã nhớ — bấm để đánh dấu chưa nhớ'
                                    : 'Đánh dấu đã nhớ',
                                onPressed: () async {
                                  setState(() => card.known = !card.known);
                                  await _persist();
                                },
                                icon: Icon(
                                  card.known
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: card.known ? Colors.green : null,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Xóa thẻ',
                                onPressed: () => _deleteCard(card),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================ Học: lật thẻ ============================

class _StudyPage extends StatefulWidget {
  const _StudyPage({required this.deck, required this.onChanged});

  final FlashDeck deck;
  final Future<void> Function() onChanged;

  @override
  State<_StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<_StudyPage> {
  List<Flashcard> _order = <Flashcard>[];
  int _index = 0;
  bool _flipped = false;
  bool _shuffle = false;
  bool _onlyUnknown = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _rebuildOrder();
  }

  void _rebuildOrder() {
    var pool = _onlyUnknown
        ? widget.deck.cards.where((c) => !c.known).toList()
        : widget.deck.cards.toList();
    if (_shuffle) pool.shuffle();
    setState(() {
      _order = pool;
      _index = 0;
      _flipped = false;
      _done = pool.isEmpty;
    });
  }

  Flashcard get _current => _order[_index];

  int get _knownTotal => widget.deck.cards.where((c) => c.known).length;

  Future<void> _mark(bool known) async {
    _current.known = known;
    await widget.onChanged();
    if (!mounted) return;
    setState(() {
      if (_index + 1 >= _order.length) {
        _done = true;
      } else {
        _index++;
        _flipped = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.deck.cards.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Học: ${widget.deck.title}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Xáo trộn',
            onPressed: () {
              _shuffle = !_shuffle;
              _rebuildOrder();
            },
            icon: Icon(Icons.shuffle,
                color: _shuffle ? cs.primary : null),
          ),
          IconButton(
            tooltip: 'Chỉ học thẻ chưa nhớ',
            onPressed: () {
              _onlyUnknown = !_onlyUnknown;
              _rebuildOrder();
            },
            icon: Icon(Icons.filter_alt_outlined,
                color: _onlyUnknown ? cs.primary : null),
          ),
        ],
      ),
      body: _order.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _onlyUnknown
                          ? 'Bạn đã nhớ hết các thẻ trong bộ này!'
                          : 'Bộ thẻ chưa có thẻ nào.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_onlyUnknown)
                      FilledButton(
                        onPressed: () {
                          _onlyUnknown = false;
                          _rebuildOrder();
                        },
                        child: const Text('Học tất cả các thẻ'),
                      ),
                  ],
                ),
              ),
            )
          : _done
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text('Hoàn thành!',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          'Đã nhớ $_knownTotal/$total thẻ trong bộ này.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            _onlyUnknown = false;
                            _rebuildOrder();
                          },
                          icon: const Icon(Icons.replay),
                          label: const Text('Học lại từ đầu'),
                        ),
                        const SizedBox(height: 10),
                        if (widget.deck.cards.any((c) => !c.known))
                          OutlinedButton(
                            onPressed: () {
                              _onlyUnknown = true;
                              _rebuildOrder();
                            },
                            child: const Text('Chỉ học thẻ chưa nhớ'),
                          ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Quay lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (_index + 1) / _order.length,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${_index + 1}/${_order.length}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Đã nhớ $_knownTotal/$total thẻ',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _flipped = !_flipped),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                  scale: anim, child: child),
                            ),
                            child: Container(
                              key: ValueKey<bool>(_flipped),
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _flipped
                                    ? cs.secondaryContainer
                                    : cs.primaryContainer,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _flipped ? 'Nghĩa' : 'Từ tiếng Anh',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _flipped
                                        ? _current.back
                                        : _current.front,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_flipped &&
                                      _current.example.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _current.example,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontStyle: FontStyle.italic),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  Text(
                                    _flipped
                                        ? 'Chạm để xem lại từ'
                                        : 'Chạm để lật thẻ',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Thẻ trước',
                            onPressed: _index == 0
                                ? null
                                : () => setState(() {
                                      _index--;
                                      _flipped = false;
                                    }),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _mark(false),
                              icon: const Icon(Icons.close),
                              label: const Text('Chưa nhớ'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _mark(true),
                              icon: const Icon(Icons.check),
                              label: const Text('Đã nhớ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ============================ Trắc nghiệm kiểu Quizlet ============================

class _QuizPage extends StatefulWidget {
  const _QuizPage({required this.deck});

  final FlashDeck deck;

  @override
  State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  List<Flashcard> _questions = <Flashcard>[];
  List<List<String>> _options = <List<String>>[];
  int _index = 0;
  int _selected = -1;
  int _score = 0;
  List<Flashcard> _wrong = <Flashcard>[];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _setup(widget.deck.cards.toList()..shuffle());
  }

  void _setup(List<Flashcard> questions) {
    final options = <List<String>>[];
    for (final q in questions) {
      final distractors = widget.deck.cards
          .where((c) => c.id != q.id && c.back != q.back)
          .map((c) => c.back)
          .toList()
        ..shuffle();
      final opts = <String>{q.back, ...distractors.take(3)}.toList()
        ..shuffle();
      options.add(opts);
    }
    setState(() {
      _questions = questions;
      _options = options;
      _index = 0;
      _selected = -1;
      _score = 0;
      _wrong = <Flashcard>[];
      _done = false;
    });
  }

  Flashcard get _q => _questions[_index];

  void _answer(int i) {
    if (_selected != -1) return;
    final correct = _options[_index][i] == _q.back;
    setState(() {
      _selected = i;
      if (correct) {
        _score++;
      } else {
        _wrong.add(_q);
      }
    });
  }

  void _next() {
    setState(() {
      if (_index + 1 >= _questions.length) {
        _done = true;
      } else {
        _index++;
        _selected = -1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Trắc nghiệm: ${widget.deck.title}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _done
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_score/${_questions.length}',
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      _wrong.isEmpty
                          ? 'Xuất sắc! Bạn nhớ hết các từ.'
                          : 'Còn ${_wrong.length} câu sai — xem lại bên dưới.',
                      textAlign: TextAlign.center,
                    ),
                    if (_wrong.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Column(
                            children: _wrong
                                .map((c) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(c.front,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                          const Text(' → '),
                                          Expanded(
                                              child: Text(c.back)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          _setup(widget.deck.cards.toList()..shuffle()),
                      icon: const Icon(Icons.replay),
                      label: const Text('Làm lại'),
                    ),
                    const SizedBox(height: 10),
                    if (_wrong.isNotEmpty)
                      OutlinedButton(
                        onPressed: () => _setup(_wrong.toList()..shuffle()),
                        child: const Text('Làm lại các câu sai'),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_index + 1) / _questions.length,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                          'Câu ${_index + 1}/${_questions.length} • Điểm $_score'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('Từ này nghĩa là gì?'),
                        const SizedBox(height: 10),
                        Text(
                          _q.front,
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _options[_index].length; i++)
                    _optionButton(i),
                  const Spacer(),
                  if (_selected != -1)
                    FilledButton(
                      onPressed: _next,
                      child: Text(_index + 1 >= _questions.length
                          ? 'Xem kết quả'
                          : 'Câu tiếp theo'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _optionButton(int i) {
    final cs = Theme.of(context).colorScheme;
    final answered = _selected != -1;
    final text = _options[_index][i];
    final isCorrect = text == _q.back;
    final isSelected = _selected == i;
    Color? bg;
    Color? border;
    if (answered && isCorrect) {
      bg = Colors.green.withAlpha(60);
      border = Colors.green;
    } else if (answered && isSelected) {
      bg = Colors.red.withAlpha(60);
      border = Colors.red;
    } else if (isSelected) {
      border = cs.primary;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: answered ? null : () => _answer(i),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg ?? cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: border ?? cs.outlineVariant, width: isSelected ? 2 : 1),
          ),
          child: Row(
            children: [
              Text('${String.fromCharCode(65 + i)}. ',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
              if (answered && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
