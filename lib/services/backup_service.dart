import 'dart:convert';
import '../data/models.dart';

typedef BackupData = ({
  List<Event> events,
  List<Txn> txns,
  List<Budget> budgets,
  List<Bill> bills,
  List<Goal> goals,
  List<Note> notes,
});

class BackupService {
  static const int version = 2;

  static String build({
    required List<Event> events,
    required List<Txn> txns,
    List<Budget> budgets = const [],
    List<Bill> bills = const [],
    List<Goal> goals = const [],
    List<Note> notes = const [],
  }) => jsonEncode({
    'app': 'LifeSync',
    'version': version,
    'exported_at': DateTime.now().toIso8601String(),
    'events': events.map((e) => e.toMap()).toList(),
    'transactions': txns.map((t) => t.toMap()).toList(),
    'budgets': budgets.map((e) => e.toMap()).toList(),
    'recurring_bills': bills.map((e) => e.toMap()).toList(),
    'goals': goals.map((e) => e.toMap()).toList(),
    'notes': notes.map((e) => e.toMap()).toList(),
  });

  static List<T> _list<T>(Object? raw, T Function(Map<String, Object?>) conv) {
    if (raw == null) return <T>[];
    if (raw is! List) throw const FormatException('list');
    return raw.map((e) {
      if (e is! Map) throw const FormatException('item');
      return conv(e.cast<String, Object?>());
    }).toList();
  }

  /// Ném FormatException nếu tệp không hợp lệ. Chấp nhận phiên bản 1 và 2.
  static BackupData parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || (j['version'] != 1 && j['version'] != 2)) {
        throw const FormatException('version');
      }
      if (j['events'] is! List || j['transactions'] is! List) {
        throw const FormatException('missing');
      }
      final events = _list<Event>(j['events'], (m) {
        if (m['title'] is! String || m['start_ms'] is! int) {
          throw const FormatException('event');
        }
        return Event.fromMap(m);
      });
      final txns = _list<Txn>(j['transactions'], (m) {
        if ((m['type'] != 'income' && m['type'] != 'expense') ||
            m['amount'] is! int ||
            (m['amount'] as int) <= 0 ||
            m['date_ms'] is! int) {
          throw const FormatException('txn');
        }
        return Txn.fromMap(m);
      });
      final budgets = _list<Budget>(j['budgets'], (m) {
        if (m['ym'] is! String || m['limit_amount'] is! int || (m['limit_amount'] as int) <= 0) {
          throw const FormatException('budget');
        }
        return Budget.fromMap(m);
      });
      final bills = _list<Bill>(j['recurring_bills'], (m) {
        final dd = m['due_day'];
        if (m['name'] is! String ||
            m['amount'] is! int ||
            (m['amount'] as int) <= 0 ||
            dd is! int ||
            dd < 1 ||
            dd > 31 ||
            m['next_due_ms'] is! int) {
          throw const FormatException('bill');
        }
        return Bill.fromMap(m);
      });
      final goals = _list<Goal>(j['goals'], (m) {
        if (m['name'] is! String ||
            m['target'] is! int ||
            (m['target'] as int) <= 0 ||
            (m['saved'] != null && (m['saved'] is! int || (m['saved'] as int) < 0))) {
          throw const FormatException('goal');
        }
        return Goal.fromMap(m);
      });
      final notes = _list<Note>(j['notes'], (m) {
        if (m['title'] is! String ||
            (m['content'] != null && m['content'] is! String) ||
            (m['updated_ms'] != null && m['updated_ms'] is! int)) {
          throw const FormatException('note');
        }
        return Note.fromMap(m);
      });
      return (
        events: events,
        txns: txns,
        budgets: budgets,
        bills: bills,
        goals: goals,
        notes: notes,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('corrupt');
    }
  }
}
