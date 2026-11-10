import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Thi thử kiểu đề thi thật (khác với Trắc nghiệm của Flashcards):
// - Chọn thời gian làm bài (mặc định theo đề, ví dụ 50 phút; có thể đổi
//   thành 15 / 30 / 45 / 60 phút hoặc tự nhập số phút).
// - Đồng hồ đếm ngược trên màn hình; hết giờ thì tự động nộp bài.
// - Làm câu nào cũng được, quay lại sửa đáp án thoải mái, có bảng 40 ô
//   để nhảy tới câu bất kỳ và xem câu nào chưa làm.
// - Nộp bài xong hiện điểm, thời gian đã dùng, từng câu đúng/sai, đáp án
//   đúng và giải thích bằng tiếng Việt cho từng câu.
// Đề thi lưu ở SharedPreferences (khóa lifesync_exams_v1). Đề mẫu
// "Đề thi thử THPT 2026 – Mã 1101" được chép từ ảnh đề thi của người dùng
// vào assets/exams/de_thi_1101.txt và nạp sẵn lần đầu mở Thi thử.
// Đề khác nhập bằng file .txt hoặc dán văn bản theo đúng định dạng ghi
// ở đầu file de_thi_1101.txt (dòng Q|...|...|đáp án|giải thích).
// ---------------------------------------------------------------------------

const String kExamsPrefsKey = 'lifesync_exams_v1';
const String _examsSeededKey = 'exams_seeded';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

class ExamQuestion {
  ExamQuestion({
    required this.id,
    required this.number,
    required this.passage,
    required this.question,
    required this.options,
    required this.answer,
    required this.explain,
  });

  final String id;
  final int number;
  final String passage; // Đoạn văn/tờ rơi/quảng cáo của câu ('' nếu không có)
  final String question;
  final List<String> options; // 4 phương án, theo thứ tự A-D
  final int answer; // 0-3
  final String explain; // Giải thích bằng tiếng Việt

  String get answerLetter => 'ABCD'[answer];

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'passage': passage,
        'question': question,
        'options': options,
        'answer': answer,
        'explain': explain,
      };

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
        id: (json['id'] ?? _newId()).toString(),
        number: (json['number'] as num?)?.toInt() ?? 0,
        passage: (json['passage'] ?? '').toString(),
        question: (json['question'] ?? '').toString(),
        options: (json['options'] as List? ?? const [])
            .map((o) => o.toString())
            .toList(),
        answer: (json['answer'] as num?)?.toInt() ?? 0,
        explain: (json['explain'] ?? '').toString(),
      );
}

class ExamPaper {
  ExamPaper({required this.id, required this.title, required this.minutes, required this.questions});

