import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Flashcards học tiếng Anh, nâng cấp theo kiểu Anki (video Quizlet -> Anki):
// Điểm cốt lõi của video: đừng ôn tất cả mọi từ mỗi ngày như Quizlet.
// Hãy để app nhắc lại mỗi thẻ đúng lúc nó sắp quên (Spaced Repetition,
// đường cong lãng quên Ebbinghaus) — thẻ nhớ tốt thì khoảng cách ôn dài
// dần, thẻ quên thì ôn lại ngay. Vì vậy mỗi thẻ giờ có lịch ôn riêng:
// - Học: lật thẻ (chạm để lật), đánh dấu "Đã nhớ / Chưa nhớ", xáo trộn,
//   chỉ học thẻ chưa nhớ, thanh tiến độ (giữ nguyên để xem nhanh cả bộ).
// - Ôn tập (mới, kiểu Anki): chỉ hiện thẻ đến hạn + tối đa 20 thẻ mới
//   mỗi phiên; sau khi lật thẻ, chấm Lại / Khó / Tốt / Dễ, mỗi nút hiện
//   sẵn lần ôn tiếp theo (ví dụ: Lại <10 phút, Tốt 3 ngày, Dễ 7 ngày).
// - Trắc nghiệm: mỗi câu 4 lựa chọn nghĩa (đáp án đúng + 3 đáp án nhiễu lấy
//   từ chính bộ thẻ), chấm điểm ngay, xem lại các câu sai, làm lại câu sai.
// Dữ liệu lưu ở SharedPreferences (cùng cách với sơ đồ tư duy) và được đưa
// lên Google Drive chung với bản sao lưu của app (xem DriveService).
// Thẻ cũ (chưa có trường SRS) vẫn đọc được: thẻ chưa nhớ -> thẻ mới,
// thẻ đã nhớ -> thẻ đang ôn, đến hạn ngay hôm nay.
// ---------------------------------------------------------------------------

const String kFlashcardsPrefsKey = 'lifesync_flashcards_v1';
const String _seededKey = 'flashcards_seeded';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Mức chấm kiểu Anki: 0 = Lại, 1 = Khó, 2 = Tốt, 3 = Dễ.
enum SrsGrade { again, hard, good, easy }

class Flashcard {
  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.example = '',
    this.pron = '',
    this.image = '',
    this.known = false,
    this.dueMs = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
    this.state = 0,
  });

  final String id;
  String front; // Từ tiếng Anh
  String back; // Nghĩa tiếng Việt
  String example;
  String pron; // Phiên âm, ví dụ: /'ɔːrɡənaɪz/ (không bắt buộc)
  String image; // Ảnh minh họa (URL, không bắt buộc — thẻ Anki hay có ảnh)
  bool known;

  // --- Lịch ôn kiểu Anki (Spaced Repetition) ---
  // dueMs = 0: thẻ mới, chưa từng ôn. state: 0 = mới, 1 = đang học
  // (vừa chấm Lại, chờ ôn lại trong phiên), 2 = đang ôn định kỳ.
  // intervalDays: khoảng cách ôn hiện tại (ngày); ease: hệ số dễ (2.5
  // mặc định, tăng khi chấm Dễ, giảm khi chấm Lại/Khó).
  int dueMs;
  int intervalDays;
  double ease;
  int reps;
  int lapses;
  int state;

  bool get isNew => state == 0;

  bool isDue(DateTime now) =>
      dueMs == 0 || dueMs <= now.millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'example': example,
        'pron': pron,
        'image': image,
        'known': known,
        'due': dueMs,
        'interval': intervalDays,
        'ease': ease,
        'reps': reps,
        'lapses': lapses,
        'state': state,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    final known = json['known'] == true;
    // Thẻ cũ không có trường 'due': thẻ đã nhớ -> đang ôn, đến hạn hôm
    // nay (giữ nguyên tiến độ cũ, không bắt học lại từ đầu); thẻ chưa
    // nhớ -> thẻ mới.
    final hasSrs = json.containsKey('due');
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Flashcard(
      id: (json['id'] ?? _newId()).toString(),
      front: (json['front'] ?? '').toString(),
      back: (json['back'] ?? '').toString(),
      example: (json['example'] ?? '').toString(),
      pron: (json['pron'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      known: known,
      dueMs: hasSrs
          ? (json['due'] as num?)?.toInt() ?? 0
          : (known ? nowMs : 0),
      intervalDays: hasSrs
          ? (json['interval'] as num?)?.toInt() ?? 0
          : (known ? 1 : 0),
      ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      state: hasSrs
          ? (json['state'] as num?)?.toInt() ?? 0
          : (known ? 2 : 0),
    );
  }
}

