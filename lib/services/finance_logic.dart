/// Logic thuần (không phụ thuộc Flutter) để dễ kiểm thử.

String ymKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Quyết định có cần báo ngưỡng ngân sách hay không.
/// Mỗi ngưỡng (80/90/100) chỉ báo một lần: trạng thái lưu trong [mask].
({int? fire, int mask}) evaluateBudget(int spent, int limit, int mask) {
  if (limit <= 0 || spent < 0) return (fire: null, mask: mask);
  final pct = spent * 100 ~/ limit;
  int? fire;
  var m = mask;
  for (final t in const [80, 90, 100]) {
    final bit = t == 80 ? 1 : (t == 90 ? 2 : 4);
    if (pct >= t && (m & bit) == 0) {
      fire = t;
      m |= bit;
    }
  }
  return (fire: fire, mask: m);
}

/// Ngày đến hạn trong tháng (tự co lại nếu tháng ngắn, vd. ngày 31 → 28/30).
DateTime billDue(int year, int month, int dueDay) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, dueDay > last ? last : dueDay);
}

DateTime firstDue(int dueDay, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  final d = billDue(t.year, t.month, dueDay);
  return d.isBefore(t) ? billDue(t.year, t.month + 1, dueDay) : d;
}

DateTime nextDueAfter(DateTime due, int dueDay) =>
    billDue(due.year, due.month + 1, dueDay);

double goalProgress(int saved, int target) {
  if (target <= 0) return 0;
  final v = saved / target;
  return v < 0 ? 0 : (v > 1 ? 1 : v);
}

/// Số tiền cần để dành mỗi tháng tới hạn (0 nếu đã đủ hoặc không có hạn).
int monthlyNeeded(int target, int saved, DateTime? deadline, DateTime now) {
  final remaining = target - saved;
  if (remaining <= 0 || deadline == null) return 0;
  var months = (deadline.year - now.year) * 12 + deadline.month - now.month;
  if (months < 1) months = 1;
  return (remaining + months - 1) ~/ months;
}