  final String id;
  final String title;
  final int minutes; // Thời gian mặc định của đề (phút)
  final List<ExamQuestion> questions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'minutes': minutes,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory ExamPaper.fromJson(Map<String, dynamic> json) => ExamPaper(
        id: (json['id'] ?? _newId()).toString(),
        title: (json['title'] ?? 'Đề thi').toString(),
        minutes: (json['minutes'] as num?)?.toInt() ?? 50,
        questions: (json['questions'] as List? ?? const [])
            .whereType<Map>()
            .map((q) => ExamQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList(),
      );
}

/// Đọc một đề thi từ văn bản theo định dạng ghi ở đầu de_thi_1101.txt.
/// Trả về null nếu không có câu hỏi nào đọc được.
ExamPaper? parseExamText(String text) {
  var title = 'Đề thi';
  var minutes = 50;
  final passages = <String, String>{};
  final questions = <ExamQuestion>[];
  String? currentPassageId;
  final passageBuf = StringBuffer();

  void flushPassage() {
    if (currentPassageId != null) {
      passages[currentPassageId!] = passageBuf.toString().trim();
    }
    currentPassageId = null;
    passageBuf.clear();
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trimRight();
    if (line.startsWith('#ĐỀ:')) {
      title = line.substring(4).trim();
      continue;
    }
    if (line.startsWith('#PHÚT:')) {
      minutes = int.tryParse(line.substring(6).trim()) ?? 50;
      continue;
    }
    if (line.startsWith('#')) continue;
    if (line.startsWith('[ĐOẠN ')) {
      flushPassage();
      currentPassageId = line
          .substring(6)
          .replaceAll(']', '')
          .trim();
      continue;
    }
    if (line == '[/ĐOẠN]') {
      flushPassage();
      continue;
    }
    if (currentPassageId != null) {
      passageBuf.writeln(line);
      continue;
    }
    if (!line.startsWith('Q|')) continue;
    // Q|số|đoạn|câu hỏi|A|B|C|D|đáp án|giải thích = 10 cột.
    final parts = line.split('|');
    if (parts.length < 10) continue;
    final number = int.tryParse(parts[1].trim()) ?? questions.length + 1;
    final passageId = parts[2].trim();
    final answerLetter = parts[8].trim().toUpperCase();
    final answer = 'ABCD'.indexOf(answerLetter);
    if (answer < 0) continue;
    questions.add(ExamQuestion(
      id: _newId(),
      number: number,
      passage: passageId.isEmpty ? '' : (passages[passageId] ?? ''),
      question: parts[3].trim().replaceAll(r'\n', '\n'),
      options: parts.sublist(4, 8).map((o) => o.trim()).toList(),
      answer: answer,
      explain: parts.sublist(9).join('|').trim(),
    ));
  }
  flushPassage();
  if (questions.isEmpty) return null;
  questions.sort((a, b) => a.number.compareTo(b.number));
  return ExamPaper(id: _newId(), title: title, minutes: minutes, questions: questions);
}

class _ExamStore {
  static Future<List<ExamPaper>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(kExamsPrefsKey);
    if (raw == null || raw.isEmpty) return <ExamPaper>[];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((d) => ExamPaper.fromJson(Map<String, dynamic>.from(d)))
          .toList();
    } catch (_) {
      return <ExamPaper>[];
    }
  }

  static Future<void> save(List<ExamPaper> papers) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        kExamsPrefsKey, jsonEncode(papers.map((p) => p.toJson()).toList()));
  }
}

String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

