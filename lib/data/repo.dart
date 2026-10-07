import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../utils.dart' show expenseCats, incomeCats;
import 'package:sqflite/sqflite.dart';
import '../services/backup_service.dart';
import '../services/finance_logic.dart';
import '../stickers.dart' show catStyles;
import 'models.dart';
import 'notif.dart';

/// Tăng giá trị này để các màn hình tải lại dữ liệu.
final ValueNotifier<int> dataTick = ValueNotifier<int>(0);

class BudgetStatus {
  final Budget? budget;
  final int spent;
  const BudgetStatus(this.budget, this.spent);
}

class Repo {
  static Database? _d;

  static Future<void> _createV2(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS budgets(ym TEXT PRIMARY KEY, '
      'limit_amount INTEGER NOT NULL, enabled INTEGER NOT NULL, notified INTEGER NOT NULL)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS goals(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, target INTEGER NOT NULL, saved INTEGER NOT NULL, '
      'deadline_ms INTEGER, note TEXT, created_ms INTEGER NOT NULL)',
    );
  }

  static Future<void> _createNotes(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'title TEXT NOT NULL, content TEXT, color INTEGER NOT NULL, '
      'pinned INTEGER NOT NULL, updated_ms INTEGER NOT NULL, '
      "sticker TEXT NOT NULL DEFAULT '', border INTEGER NOT NULL DEFAULT 0)",
    );
  }

  static Future<void> _createCategories(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS categories(name TEXT PRIMARY KEY, '
      'is_income INTEGER NOT NULL, sticker TEXT NOT NULL, '
      'border INTEGER NOT NULL, custom INTEGER NOT NULL)',
    );
  }

  static Future<void> _createIndexes(Database d) async {
    await d.execute('CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date_ms)');
    await d.execute('CREATE INDEX IF NOT EXISTS idx_txn_type_date ON transactions(type, date_ms)');
    await d.execute('CREATE INDEX IF NOT EXISTS idx_events_start ON events(start_ms)');
  }

  /// Mở (hoặc tạo / nâng cấp) CSDL tại [path]. Dùng cho cả app lẫn test.
  static Future<Database> openAt(String path, {DatabaseFactory? factory}) =>
      (factory ?? databaseFactory).openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (d, v) async {
            await d.execute(
              'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'title TEXT NOT NULL, description TEXT, start_ms INTEGER NOT NULL, '
              'end_ms INTEGER, reminder_min INTEGER NOT NULL, repeat INTEGER NOT NULL)',
            );
            await d.execute(
              'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'type TEXT NOT NULL, amount INTEGER NOT NULL, category TEXT NOT NULL, '
              'note TEXT, date_ms INTEGER NOT NULL)',
            );
            await _createV2(d);
            await _createIndexes(d);
            await _createNotes(d);
            await _createCategories(d);
          },
          onUpgrade: (d, oldV, newV) async {
            if (oldV < 2) {
              await d.execute('ALTER TABLE events ADD COLUMN end_ms INTEGER');
              await _createV2(d);
            }
            if (oldV < 3) {
              await _createIndexes(d);
            }
            if (oldV < 4) {
              await _createNotes(d); // đã có sẵn cột sticker/border
            } else if (oldV < 5) {
              await d.execute("ALTER TABLE notes ADD COLUMN sticker TEXT NOT NULL DEFAULT ''");
              await d.execute('ALTER TABLE notes ADD COLUMN border INTEGER NOT NULL DEFAULT 0');
            }
            if (oldV < 5) {
              await _createCategories(d);
            }
          },
        ),
      );

  static Future<Database> get _db async =>
      _d ??= await openAt(p.join(await getDatabasesPath(), 'lifesync.db'));

  @visibleForTesting
  static void useDb(Database d) => _d = d;

  @visibleForTesting
  static Future<void> closeForTest() async {
    await _d?.close();
    _d = null;
  }

  // ---------- Sự kiện ----------
  static Future<List<Event>> events() async {
    final rows = await (await _db).query('events', orderBy: 'start_ms');
    return rows.map(Event.fromMap).toList();
  }

  static Future<void> saveEvent(Event e) async {
    final d = await _db;
    if (e.id == null) {
      e.id = await d.insert('events', e.toMap()..remove('id'));
    } else {
      await d.update('events', e.toMap(), where: 'id=?', whereArgs: [e.id]);
    }
    await Notif.schedule(e);
    dataTick.value++;
  }

  static Future<void> deleteEvent(Event e) async {
    if (e.id == null) return;
    await Notif.cancel(e.id!);
    await (await _db).delete('events', where: 'id=?', whereArgs: [e.id]);
    dataTick.value++;
  }

  // ---------- Giao dịch ----------
  static Future<List<Txn>> txns() async {
    final rows = await (await _db).query('transactions', orderBy: 'date_ms DESC');
    return rows.map(Txn.fromMap).toList();
  }

  static Future<void> saveTxn(Txn t) async {
    final d = await _db;
    if (t.id == null) {
      t.id = await d.insert('transactions', t.toMap()..remove('id'));
    } else {
      await d.update('transactions', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    }
    if (!t.isIncome) await _checkBudget(t.date);
    dataTick.value++;
  }

  static Future<void> deleteTxn(Txn t) async {
    if (t.id == null) return;
    await (await _db).delete('transactions', where: 'id=?', whereArgs: [t.id]);
    dataTick.value++;
  }

  // ---------- Ngân sách ----------
  static Future<int> spentInMonth(DateTime when) async {
    final a = DateTime(when.year, when.month).millisecondsSinceEpoch;
    final b = DateTime(when.year, when.month + 1).millisecondsSinceEpoch;
    final rows = await (await _db).rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE type=? AND date_ms>=? AND date_ms<?',
      ['expense', a, b],
    );
    return (rows.first['s'] as num).toInt();
  }

  static Future<BudgetStatus> budgetStatus(DateTime when) async {
    final d = await _db;
    final rows = await d.query('budgets', where: 'ym=?', whereArgs: [ymKey(when)]);
    return BudgetStatus(
      rows.isEmpty ? null : Budget.fromMap(rows.first),
      await spentInMonth(when),
    );
  }

  /// Đặt/sửa ngân sách. Đổi số tiền sẽ đặt lại các cảnh báo của tháng đó.
  static Future<void> setBudget(DateTime when, int limit) async {
    final d = await _db;
    final cur = (await budgetStatus(when)).budget;
    final b = Budget(
      ym: ymKey(when),
      limit: limit,
      enabled: cur?.enabled ?? true,
      notified: (cur != null && cur.limit == limit) ? cur.notified : 0,
    );
    await d.insert('budgets', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _checkBudget(when);
    dataTick.value++;
  }

  static Future<void> setBudgetEnabled(DateTime when, bool on) async {
    await (await _db).update('budgets', {'enabled': on ? 1 : 0},
        where: 'ym=?', whereArgs: [ymKey(when)]);
    if (on) await _checkBudget(when);
    dataTick.value++;
  }

  static Future<void> resetBudgetAlerts(DateTime when) async {
    await (await _db).update('budgets', {'notified': 0},
        where: 'ym=?', whereArgs: [ymKey(when)]);
    await _checkBudget(when);
    dataTick.value++;
  }

  static Future<void> _checkBudget(DateTime when) async {
    try {
      final d = await _db;
      final st = await budgetStatus(when);
      final b = st.budget;
      if (b == null || !b.enabled) return;
      final r = evaluateBudget(st.spent, b.limit, b.notified);
      if (r.mask != b.notified) {
        await d.update('budgets', {'notified': r.mask}, where: 'ym=?', whereArgs: [b.ym]);
      }
      if (r.fire != null) await Notif.showBudget(r.fire!, st.spent, b.limit);
    } catch (_) {}
  }

  /// Tính năng hóa đơn định kỳ đã bị gỡ: hủy các thông báo hóa đơn còn đặt từ bản cũ.
  /// Bảng cũ (nếu có) được giữ nguyên, không xóa dữ liệu.
  static Future<void> cancelLegacyBillAlarms() async {
    try {
      final rows = await (await _db).query('recurring_bills', columns: ['id']);
      for (final r in rows) {
        await Notif.cancel(1000000 + (r['id'] as num).toInt());
      }
    } catch (_) {} // bảng không tồn tại (cài mới) -> bỏ qua
  }

  // ---------- Mục tiêu tiết kiệm ----------
  static Future<List<Goal>> goals() async {
    final rows = await (await _db).query('goals', orderBy: 'created_ms DESC');
    return rows.map(Goal.fromMap).toList();
  }

  static Future<void> saveGoal(Goal g) async {
    final d = await _db;
    if (g.id == null) {
      g.id = await d.insert('goals', g.toMap()..remove('id'));
    } else {
      await d.update('goals', g.toMap(), where: 'id=?', whereArgs: [g.id]);
    }
    dataTick.value++;
  }

  static Future<void> deleteGoal(Goal g) async {
    if (g.id == null) return;
    await (await _db).delete('goals', where: 'id=?', whereArgs: [g.id]);
    dataTick.value++;
  }

  /// Thêm (delta > 0) hoặc rút (delta < 0). Trả về false nếu không hợp lệ.
  static Future<bool> adjustGoal(Goal g, int delta) async {
    if (delta == 0 || g.saved + delta < 0) return false;
    g.saved += delta;
    await saveGoal(g);
    return true;
  }

  // ---------- Ghi chú ----------
  static Future<List<Note>> notes() async {
    final rows = await (await _db).query('notes', orderBy: 'pinned DESC, updated_ms DESC');
    return rows.map(Note.fromMap).toList();
  }

  static Future<void> saveNote(Note n) async {
    final d = await _db;
    n.updated = DateTime.now();
    if (n.id == null) {
      n.id = await d.insert('notes', n.toMap()..remove('id'));
    } else {
      await d.update('notes', n.toMap(), where: 'id=?', whereArgs: [n.id]);
    }
    dataTick.value++;
  }

  static Future<void> deleteNote(Note n) async {
    if (n.id == null) return;
    await (await _db).delete('notes', where: 'id=?', whereArgs: [n.id]);
    dataTick.value++;
  }

  // ---------- Danh mục (sticker + màu viền) ----------
  /// Đọc toàn bộ danh mục đã tùy chỉnh và cập nhật bộ nhớ đệm [catStyles].
  static Future<List<CatStyle>> categories() async {
    final rows = await (await _db).query('categories', orderBy: 'name COLLATE NOCASE');
    final list = rows.map(CatStyle.fromMap).toList();
    catStyles
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.name, c)));
    return list;
  }

  /// Lưu danh mục. [oldName] != null và khác tên mới = đổi tên: các giao dịch và
  /// hóa đơn đang dùng tên cũ được chuyển sang tên mới.
  /// Trả về false nếu tên trống hoặc trùng với danh mục khác.
  static Future<bool> saveCategory(CatStyle c, {String? oldName}) async {
    c.name = c.name.trim();
    if (c.name.isEmpty) return false;
    final d = await _db;
    final renamed = oldName != null && oldName != c.name;
    if (renamed || oldName == null) {
      final taken = {...expenseCats, ...incomeCats};
      final dup = await d.query('categories', where: 'name=?', whereArgs: [c.name]);
      if (taken.contains(c.name) || dup.isNotEmpty) return false;
    }
    await d.transaction((t) async {
      if (renamed) {
        await t.update('transactions', {'category': c.name}, where: 'category=?', whereArgs: [oldName]);
        await t.delete('categories', where: 'name=?', whereArgs: [oldName]);
      }
      await t.insert('categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await categories();
    dataTick.value++;
    return true;
  }

  /// Xóa danh mục tự tạo. Giao dịch cũ vẫn giữ nguyên tên danh mục.
  static Future<void> deleteCategory(String name) async {
    await (await _db).delete('categories', where: 'name=?', whereArgs: [name]);
    await categories();
    dataTick.value++;
  }

  // ---------- Tổng hợp ----------
  static Future<({List<Txn> txns, BudgetStatus budget, int savings})> analytics() async {
    final gs = await goals();
    return (
      txns: await txns(),
      budget: await budgetStatus(DateTime.now()),
      savings: gs.fold<int>(0, (a, g) => a + g.saved),
    );
  }

  // ---------- Sao lưu ----------
  static Future<String> exportJson() async {
    final d = await _db;
    return BackupService.build(
      events: await events(),
      txns: await txns(),
      budgets: (await d.query('budgets')).map(Budget.fromMap).toList(),
      goals: await goals(),
      notes: await notes(),
    );
  }

  static Future<void> restore(BackupData data) async {
    final d = await _db;
    for (final e in await events()) {
      await Notif.cancel(e.id!);
    }
    await d.transaction((t) async {
      for (final tb in ['events', 'transactions', 'budgets', 'goals', 'notes']) {
        await t.delete(tb);
      }
      const r = ConflictAlgorithm.replace;
      for (final e in data.events) {
        await t.insert('events', e.toMap(), conflictAlgorithm: r);
      }
      for (final x in data.txns) {
        await t.insert('transactions', x.toMap(), conflictAlgorithm: r);
      }
      for (final x in data.budgets) {
        await t.insert('budgets', x.toMap(), conflictAlgorithm: r);
      }
      for (final x in data.goals) {
        await t.insert('goals', x.toMap(), conflictAlgorithm: r);
      }
      for (final x in data.notes) {
        await t.insert('notes', x.toMap(), conflictAlgorithm: r);
      }
    });
    await Notif.rescheduleAll(await events());
    dataTick.value++;
  }
}