/// Kết quả chấm một thẻ: khoảng cách ôn mới và thời điểm ôn tiếp theo.
class _SrsResult {
  const _SrsResult(this.intervalDays, this.dueMs, this.ease, this.state);

  final int intervalDays;
  final int dueMs;
  final double ease;
  final int state;
}

int _clampDays(int v) => v < 1 ? 1 : (v > 36500 ? 36500 : v);

/// Thuật toán rút gọn kiểu Anki/SM-2, đủ để dùng hằng ngày trên điện thoại:
/// - Thẻ mới (hoặc vừa chấm Lại): Lại = ôn lại sau 10 phút trong phiên,
///   Khó = 1 ngày, Tốt = 3 ngày, Dễ = 7 ngày.
/// - Thẻ đang ôn: Lại = về 10 phút + trừ ease, Khó = khoảng cũ x 1.2,
///   Tốt = khoảng cũ x ease, Dễ = khoảng cũ x ease x 1.3 (và tăng ease).
_SrsResult _gradeCard(Flashcard card, SrsGrade grade, DateTime now) {
  final nowMs = now.millisecondsSinceEpoch;
  var ease = card.ease;
  if (card.intervalDays == 0) {
    switch (grade) {
      case SrsGrade.again:
        return _SrsResult(0, nowMs + 10 * 60 * 1000, ease, 1);
      case SrsGrade.hard:
        return _SrsResult(1, nowMs + 24 * 60 * 60 * 1000, ease, 2);
      case SrsGrade.good:
        return _SrsResult(3, nowMs + 3 * 24 * 60 * 60 * 1000, ease, 2);
      case SrsGrade.easy:
        return _SrsResult(
            7, nowMs + 7 * 24 * 60 * 60 * 1000, ease + 0.15, 2);
    }
  }
  switch (grade) {
    case SrsGrade.again:
      ease = (ease - 0.2).clamp(1.3, 10.0);
      return _SrsResult(0, nowMs + 10 * 60 * 1000, ease, 1);
    case SrsGrade.hard:
      ease = (ease - 0.15).clamp(1.3, 10.0);
      final days = _clampDays((card.intervalDays * 1.2).round());
      return _SrsResult(
          days, nowMs + days * 24 * 60 * 60 * 1000, ease, 2);
    case SrsGrade.good:
      final days = _clampDays((card.intervalDays * ease).round());
      return _SrsResult(
          days, nowMs + days * 24 * 60 * 60 * 1000, ease, 2);
    case SrsGrade.easy:
      ease = ease + 0.15;
      final days = _clampDays((card.intervalDays * ease * 1.3).round());
      return _SrsResult(
          days, nowMs + days * 24 * 60 * 60 * 1000, ease, 2);
  }
}

/// Nhãn khoảng ôn hiển thị trên nút chấm, đúng kiểu Anki
/// ("<10 phút", "1 ngày", "3 ngày", ...): tính trước khi chấm.
String _gradePreview(Flashcard card, SrsGrade grade) {
  final r = _gradeCard(card, grade, DateTime.now());
  if (r.intervalDays == 0) return '10 phút nữa';
  if (r.intervalDays == 1) return '1 ngày';
  return '${r.intervalDays} ngày';
}

/// Áp dụng một lần chấm vào thẻ (lưu ngay qua onChanged của trang gọi).
void _applyGrade(Flashcard card, SrsGrade grade) {
  final r = _gradeCard(card, grade, DateTime.now());
  card.intervalDays = r.intervalDays;
  card.dueMs = r.dueMs;
  card.ease = r.ease;
  card.state = r.state;
  card.reps++;
  if (grade == SrsGrade.again) card.lapses++;
  card.known = grade != SrsGrade.again;
}