// ============================ Danh sách đề thi ============================

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  List<ExamPaper> _papers = <ExamPaper>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var papers = await _ExamStore.load();
    if (papers.isEmpty) {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_examsSeededKey) != true) {
        try {
          final text =
              await rootBundle.loadString('assets/exams/de_thi_1101.txt');
          final seeded = parseExamText(text);
          if (seeded != null) papers = <ExamPaper>[seeded];
        } catch (_) {
          // Không có file đề mẫu thì danh sách cứ để trống.
        }
        await _ExamStore.save(papers);
        await sp.setBool(_examsSeededKey, true);
      }
    }
    if (!mounted) return;
    setState(() {
      _papers = papers;
      _loading = false;
    });
  }

  Future<void> _addPaper(ExamPaper paper) async {
    _papers.removeWhere((p) => p.title == paper.title);
    _papers.add(paper);
    await _ExamStore.save(_papers);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Đã thêm "${paper.title}" (${paper.questions.length} câu).')));
    }
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }
    final text =
        utf8.decode(result.files.first.bytes!, allowMalformed: true);
    final paper = parseExamText(text);
    if (paper == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Không đọc được đề từ file này. File phải có các dòng Q|...|...|đáp án|giải thích như file mẫu.')));
      }
      return;
    }
    await _addPaper(paper);
  }

  Future<void> _importFromText() async {
    final textC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập đề từ văn bản'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Dán nội dung đề theo định dạng file mẫu (dòng #ĐỀ:, #PHÚT:, [ĐOẠN ...], Q|số|đoạn|câu hỏi|A|B|C|D|đáp án|giải thích).'),
              const SizedBox(height: 10),
              TextField(
                controller: textC,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                    hintText: '#ĐỀ: Đề của tôi\n#PHÚT: 45\nQ|1||...',
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
              child: const Text('Nhập đề')),
        ],
      ),
    );
    final text = textC.text;
    textC.dispose();
    if (ok != true || text.trim().isEmpty) return;
    final paper = parseExamText(text);
    if (paper == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không đọc được đề từ văn bản này.')));
      }
      return;
    }
    await _addPaper(paper);
  }

  Future<void> _deletePaper(ExamPaper paper) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa đề thi?'),
        content: Text('Xóa "${paper.title}" (${paper.questions.length} câu)?'),
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
    _papers.removeWhere((p) => p.id == paper.id);
    await _ExamStore.save(_papers);
    if (mounted) setState(() {});
  }

  Future<void> _startPaper(ExamPaper paper) async {
    var minutes = paper.minutes;
    final customC = TextEditingController(text: minutes.toString());
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(paper.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${paper.questions.length} câu hỏi. Đề thi thật là ${paper.minutes} phút — bạn có thể đổi thời gian dưới đây.'),
              const SizedBox(height: 14),
              const Text('Thời gian làm bài',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 50, 60]
                    .map((m) => ChoiceChip(
                          label: Text('$m phút'),
                          selected: minutes == m,
                          onSelected: (_) {
                            setD(() {
                              minutes = m;
                              customC.text = m.toString();
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Hoặc tự nhập số phút (5–180)',
                    border: OutlineInputBorder()),
                onChanged: (v) {
                  final m = int.tryParse(v.trim());
                  if (m != null) minutes = m;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton.icon(
              onPressed: () {
                final m = minutes.clamp(5, 180).toInt();
                Navigator.pop(context, m);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu thi'),
            ),
          ],
        ),
      ),
    );
    customC.dispose();
    if (chosen == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _ExamPage(paper: paper, minutes: chosen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thi thử'),
        actions: [
          IconButton(
            tooltip: 'Nhập đề từ file .txt',
            onPressed: _importFromFile,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Nhập đề từ văn bản',
            onPressed: _importFromText,
            icon: const Icon(Icons.edit_note_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _papers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Chưa có đề thi nào.\nBấm nút tải lên để nhập đề từ file .txt.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _papers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final paper = _papers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.assignment_outlined)),
                        title: Text(paper.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${paper.questions.length} câu • ${paper.minutes} phút'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _startPaper(paper),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Thi thử'),
                            ),
                            IconButton(
                              tooltip: 'Xóa đề',
                              onPressed: () => _deletePaper(paper),
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

// ============================ Làm bài thi ============================

class _ExamPage extends StatefulWidget {
  const _ExamPage({required this.paper, required this.minutes});

  final ExamPaper paper;
  final int minutes;

  @override
  State<_ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<_ExamPage> {
  late List<int> _answers; // -1 = chưa làm, 0-3 = đã chọn A-D
  int _index = 0;
  late int _remaining;
  Timer? _timer;
  bool _submitted = false;
  final _notesC = TextEditingController(); // Giấy nháp

  String get _notesKey => 'lifesync_exam_notes_${widget.paper.id}';

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(widget.paper.questions.length, -1);
    _remaining = widget.minutes * 60;
    SharedPreferences.getInstance().then((sp) {
      final saved = sp.getString(_notesKey);
      if (saved != null && mounted) setState(() => _notesC.text = saved);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_submitted) return;
      if (_remaining <= 1) {
        _submit(auto: true);
      } else if (mounted) {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _saveNotes() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_notesKey, _notesC.text);
  }

  Future<void> _openNotes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Text('Giấy nháp',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _notesC.clear()),
                      child: const Text('Xóa hết'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                    'Ghi công thức, từ vựng cần nhớ ở đây. Nháp được lưu theo đề, mở lại vẫn còn.',
                    style: TextStyle(fontSize: 13)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _notesC,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          'Ví dụ:\n- everyone + động từ số ít (works)\n- indolent = lazy\n- công thức...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _saveNotes();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveNotes();
    _notesC.dispose();
    super.dispose();
  }

  ExamQuestion get _q => widget.paper.questions[_index];

  int get _answeredCount => _answers.where((a) => a != -1).length;

  void _submit({bool auto = false}) {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();
    final used = widget.minutes * 60 - _remaining;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _ResultPage(
          paper: widget.paper,
          minutes: widget.minutes,
          answers: _answers,
          secondsUsed: used,
          autoSubmitted: auto,
        ),
      ),
    );
  }

  Future<void> _askSubmit() async {
    final unanswered = _answers.length - _answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài?'),
        content: Text(unanswered == 0
            ? 'Bạn đã làm hết ${_answers.length} câu. Nộp bài để xem điểm và giải thích nhé.'
            : 'Bạn còn $unanswered câu chưa làm. Nộp luôn hay làm tiếp?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Làm tiếp')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Nộp bài')),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _showPalette() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn câu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Ô màu đậm = đã làm (chưa biết đúng hay sai). Chỉ sau khi nộp bài mới hiện đúng/sai.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(widget.paper.questions.length, (i) {
                  final answered = _answers[i] != -1;
                  final current = i == _index;
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: answered
                            ? Theme.of(context).colorScheme.primary
                            : (current
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh),
                        foregroundColor: answered
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                  onPressed: () => Navigator.pop(context, i),
                  child: Text('${widget.paper.questions[i].number}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng')),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _index = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lowTime = _remaining <= 5 * 60;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paper.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Giấy nháp',
            onPressed: _openNotes,
            icon: Icon(_notesC.text.isNotEmpty
                ? Icons.note_alt
                : Icons.note_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    color: lowTime ? Colors.red : null),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_remaining),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: lowTime ? Colors.red : null,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _askSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  child: const Text('NỘP BÀI',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _answeredCount / _answers.length,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Câu ${_index + 1}/${_answers.length} • '
                    'Đã làm $_answeredCount'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                if (_q.passage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_q.passage,
                        style: const TextStyle(fontSize: 15, height: 1.5)),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Câu ${_q.number}. ${_q.question}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chạm vào đáp án khác để đổi ý — đổi được tới khi nộp bài hoặc hết giờ.',
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _q.options.length; i++)
                  _optionButton(i),
                if (_answers[_index] != -1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _answers[_index] = -1),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Bỏ chọn đáp án này'),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _index == 0
                      ? null
                      : () => setState(() => _index--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _showPalette,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('DANH SÁCH CÂU HỎI',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _index + 1 >= _answers.length
                      ? null
                      : () => setState(() => _index++),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.arrow_forward_ios),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionButton(int i) {
    final cs = Theme.of(context).colorScheme;
    final selected = _answers[_index] == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _answers[_index] = i),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
                width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${String.fromCharCode(65 + i)}. ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17)),
              Expanded(
                  child: Text(_q.options[i],
                      style: const TextStyle(fontSize: 17, height: 1.35))),
              if (selected)
                Icon(Icons.check_circle, color: cs.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Kết quả + giải thích ============================

class _ResultPage extends StatelessWidget {
  const _ResultPage({
    required this.paper,
    required this.minutes,
    required this.answers,
    required this.secondsUsed,
    required this.autoSubmitted,
  });

  final ExamPaper paper;
  final int minutes;
  final List<int> answers;
  final int secondsUsed;
  final bool autoSubmitted;

  @override
  Widget build(BuildContext context) {
    var score = 0;
    for (var i = 0; i < paper.questions.length; i++) {
      if (answers[i] == paper.questions[i].answer) score++;
    }
    final total = paper.questions.length;
    final percent = total == 0 ? 0 : (score * 100 / total).round();
    final stars = percent >= 90 ? 3 : (percent >= 70 ? 2 : (percent >= 50 ? 1 : 0));
    final timeText =
        'Thời gian làm bài: ${_formatDuration(secondsUsed)} / ${_formatDuration(minutes * 60)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thi thử')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                Text('⭐' * stars + (stars == 0 ? '💪' : ''),
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('$score/$total',
                    style: const TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w800)),
                Text('$percent% đúng',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(timeText),
                if (autoSubmitted) ...[
                  const SizedBox(height: 4),
                  const Text('Hết giờ — bài đã được nộp tự động.',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _ExamPage(
                                  paper: paper, minutes: minutes)),
                        ),
                        icon: const Icon(Icons.replay),
                        label: const Text('Làm lại'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Về danh sách đề'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Giải thích từng câu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (var i = 0; i < total; i++) _resultTile(context, i, score),
        ],
      ),
    );
  }

  Widget _resultTile(BuildContext context, int i, int score) {
    final q = paper.questions[i];
    final mine = answers[i];
    final correct = mine == q.answer;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : Colors.red,
        ),
        title: Text(
          'Câu ${q.number} — ${correct ? 'Đúng' : 'Sai'}'
          '${mine == -1 ? ' (chưa làm)' : ' • Bạn chọn ${'ABCD'[mine]} • Đáp án ${q.answerLetter}'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (var j = 0; j < q.options.length; j++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          j == q.answer
                              ? Icons.check_circle
                              : (j == mine
                                  ? Icons.cancel
                                  : Icons.radio_button_unchecked),
                          size: 18,
                          color: j == q.answer
                              ? Colors.green
                              : (j == mine ? Colors.red : cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${String.fromCharCode(65 + j)}. ${q.options[j]}',
                            style: TextStyle(
                              fontWeight: j == q.answer
                                  ? FontWeight.w800
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('💡 ${q.explain}',
                      style: const TextStyle(height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
