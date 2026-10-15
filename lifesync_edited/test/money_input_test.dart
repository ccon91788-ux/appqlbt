import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/utils.dart';

TextEditingValue _v(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

void main() {
  const f = ThousandsFormatter();

  test('groupDigits', () {
    expect(groupDigits(''), '');
    expect(groupDigits('7'), '7');
    expect(groupDigits('999'), '999');
    expect(groupDigits('1000'), '1,000');
    expect(groupDigits('1500000'), '1,500,000');
    expect(groupDigits('8000000000'), '8,000,000,000');
  });

  test('gõ 1500000 hiện 1,500,000', () {
    final r = f.formatEditUpdate(TextEditingValue.empty, _v('1500000'));
    expect(r.text, '1,500,000');
    expect(r.selection.baseOffset, 9);
  });

  test('gõ từng chữ số một', () {
    var v = TextEditingValue.empty;
    for (final c in '1500000'.split('')) {
      v = f.formatEditUpdate(v, _v(v.text + c));
    }
    expect(v.text, '1,500,000');
  });

  test('xóa chữ số cuối', () {
    final r = f.formatEditUpdate(_v('1,500,000'), _v('1,500,00'));
    expect(r.text, '150,000');
    expect(r.selection.baseOffset, 7);
  });

  test('chèn chữ số ở giữa giữ đúng vị trí con trỏ', () {
    final r = f.formatEditUpdate(_v('1,500,000'), _v('1,5000,000', 5));
    expect(r.text, '15,000,000');
    expect(r.selection.baseOffset, 5);
  });

  test('bỏ số 0 đứng đầu và ký tự lạ', () {
    expect(f.formatEditUpdate(TextEditingValue.empty, _v('007')).text, '7');
    expect(f.formatEditUpdate(TextEditingValue.empty, _v('0')).text, '');
    expect(f.formatEditUpdate(TextEditingValue.empty, _v('12ab3')).text, '123');
  });

  test('giới hạn 13 chữ số', () {
    final r = f.formatEditUpdate(TextEditingValue.empty, _v('9' * 20));
    expect(r.text.replaceAll(',', '').length, 13);
  });

  test('parseMoney', () {
    expect(parseMoney('1,500,000'), 1500000);
    expect(parseMoney('50000'), 50000);
    expect(parseMoney(''), isNull);
    expect(parseMoney('abc'), isNull);
  });
}