/// Nhãn lịch ôn của một thẻ để hiện trong danh sách thẻ.
String _dueLabel(Flashcard card) {
  if (card.isNew) return 'Thẻ mới';
  final now = DateTime.now();
  final due = DateTime.fromMillisecondsSinceEpoch(card.dueMs);
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;
  if (diff < 0) return 'Quá hạn ${-diff} ngày';
  if (diff == 0) return 'Đến hạn hôm nay';
  if (diff == 1) return 'Ôn lại ngày mai';
  return 'Ôn lại sau $diff ngày (${due.day}/${due.month})';
}

class FlashDeck {
  FlashDeck({required this.id, required this.title, List<Flashcard>? cards})
      : cards = cards ?? <Flashcard>[];

  final String id;
  String title;
  final List<Flashcard> cards;

  int get knownCount => cards.where((c) => c.known).length;

  /// Số liệu kiểu Anki hiện ở đầu mỗi bộ thẻ: Mới / Đang học / Đến hạn.
  int get newCount => cards.where((c) => c.state == 0).length;

  int get learnCount => cards.where((c) => c.state == 1).length;

  int dueCount([DateTime? now]) {
    final n = now ?? DateTime.now();
    return cards.where((c) => c.state == 2 && c.isDue(n)).length;
  }

  /// Hàng chờ ôn hôm nay: thẻ đến hạn trước (cũ nhất trước), rồi thẻ mới.
  /// Giới hạn 20 thẻ mới mỗi phiên như Anki mặc định, để mỗi ngày chỉ
  /// nạp một lượng từ vừa sức thay vì ôm cả bộ 100 thẻ một lúc.
  List<Flashcard> reviewQueue([DateTime? now]) {
    final n = now ?? DateTime.now();
    final due = cards.where((c) => !c.isNew && c.isDue(n)).toList()
      ..sort((a, b) => a.dueMs.compareTo(b.dueMs));
    final fresh = cards.where((c) => c.isNew).toList();
    return [...due, ...fresh.take(20)];
  }

  int get pendingNewBeyondSession {
    final q = reviewQueue();
    final inSession = q.where((c) => c.isNew).length;
    return newCount - inSession;
  }

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

// Một thẻ phân tích được từ văn bản nhập (dán danh sách từ vựng).
class _ParsedCard {
  const _ParsedCard(this.front, this.pron, this.back);

  final String front;
  final String pron;
  final String back;
}

/// Phân tích văn bản dán vào thành danh sách thẻ.
///
/// [termSep]: ký tự phân cách giữa từ và nghĩa (Tab, dấu phẩy, ...).
/// [cardSep]: ký tự phân cách giữa các thẻ ('\n' = mỗi thẻ một dòng).
/// Dòng không có dấu phân cách, thiếu từ hoặc thiếu nghĩa sẽ bị bỏ qua.
/// Nếu phần nghĩa bắt đầu bằng phiên âm dạng /.../ thì phiên âm được tách
/// riêng để hiển thị dưới từ ở chế độ Học (đúng kiểu dữ liệu trong video
/// mẫu: "organize\t/'ɔːrɡənaɪz/ tổ chức").
List<_ParsedCard> _parseImport(String text, String termSep, String cardSep) {
  if (termSep.isEmpty || cardSep.isEmpty) return <_ParsedCard>[];
  final chunks = cardSep == '\n' ? text.split('\n') : text.split(cardSep);
  final out = <_ParsedCard>[];
  for (final raw in chunks) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final sepIndex = line.indexOf(termSep);
    if (sepIndex == -1) continue;
    final front = line.substring(0, sepIndex).trim();
    var rest = line.substring(sepIndex + termSep.length).trim();
    if (front.isEmpty || rest.isEmpty) continue;
    var pron = '';
    if (rest.startsWith('/')) {
      final close = rest.indexOf('/', 1);
      if (close > 1) {
        pron = rest.substring(0, close + 1);
        rest = rest.substring(close + 1).trim();
      }
    }
    if (rest.isEmpty) continue;
    out.add(_ParsedCard(front, pron, rest));
  }
  return out;
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
                          'Tạo bộ thẻ, bấm Ôn tập để app nhắc lại mỗi từ đúng lúc sắp quên (kiểu Anki), hoặc lật thẻ và làm trắc nghiệm như trước.',
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
              : Builder(
                  builder: (context) {
                    final totalDue =
                        _decks.fold<int>(0, (s, d) => s + d.dueCount());
                    final totalLearn =
                        _decks.fold<int>(0, (s, d) => s + d.learnCount);
                    final totalNew =
                        _decks.fold<int>(0, (s, d) => s + d.newCount);
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Card(
                            color: theme.colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      totalDue + totalLearn + totalNew == 0
                                          ? 'Hôm nay không còn thẻ nào đến hạn. Tuyệt vời!'
                                          : 'Hôm nay: $totalDue thẻ đến hạn • $totalLearn đang học • $totalNew thẻ mới',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _decks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final deck = _decks[index];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.style_outlined)),
                                  title: Text(deck.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${deck.cards.length} thẻ • Mới ${deck.newCount} • Đang học ${deck.learnCount} • Đến hạn ${deck.dueCount()}'),
                                  onTap: () => _openDeck(deck),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Ôn tập ngay',
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
                        ),
                      ],
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

