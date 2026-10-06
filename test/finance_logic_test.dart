import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/services/finance_logic.dart';

void main() {
  group('Ngân sách', () {
    test('dưới 80% không báo', () {
      expect(evaluateBudget(3900000, 5000000, 0).fire, isNull);
    });
    test('báo 80% đúng một lần', () {
      final r = evaluateBudget(4000000, 5000000, 0);
      expect(r.fire, 80);
      expect(evaluateBudget(4100000, 5000000, r.mask).fire, isNull);
    });
    test('báo 90% rồi 100%, không trùng', () {
      var m = evaluateBudget(4000000, 5000000, 0).mask;
      final r90 = evaluateBudget(4500000, 5000000, m);
      expect(r90.fire, 90);
      m = r90.mask;
      final r100 = evaluateBudget(5000000, 5000000, m);
      expect(r100.fire, 100);
      expect(evaluateBudget(6000000, 5000000, r100.mask).fire, isNull);
    });
    test('nhảy thẳng lên 95% chỉ báo một thông báo (90%)', () {
      final r = evaluateBudget(4750000, 5000000, 0);
      expect(r.fire, 90);
      expect(evaluateBudget(4800000, 5000000, r.mask).fire, isNull);
    });
    test('đặt lại cảnh báo thì báo lại', () {
      expect(evaluateBudget(4000000, 5000000, 0).fire, 80);
    });
    test('hạn mức không hợp lệ', () {
      expect(evaluateBudget(100, 0, 0).fire, isNull);
    });
  });

  group('Tiết kiệm', () {
    test('0%, 30%, 100%', () {
      expect(goalProgress(0, 10000000), 0);
      expect(goalProgress(3000000, 10000000), closeTo(0.3, 1e-9));
      expect(goalProgress(10000000, 10000000), 1);
      expect(goalProgress(12000000, 10000000), 1);
      expect(goalProgress(5, 0), 0);
    });
    test('số tiền cần để dành mỗi tháng', () {
      final now = DateTime(2026, 10, 2);
      expect(monthlyNeeded(10000000, 3000000, DateTime(2027, 4, 2), now), 1166667);
      expect(monthlyNeeded(10000000, 10000000, DateTime(2027, 4, 2), now), 0);
      expect(monthlyNeeded(10000000, 0, null, now), 0);
      expect(monthlyNeeded(1000000, 0, DateTime(2026, 9, 1), now), 1000000);
    });
  });

  group('Hóa đơn định kỳ', () {
    test('ngày đến hạn đầu tiên', () {
      expect(firstDue(10, DateTime(2026, 10, 2)), DateTime(2026, 10, 10));
      expect(firstDue(10, DateTime(2026, 10, 10)), DateTime(2026, 10, 10));
      expect(firstDue(10, DateTime(2026, 10, 11)), DateTime(2026, 11, 10));
    });
    test('dời sang tháng sau', () {
      expect(nextDueAfter(DateTime(2026, 10, 10), 10), DateTime(2026, 11, 10));
      expect(nextDueAfter(DateTime(2026, 12, 10), 10), DateTime(2027, 1, 10));
    });
    test('ngày 31 co lại ở tháng ngắn', () {
      expect(billDue(2026, 2, 31), DateTime(2026, 2, 28));
      expect(billDue(2028, 2, 31), DateTime(2028, 2, 29));
      expect(nextDueAfter(DateTime(2026, 1, 31), 31), DateTime(2026, 2, 28));
      expect(nextDueAfter(DateTime(2026, 2, 28), 31), DateTime(2026, 3, 31));
    });
  });

  test('ymKey', () {
    expect(ymKey(DateTime(2026, 3, 5)), '2026-03');
  });
}
