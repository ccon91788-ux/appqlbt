import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/data/models.dart';
import 'package:lifesync/data/repo.dart';
import 'package:lifesync/services/backup_service.dart';
import 'package:lifesync/services/finance_logic.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Các bài test này chạy trên SQLite THẬT (qua sqflite_common_ffi), không giả lập.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    Repo.useDb(await Repo.openAt(inMemoryDatabasePath, factory: databaseFactoryFfi));
  });

  tearDown(() async {
    await Repo.closeForTest();
  });

  test('Giao dịch: tạo, đọc, sửa, xóa', () async {
    final t = Txn(
      isIncome: false,
      amount: 50000,
      category: 'Ăn uống',
      note: 'ăn sáng',
      date: DateTime(2026, 10, 1, 8),
    );
    await Repo.saveTxn(t);
    expect(t.id, isNotNull);

    var all = await Repo.txns();
    expect(all.length, 1);
    expect(all.first.amount, 50000);
    expect(all.first.isIncome, false);
    expect(all.first.note, 'ăn sáng');

    t.amount = 60000;
    t.category = 'Di chuyển';
    await Repo.saveTxn(t);
    all = await Repo.txns();
    expect(all.single.amount, 60000);
    expect(all.single.category, 'Di chuyển');

    await Repo.deleteTxn(t);
    expect(await Repo.txns(), isEmpty);
  });

  test('Sự kiện: tạo, đọc (có giờ kết thúc và lặp), xóa', () async {
    final e = Event(
      title: 'Học Lý',
      description: 'Phòng 3',
      start: DateTime(2026, 10, 1, 19),
      end: DateTime(2026, 10, 1, 20, 30),
      reminderMin: 15,
      repeat: 2,
    );
    await Repo.saveEvent(e);
    final list = await Repo.events();
    expect(list.single.title, 'Học Lý');
    expect(list.single.end, DateTime(2026, 10, 1, 20, 30));
    expect(list.single.repeat, 2);
    expect(list.single.occursOn(DateTime(2026, 10, 8)), true);
    expect(list.single.occursOn(DateTime(2026, 10, 9)), false);
    await Repo.deleteEvent(e);
    expect(await Repo.events(), isEmpty);
  });

  test('Mục tiêu tiết kiệm: thêm, rút, không cho âm', () async {
    final g = Goal(name: 'Laptop', target: 10000000, created: DateTime(2026, 10, 1));
    await Repo.saveGoal(g);
    expect(await Repo.adjustGoal(g, 3000000), true);
    final got = (await Repo.goals()).single;
    expect(got.saved, 3000000);
    expect(goalProgress(got.saved, got.target), closeTo(0.3, 1e-9));

    expect(await Repo.adjustGoal(g, -5000000), false);
    expect((await Repo.goals()).single.saved, 3000000);
    expect(await Repo.adjustGoal(g, -1000000), true);
    expect((await Repo.goals()).single.saved, 2000000);

    await Repo.deleteGoal(g);
    expect(await Repo.goals(), isEmpty);
  });

  test('Ngân sách: cảnh báo 80/90/100% mỗi mức một lần', () async {
    final when = DateTime(2026, 10, 15);
    await Repo.setBudget(when, 1000000);
    var st = await Repo.budgetStatus(when);
    expect(st.budget!.limit, 1000000);
    expect(st.budget!.notified, 0);

    Future<void> spend(int amount, DateTime date) => Repo.saveTxn(
      Txn(isIncome: false, amount: amount, category: 'Mua sắm', date: date),
    );

    await spend(800000, DateTime(2026, 10, 10));
    st = await Repo.budgetStatus(when);
    expect(st.spent, 800000);
    expect(st.budget!.notified, 1); // đã báo 80%

    await spend(100000, DateTime(2026, 10, 11));
    expect((await Repo.budgetStatus(when)).budget!.notified, 3); // thêm 90%

    await spend(10000, DateTime(2026, 10, 12));
    expect((await Repo.budgetStatus(when)).budget!.notified, 3); // không báo lại

    await spend(100000, DateTime(2026, 10, 13));
    expect((await Repo.budgetStatus(when)).budget!.notified, 7); // thêm 100%

    // Thu nhập và chi tiêu tháng khác không tính vào tháng 10
    await Repo.saveTxn(Txn(isIncome: true, amount: 9000000, category: 'Lương', date: DateTime(2026, 10, 14)));
    await spend(5000000, DateTime(2026, 9, 30));
    expect((await Repo.budgetStatus(when)).spent, 1010000);

    // Đổi hạn mức = đặt lại cảnh báo
    await Repo.setBudget(when, 2000000);
    expect((await Repo.budgetStatus(when)).budget!.notified, 0);
  });

  test('Ngân sách: tắt cảnh báo thì không ghi nhận ngưỡng', () async {
    final when = DateTime(2026, 10, 15);
    await Repo.setBudget(when, 1000000);
    await Repo.setBudgetEnabled(when, false);
    await Repo.saveTxn(Txn(isIncome: false, amount: 950000, category: 'Ăn uống', date: DateTime(2026, 10, 3)));
    final st = await Repo.budgetStatus(when);
    expect(st.budget!.enabled, false);
    expect(st.budget!.notified, 0);
  });

  test('Hóa đơn: trả tiền tạo giao dịch, dời kỳ sau, chống trả trùng', () async {
    final b = Bill(
      name: 'Internet',
      amount: 300000,
      category: 'Hóa đơn',
      dueDay: 10,
      nextDue: DateTime(2026, 10, 10),
    );
    await Repo.saveBill(b);

    expect(await Repo.payBill(b.id!), true);
    var cur = (await Repo.bills()).single;
    expect(cur.nextDue, DateTime(2026, 11, 10));
    var txns = await Repo.txns();
    expect(txns.length, 1);
    expect(txns.single.amount, 300000);
    expect(txns.single.isIncome, false);
    expect(txns.single.note, contains('Internet'));

    // Đưa hạn về kỳ đã trả rồi trả lại: phải bị chặn
    cur.nextDue = DateTime(2026, 10, 10);
    await Repo.saveBill(cur);
    expect(await Repo.payBill(b.id!), false);
    expect((await Repo.txns()).length, 1);
    expect((await Repo.bills()).single.nextDue, DateTime(2026, 10, 10));

    // Kỳ kế tiếp trả bình thường
    cur.nextDue = DateTime(2026, 11, 10);
    await Repo.saveBill(cur);
    expect(await Repo.payBill(b.id!), true);
    expect((await Repo.bills()).single.nextDue, DateTime(2026, 12, 10));
    txns = await Repo.txns();
    expect(txns.length, 2);
  });

  test('Ghi chú: tạo, ghim, sửa, xóa', () async {
    final n = Note(title: 'Việc cần làm', content: 'Mua sữa', color: 2, updated: DateTime(2026, 10, 1));
    await Repo.saveNote(n);
    final other = Note(title: 'Khác', updated: DateTime(2026, 10, 1));
    await Repo.saveNote(other);

    n.pinned = true;
    await Repo.saveNote(n);
    var list = await Repo.notes();
    expect(list.length, 2);
    expect(list.first.title, 'Việc cần làm'); // ghim lên đầu
    expect(list.first.color, 2);

    other.content = 'Nội dung mới';
    await Repo.saveNote(other);
    list = await Repo.notes();
    expect(list.firstWhere((x) => x.title == 'Khác').content, 'Nội dung mới');

    await Repo.deleteNote(n);
    await Repo.deleteNote(other);
    expect(await Repo.notes(), isEmpty);
  });

  test('Sao lưu: xuất, xóa sạch, khôi phục đủ mọi loại dữ liệu', () async {
    await Repo.saveEvent(Event(title: 'A', start: DateTime(2026, 10, 1, 9), repeat: 4));
    await Repo.saveTxn(Txn(isIncome: true, amount: 8000000, category: 'Lương', date: DateTime(2026, 10, 1)));
    await Repo.setBudget(DateTime(2026, 10, 1), 5000000);
    await Repo.saveBill(Bill(name: 'Nước', amount: 100000, category: 'Hóa đơn', dueDay: 5, nextDue: DateTime(2026, 10, 5)));
    await Repo.saveGoal(Goal(name: 'Du lịch', target: 5000000, saved: 1000000, created: DateTime(2026, 10, 1)));
    await Repo.saveNote(Note(title: 'Ghi chú', content: 'Nội dung', updated: DateTime(2026, 10, 1)));

    final json = await Repo.exportJson();

    await Repo.restore((
      events: <Event>[],
      txns: <Txn>[],
      budgets: <Budget>[],
      bills: <Bill>[],
      goals: <Goal>[],
      notes: <Note>[],
    ));
    expect(await Repo.events(), isEmpty);
    expect(await Repo.txns(), isEmpty);
    expect(await Repo.bills(), isEmpty);
    expect(await Repo.goals(), isEmpty);
    expect(await Repo.notes(), isEmpty);

    await Repo.restore(BackupService.parse(json));
    expect((await Repo.events()).single.repeat, 4);
    expect((await Repo.txns()).single.amount, 8000000);
    expect((await Repo.budgetStatus(DateTime(2026, 10, 1))).budget!.limit, 5000000);
    expect((await Repo.bills()).single.dueDay, 5);
    expect((await Repo.goals()).single.saved, 1000000);
    expect((await Repo.notes()).single.content, 'Nội dung');
  });

  test('Nâng cấp CSDL từ phiên bản 1 lên 4 giữ nguyên dữ liệu cũ', () async {
    await Repo.closeForTest();
    final dir = Directory.systemTemp.createTempSync('lifesync_db');
    try {
      final path = '${dir.path}/old.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute(
              'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'title TEXT NOT NULL, description TEXT, start_ms INTEGER NOT NULL, '
              'reminder_min INTEGER NOT NULL, repeat INTEGER NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'type TEXT NOT NULL, amount INTEGER NOT NULL, category TEXT NOT NULL, '
              'note TEXT, date_ms INTEGER NOT NULL)',
            );
            await d.insert('events', {
              'title': 'Cũ',
              'description': '',
              'start_ms': 1000,
              'reminder_min': -1,
              'repeat': 0,
            });
            await d.insert('transactions', {
              'type': 'expense',
              'amount': 1000,
              'category': 'Ăn uống',
              'note': '',
              'date_ms': 1000,
            });
          },
        ),
      );
      await old.close();

      final up = await Repo.openAt(path, factory: databaseFactoryFfi);
      Repo.useDb(up);

      final ev = await Repo.events();
      expect(ev.single.title, 'Cũ');
      expect(ev.single.end, isNull);
      expect((await Repo.txns()).single.amount, 1000);

      // Các bảng mới hoạt động sau khi nâng cấp
      await Repo.saveBill(Bill(name: 'X', amount: 1, category: 'Hóa đơn', dueDay: 1, nextDue: DateTime(2026, 10, 1)));
      await Repo.saveGoal(Goal(name: 'Y', target: 10, created: DateTime(2026, 10, 1)));
      await Repo.saveNote(Note(title: 'Z', updated: DateTime(2026, 10, 1)));
      expect((await Repo.bills()).length, 1);
      expect((await Repo.goals()).length, 1);
      expect((await Repo.notes()).length, 1);

      final idx = await up.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_txn_date'",
      );
      expect(idx, isNotEmpty);
    } finally {
      await Repo.closeForTest();
      dir.deleteSync(recursive: true);
    }
  });

  test('Hiệu năng: 5000 giao dịch vẫn đọc nhanh và tính đúng tổng chi tháng', () async {
    await Repo.closeForTest();
    final db = await Repo.openAt(inMemoryDatabasePath, factory: databaseFactoryFfi);
    Repo.useDb(db);
    final batch = db.batch();
    for (var i = 0; i < 5000; i++) {
      batch.insert('transactions', {
        'type': 'expense',
        'amount': 1000,
        'category': 'Ăn uống',
        'note': '',
        'date_ms': DateTime(2026, 10, 1 + i % 28, 12).millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
    final sw = Stopwatch()..start();
    final all = await Repo.txns();
    final spent = await Repo.spentInMonth(DateTime(2026, 10, 15));
    sw.stop();
    expect(all.length, 5000);
    expect(spent, 5000 * 1000);
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
