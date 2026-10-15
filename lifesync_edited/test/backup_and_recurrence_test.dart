import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/data/models.dart';
import 'package:lifesync/services/backup_service.dart';

void main() {
  test('Backup v2: export rồi import đủ mọi loại dữ liệu', () {
    final s = BackupService.build(
      events: [Event(id: 1, title: 'A', start: DateTime(2026, 10, 1, 19), end: DateTime(2026, 10, 1, 20), repeat: 4)],
      txns: [Txn(id: 1, isIncome: false, amount: 50000, category: 'Ăn uống', date: DateTime(2026, 10, 1))],
      budgets: [Budget(ym: '2026-10', limit: 5000000, notified: 3)],
      goals: [Goal(id: 1, name: 'Laptop', target: 10000000, saved: 3000000, created: DateTime(2026, 10, 1))],
      notes: [Note(id: 1, title: 'Việc cần làm', content: 'Mua sữa', color: 2, pinned: true, updated: DateTime(2026, 10, 1))],
    );
    final d = BackupService.parse(s);
    expect(d.events.single.title, 'A');
    expect(d.events.single.end, isNotNull);
    expect(d.txns.single.amount, 50000);
    expect(d.budgets.single.notified, 3);
    expect(d.goals.single.saved, 3000000);
    expect(d.notes.single.title, 'Việc cần làm');
    expect(d.notes.single.pinned, true);
  });

  test('Backup v1 cũ vẫn nhập được', () {
    final d = BackupService.parse('{"version":1,"events":[],"transactions":[]}');
    expect(d.budgets, isEmpty);
    expect(d.goals, isEmpty);
    expect(d.notes, isEmpty);
  });

  test('Backup: JSON hỏng / thiếu trường / sai phiên bản / dữ liệu sai', () {
    expect(() => BackupService.parse('không phải json'), throwsFormatException);
    expect(() => BackupService.parse('{"version":2}'), throwsFormatException);
    expect(() => BackupService.parse('{"version":99,"events":[],"transactions":[]}'), throwsFormatException);
    expect(() => BackupService.parse('{"version":2,"events":[{"x":1}],"transactions":[]}'), throwsFormatException);
    expect(
      () => BackupService.parse('{"version":2,"events":[],"transactions":[{"type":"income","amount":-5,"date_ms":1}]}'),
      throwsFormatException,
    );
    expect(
      () => BackupService.parse('{"version":2,"events":[],"transactions":[],"goals":[{"name":"x","target":0}]}'),
      throwsFormatException,
    );
  });

  test('Sự kiện lặp ngày/tuần/tháng/năm', () {
    final start = DateTime(2026, 10, 1, 19); // thứ Năm
    Event e(int rep) => Event(title: 'Học Lý', start: start, repeat: rep);
    expect(e(0).occursOn(DateTime(2026, 10, 2)), false);
    expect(e(1).occursOn(DateTime(2026, 10, 2)), true);
    expect(e(2).occursOn(DateTime(2026, 10, 8)), true);
    expect(e(2).occursOn(DateTime(2026, 10, 9)), false);
    expect(e(3).occursOn(DateTime(2026, 11, 1)), true);
    expect(e(4).occursOn(DateTime(2027, 10, 1)), true);
    expect(e(4).occursOn(DateTime(2027, 11, 1)), false);
    expect(e(1).occursOn(DateTime(2026, 9, 30)), false);
  });
}
