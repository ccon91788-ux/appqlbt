import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/services/quick_input_service.dart';
import 'package:lifesync/utils.dart';

void main() {
  test('Chi 50k ăn sáng', () {
    final r = parseQuick('Chi 50k ăn sáng');
    expect(r.isIncome, false);
    expect(r.amount, 50000);
    expect(r.note, 'ăn sáng');
    expect(r.certain, true);
  });
  test('Thu 8tr lương', () {
    final r = parseQuick('Thu 8tr lương');
    expect(r.isIncome, true);
    expect(r.amount, 8000000);
  });
  test('Chi 35.000 tiền xăng', () {
    expect(parseQuick('Chi 35.000 tiền xăng').amount, 35000);
  });
  test('Chi 1 triệu mua sách', () {
    expect(parseQuick('Chi 1 triệu mua sách').amount, 1000000);
  });
  test('Thu 500k và 1.5tr', () {
    expect(parseQuick('Thu 500k').amount, 500000);
    expect(parseQuick('thu 1.5tr').amount, 1500000);
  });
  test('Không rõ số tiền thì không chắc chắn', () {
    expect(parseQuick('mua gì đó').certain, false);
  });
  test('Định dạng tiền', () {
    expect(fmtMoney(1500000), '1,500,000 ₫');
  });
}