  /// Đặt lại lịch ôn của cả bộ (kiểu "Forget" của Anki): mọi thẻ về
  /// thẻ mới, xóa khoảng cách ôn và hệ số dễ. Dùng khi muốn học lại
  /// bộ từ đầu; không xóa từ, nghĩa hay ví dụ.
  Future<void> _resetSrs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt lại lịch ôn?'),
        content: const Text(
            'Mọi thẻ trong bộ sẽ trở về thẻ mới và phải ôn lại từ đầu. Từ, nghĩa và ví dụ không bị xóa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đặt lại')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final c in _deck.cards) {
        c.dueMs = 0;
        c.intervalDays = 0;
        c.ease = 2.5;
        c.reps = 0;
        c.lapses = 0;
        c.state = 0;
        c.known = false;
      }
    });
    await _persist();
  }

  Future<void> _editCard([Flashcard? card]) async {
    final frontC = TextEditingController(text: card?.front ?? '');
    final backC = TextEditingController(text: card?.back ?? '');
    final pronC = TextEditingController(text: card?.pron ?? '');
    final exC = TextEditingController(text: card?.example ?? '');
    final imgC = TextEditingController(text: card?.image ?? '');
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
                controller: pronC,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                    labelText: 'Phiên âm (không bắt buộc)',
                    hintText: "Ví dụ: /'bjuːtɪfəl/",
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
              const SizedBox(height: 12),
              TextField(
                controller: imgC,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                    labelText: 'Ảnh minh họa — đường link (không bắt buộc)',
                    hintText: 'Ví dụ: https://…/beautiful.jpg',
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
    final pron = pronC.text.trim();
    final example = exC.text.trim();
    final image = imgC.text.trim();
    frontC.dispose();
    backC.dispose();
    pronC.dispose();
    exC.dispose();
    imgC.dispose();
    if (saved != true || front.isEmpty || back.isEmpty) return;
    setState(() {
      if (card == null) {
        _deck.cards.add(Flashcard(
            id: _newId(),
            front: front,
            back: back,
            pron: pron,
            example: example,
            image: image));
      } else {
        card.front = front;
        card.back = back;
        card.pron = pron;
        card.example = example;
        card.image = image;
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

  /// Nhập nhiều thẻ cùng lúc từ văn bản dán vào, kiểu Import của Quizlet:
  /// chọn dấu phân cách giữa từ và nghĩa, dấu phân cách giữa các thẻ,
  /// xem trước rồi mới nhập. Thẻ trùng từ đã có trong bộ sẽ bị bỏ qua.
  Future<void> _importCards() async {
    final textC = TextEditingController();
    var termChoice = 'tab';
    var termCustom = '';
    var cardChoice = 'newline';
    var cardCustom = '';
    var latest = <_ParsedCard>[];

    String termSep() {
      switch (termChoice) {
        case 'comma':
          return ',';
        case 'colon':
          return ':';
        case 'custom':
          return termCustom;
        default:
          return '\t';
      }
    }

    String cardSep() {
      switch (cardChoice) {
        case 'semicolon':
          return ';';
        case 'custom':
          return cardCustom;
        default:
          return '\n';
      }
    }

    final result = await showDialog<List<_ParsedCard>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) {
          void refresh() {
            final ts = termSep();
            final cs = cardSep();
            setD(() {
              latest = (ts.isEmpty || cs.isEmpty)
                  ? <_ParsedCard>[]
                  : _parseImport(textC.text, ts, cs);
            });
          }

          return AlertDialog(
            title: const Text('Nhập từ văn bản'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dán danh sách từ vựng, mỗi thẻ một dòng, dạng: từ + dấu phân cách + phiên âm + nghĩa.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textC,
                    maxLines: 8,
                    minLines: 4,
                    onChanged: (_) => refresh(),
                    decoration: const InputDecoration(
                      hintText:
                          "organize\t/'ɔːrɡənaɪz/ tổ chức\nannual\t/'æn.ju.əl/ hằng năm",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Từ — nghĩa: '),
                      Expanded(
                        child: DropdownButton<String>(
                          value: termChoice,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'tab', child: Text('Tab')),
                            DropdownMenuItem(
                                value: 'comma', child: Text('Dấu phẩy')),
                            DropdownMenuItem(
                                value: 'colon', child: Text('Dấu hai chấm')),
                            DropdownMenuItem(
                                value: 'custom', child: Text('Tùy chỉnh')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            termChoice = v;
                            refresh();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (termChoice == 'custom')
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Ký tự phân cách',
                          border: OutlineInputBorder()),
                      onChanged: (v) {
                        termCustom = v;
                        refresh();
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Giữa các thẻ: '),
                      Expanded(
                        child: DropdownButton<String>(
                          value: cardChoice,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'newline', child: Text('Xuống dòng')),
                            DropdownMenuItem(
                                value: 'semicolon',
                                child: Text('Dấu chấm phẩy')),
                            DropdownMenuItem(
                                value: 'custom', child: Text('Tùy chỉnh')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            cardChoice = v;
                            refresh();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (cardChoice == 'custom')
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Ký tự phân cách thẻ',
                          border: OutlineInputBorder()),
                      onChanged: (v) {
                        cardCustom = v;
                        refresh();
                      },
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Xem trước: ${latest.length} thẻ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  for (final p in latest.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${p.front}${p.pron.isEmpty ? '' : ' ${p.pron}'} — ${p.back}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (latest.length > 5)
                    Text('… và ${latest.length - 5} thẻ nữa'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: latest.isEmpty
                    ? null
                    : () => Navigator.pop(context, latest),
                child: Text('Nhập ${latest.length} thẻ'),
              ),
            ],
          );
        },
      ),
    );
    textC.dispose();
    if (result == null || result.isEmpty) return;
    final existing = _deck.cards.map((c) => c.front.toLowerCase()).toSet();
    var added = 0;
    setState(() {
      for (final p in result) {
        if (existing.contains(p.front.toLowerCase())) continue;
        existing.add(p.front.toLowerCase());
        _deck.cards.add(Flashcard(
            id: _newId(), front: p.front, pron: p.pron, back: p.back));
        added++;
      }
    });
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added == result.length
              ? 'Đã nhập $added thẻ.'
              : 'Đã nhập $added thẻ (bỏ qua ${result.length - added} thẻ trùng).'),
        ),
      );
    }
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
            tooltip: 'Nhập từ văn bản',
            onPressed: _importCards,
            icon: const Icon(Icons.upload_outlined),
          ),
          IconButton(
            tooltip: 'Đổi tên bộ thẻ',
            onPressed: _renameDeck,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: 'Đặt lại lịch ôn',
            onPressed: _resetSrs,
            icon: const Icon(Icons.restart_alt_outlined),
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
                                    builder: (_) => _ReviewPage(
                                        deck: _deck, onChanged: _persist),
                                  ),
                                ),
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                            'Ôn tập (${_deck.reviewQueue().length})'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: total == 0
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _StudyPage(
                                        deck: _deck, onChanged: _persist),
                                  ),
                                ),
                        icon: const Icon(Icons.style_outlined),
                        label: const Text('Học'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
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
                const SizedBox(height: 10),
                Text(
                  'Mới ${_deck.newCount} • Đang học ${_deck.learnCount} • Đến hạn ${_deck.dueCount()} • $known/$total đã nhớ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                if (_deck.pendingNewBeyondSession > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Còn ${_deck.pendingNewBeyondSession} thẻ mới sẽ vào các phiên sau (mỗi phiên tối đa 20 thẻ mới).',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
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
                                ? '${card.back} • ${_dueLabel(card)}'
                                : '${card.back} • ${card.example} • ${_dueLabel(card)}',
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
                                  if (!_flipped &&
                                      _current.pron.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _current.pron,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          color: cs.onSurfaceVariant),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
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

// ============================ Ôn tập kiểu Anki ============================
// Chỉ ôn thẻ đến hạn + tối đa 20 thẻ mới. Sau khi lật thẻ mới được chấm,
// mỗi nút chấm hiện sẵn lần ôn tiếp theo. Thẻ chấm "Lại" được xếp cuối
// hàng chờ để ôn lại ngay trong phiên (đúng bước học 10 phút của Anki).

class _ReviewPage extends StatefulWidget {
  const _ReviewPage({required this.deck, required this.onChanged});

  final FlashDeck deck;
  final Future<void> Function() onChanged;

  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  List<Flashcard> _queue = <Flashcard>[];
  int _index = 0;
  bool _flipped = false;
  bool _done = false;
  int _reviewed = 0;
  int _againCount = 0;

  @override
  void initState() {
    super.initState();
    _queue = widget.deck.reviewQueue();
  }

  Flashcard get _current => _queue[_index];

  String get _nextDueText {
    final now = DateTime.now().millisecondsSinceEpoch;
    final future = widget.deck.cards
        .where((c) => !c.isNew && c.dueMs > now)
        .toList();
    if (future.isEmpty) return 'Chưa có thẻ nào chờ ôn.';
    future.sort((a, b) => a.dueMs.compareTo(b.dueMs));
    return 'Lần ôn tiếp theo: ${_dueLabel(future.first)}.';
  }

  Future<void> _grade(SrsGrade grade) async {
    final card = _current;
    _applyGrade(card, grade);
    await widget.onChanged();
    if (!mounted) return;
    setState(() {
      _reviewed++;
      if (grade == SrsGrade.again) {
        _againCount++;
        _queue.add(card);
      }
      if (_index + 1 >= _queue.length) {
        _done = true;
      } else {
        _index++;
        _flipped = false;
      }
    });
  }

  Widget _gradeButton(SrsGrade grade, String label, Color color) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        ),
        onPressed: () => _grade(grade),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_gradePreview(_current, grade),
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ôn tập: ${widget.deck.title}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration_outlined, size: 64),
                    const SizedBox(height: 16),
                    const Text('Hôm nay không còn thẻ nào đến hạn!',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(_nextDueText, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
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
                        const Text('Xong phiên ôn!',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Đã chấm $_reviewed lượt'
                            '${_againCount > 0 ? ' (chấm Lại $_againCount lượt)' : ''}.'),
                        const SizedBox(height: 8),
                        Text(_nextDueText, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
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
                              value: _queue.isEmpty
                                  ? 0
                                  : _index / _queue.length,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Thẻ ${_index + 1}/${_queue.length}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _current.isNew
                            ? 'Thẻ mới'
                            : 'Thẻ đến hạn • khoảng ôn hiện tại: ${_current.intervalDays} ngày',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _flipped = !_flipped),
                          child: Container(
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
                            child: SingleChildScrollView(
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
                                  if (!_flipped &&
                                      _current.pron.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _current.pron,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          color: cs.onSurfaceVariant),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  if (_flipped) ...[
                                    if (_current.example.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        _current.example,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontStyle: FontStyle.italic),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                    if (_current.image.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.network(
                                          _current.image,
                                          height: 150,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(height: 24),
                                  Text(
                                    _flipped
                                        ? 'Chấm thật lòng ở dưới nhé'
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
                      if (!_flipped)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _flipped = true),
                            child: const Text('Lật thẻ'),
                          ),
                        )
                      else
                        Row(
                          children: [
                            _gradeButton(
                                SrsGrade.again, 'Lại', Colors.red),
                            const SizedBox(width: 8),
                            _gradeButton(
                                SrsGrade.hard, 'Khó', Colors.orange),
                            const SizedBox(width: 8),
                            _gradeButton(
                                SrsGrade.good, 'Tốt', Colors.green),
                            const SizedBox(width: 8),
                            _gradeButton(
                                SrsGrade.easy, 'Dễ', Colors.blue),
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
