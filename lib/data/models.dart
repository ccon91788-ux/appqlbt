class Event {
  int? id;
  String title;
  String description;
  DateTime start;
  DateTime? end;
  int reminderMin; // -1 = không nhắc
  int repeat; // 0 không, 1 ngày, 2 tuần, 3 tháng, 4 năm

  Event({
    this.id,
    required this.title,
    this.description = '',
    required this.start,
    this.end,
    this.reminderMin = -1,
    this.repeat = 0,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'start_ms': start.millisecondsSinceEpoch,
    'end_ms': end?.millisecondsSinceEpoch,
    'reminder_min': reminderMin,
    'repeat': repeat,
  };

  factory Event.fromMap(Map<String, Object?> m) => Event(
    id: (m['id'] as num?)?.toInt(),
    title: (m['title'] as String?) ?? '',
    description: (m['description'] as String?) ?? '',
    start: DateTime.fromMillisecondsSinceEpoch((m['start_ms'] as num).toInt()),
    end: m['end_ms'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((m['end_ms'] as num).toInt()),
    reminderMin: (m['reminder_min'] as num?)?.toInt() ?? -1,
    repeat: (m['repeat'] as num?)?.toInt() ?? 0,
  );

  /// Sự kiện lặp lại thật: tính theo quy tắc, không chỉ lưu chữ "weekly".
  bool occursOn(DateTime day) {
    final a = DateTime.utc(start.year, start.month, start.day);
    final b = DateTime.utc(day.year, day.month, day.day);
    if (b.isBefore(a)) return false;
    switch (repeat) {
      case 1:
        return true;
      case 2:
        return b.difference(a).inDays % 7 == 0;
      case 3:
        return b.day == a.day;
      case 4:
        return b.day == a.day && b.month == a.month;
      default:
        return b == a;
    }
  }
}

class Txn {
  int? id;
  bool isIncome;
  int amount; // VND, số nguyên
  String category;
  String note;
  DateTime date;

  Txn({
    this.id,
    required this.isIncome,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'type': isIncome ? 'income' : 'expense',
    'amount': amount,
    'category': category,
    'note': note,
    'date_ms': date.millisecondsSinceEpoch,
  };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
    id: (m['id'] as num?)?.toInt(),
    isIncome: m['type'] == 'income',
    amount: (m['amount'] as num).toInt(),
    category: (m['category'] as String?) ?? '',
    note: (m['note'] as String?) ?? '',
    date: DateTime.fromMillisecondsSinceEpoch((m['date_ms'] as num).toInt()),
  );
}

class Budget {
  String ym; // 'yyyy-MM'
  int limit;
  bool enabled;
  int notified; // bit 1 = 80%, 2 = 90%, 4 = 100%

  Budget({
    required this.ym,
    required this.limit,
    this.enabled = true,
    this.notified = 0,
  });

  Map<String, Object?> toMap() => {
    'ym': ym,
    'limit_amount': limit,
    'enabled': enabled ? 1 : 0,
    'notified': notified,
  };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    ym: m['ym'] as String,
    limit: (m['limit_amount'] as num).toInt(),
    enabled: ((m['enabled'] as num?)?.toInt() ?? 1) == 1,
    notified: (m['notified'] as num?)?.toInt() ?? 0,
  );
}

class Bill {
  int? id;
  String name;
  int amount;
  String category;
  int dueDay;
  String note;
  bool enabled;
  DateTime nextDue;

  Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDay,
    this.note = '',
    this.enabled = true,
    required this.nextDue,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'category': category,
    'due_day': dueDay,
    'note': note,
    'enabled': enabled ? 1 : 0,
    'next_due_ms': nextDue.millisecondsSinceEpoch,
  };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
    id: (m['id'] as num?)?.toInt(),
    name: (m['name'] as String?) ?? '',
    amount: (m['amount'] as num).toInt(),
    category: (m['category'] as String?) ?? 'Hóa đơn',
    dueDay: (m['due_day'] as num).toInt(),
    note: (m['note'] as String?) ?? '',
    enabled: ((m['enabled'] as num?)?.toInt() ?? 1) == 1,
    nextDue: DateTime.fromMillisecondsSinceEpoch(
      (m['next_due_ms'] as num).toInt(),
    ),
  );
}

class Goal {
  int? id;
  String name;
  int target;
  int saved;
  DateTime? deadline;
  String note;
  DateTime created;

  Goal({
    this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.deadline,
    this.note = '',
    required this.created,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
    'deadline_ms': deadline?.millisecondsSinceEpoch,
    'note': note,
    'created_ms': created.millisecondsSinceEpoch,
  };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
    id: (m['id'] as num?)?.toInt(),
    name: (m['name'] as String?) ?? '',
    target: (m['target'] as num).toInt(),
    saved: (m['saved'] as num?)?.toInt() ?? 0,
    deadline: m['deadline_ms'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((m['deadline_ms'] as num).toInt()),
    note: (m['note'] as String?) ?? '',
    created: DateTime.fromMillisecondsSinceEpoch(
      ((m['created_ms'] as num?) ?? DateTime.now().millisecondsSinceEpoch).toInt(),
    ),
  );
}

class Note {
  int? id;
  String title;
  String content;
  int color; // chỉ số màu pastel 0..5
  bool pinned;
  DateTime updated;
  String sticker; // '' = không có; tên sticker có sẵn hoặc 'file:<đường dẫn>'
  int border; // màu viền sticker (ARGB), 0 = không viền

  Note({
    this.id,
    this.title = '',
    this.content = '',
    this.color = 0,
    this.pinned = false,
    required this.updated,
    this.sticker = '',
    this.border = 0,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'color': color,
    'pinned': pinned ? 1 : 0,
    'updated_ms': updated.millisecondsSinceEpoch,
    'sticker': sticker,
    'border': border,
  };

  factory Note.fromMap(Map<String, Object?> m) => Note(
    id: (m['id'] as num?)?.toInt(),
    title: (m['title'] as String?) ?? '',
    content: (m['content'] as String?) ?? '',
    color: (m['color'] as num?)?.toInt() ?? 0,
    pinned: ((m['pinned'] as num?)?.toInt() ?? 0) == 1,
    sticker: (m['sticker'] as String?) ?? '',
    border: (m['border'] as num?)?.toInt() ?? 0,
    updated: DateTime.fromMillisecondsSinceEpoch(
      ((m['updated_ms'] as num?) ?? DateTime.now().millisecondsSinceEpoch).toInt(),
    ),
  );
}

/// Kiểu hiển thị của một danh mục: sticker + màu viền.
/// [custom] = danh mục do người dùng tự tạo (có thể đổi tên / xóa).
class CatStyle {
  String name;
  bool isIncome;
  String sticker; // '' = dùng sticker mặc định
  int border; // ARGB, 0 = không viền
  bool custom;

  CatStyle({
    required this.name,
    required this.isIncome,
    this.sticker = '',
    this.border = 0,
    this.custom = false,
  });

  Map<String, Object?> toMap() => {
    'name': name,
    'is_income': isIncome ? 1 : 0,
    'sticker': sticker,
    'border': border,
    'custom': custom ? 1 : 0,
  };

  factory CatStyle.fromMap(Map<String, Object?> m) => CatStyle(
    name: (m['name'] as String?) ?? '',
    isIncome: ((m['is_income'] as num?)?.toInt() ?? 0) == 1,
    sticker: (m['sticker'] as String?) ?? '',
    border: (m['border'] as num?)?.toInt() ?? 0,
    custom: ((m['custom'] as num?)?.toInt() ?? 0) == 1,
  );
}
