import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/services/lunar_service.dart';

void main() {
  void expectLunar(DateTime d, int day, int month, int year, bool leap) {
    final l = LunarService.toLunar(d);
    expect((l.day, l.month, l.year, l.leap), (day, month, year, leap), reason: '$d');
  }

  test('Mùng 1 Tết', () {
    expectLunar(DateTime(2026, 2, 17), 1, 1, 2026, false);
    expectLunar(DateTime(2025, 1, 29), 1, 1, 2025, false);
    expectLunar(DateTime(2024, 2, 10), 1, 1, 2024, false);
    expectLunar(DateTime(2023, 1, 22), 1, 1, 2023, false);
  });
  test('Rằm tháng 8 năm 2026 (Trung Thu) và 01/10/2026', () {
    expectLunar(DateTime(2026, 9, 25), 15, 8, 2026, false);
    expectLunar(DateTime(2026, 10, 1), 21, 8, 2026, false);
  });
  test('Tháng nhuận 2023', () {
    expectLunar(DateTime(2023, 2, 20), 1, 2, 2023, false);
    expectLunar(DateTime(2023, 3, 22), 1, 2, 2023, true);
    expectLunar(DateTime(2023, 4, 20), 1, 3, 2023, false);
  });
  test('Qua năm', () {
    expectLunar(DateTime(2000, 1, 1), 25, 11, 1999, false);
  });
  test('Nhãn hiển thị', () {
    expect(LunarService.toLunar(DateTime(2026, 10, 1)).label, '21/08 Âm lịch');
    expect(LunarService.toLunar(DateTime(2023, 3, 22)).label, '01/02 (nhuận) Âm lịch');
    expect(LunarService.toLunar(DateTime(2026, 2, 17)).short, '1/1');
  });
}
