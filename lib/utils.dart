import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String fmtMoney(int v) => '${NumberFormat('#,##0', 'en_US').format(v)} ₫';

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

const incomeCats = ['Lương', 'Trợ cấp', 'Kinh doanh', 'Thu nhập khác'];
const expenseCats = [
  'Ăn uống', 'Di chuyển', 'Giáo dục', 'Mua sắm',
  'Giải trí', 'Hóa đơn', 'Sức khỏe', 'Chi tiêu khác',
];

const _catEmoji = <String, String>{
  'Lương': '💼',
  'Trợ cấp': '🎁',
  'Kinh doanh': '🏪',
  'Thu nhập khác': '💰',
  'Ăn uống': '🍜',
  'Di chuyển': '🛵',
  'Giáo dục': '📚',
  'Mua sắm': '🛍️',
  'Giải trí': '🎮',
  'Hóa đơn': '🧾',
  'Sức khỏe': '💊',
  'Chi tiêu khác': '🧺',
};

String catEmoji(String c) => _catEmoji[c] ?? '🏷️';

/// Chèn dấu phẩy phân cách hàng nghìn: '1500000' -> '1,500,000'.
String groupDigits(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Đọc số tiền từ chuỗi có dấu phẩy. Trả về null nếu không hợp lệ.
int? parseMoney(String s) => int.tryParse(s.replaceAll(',', '').trim());

/// Tự thêm dấu phân cách khi gõ, giữ nguyên vị trí con trỏ.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final sel = newValue.selection.baseOffset;
    final pos = (sel < 0 || sel > raw.length) ? raw.length : sel;
    var digitsBefore = RegExp(r'\d').allMatches(raw.substring(0, pos)).length;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final noZeros = digits.replaceFirst(RegExp(r'^0+'), '');
    digitsBefore -= digits.length - noZeros.length;
    digits = noZeros.length > 13 ? noZeros.substring(0, 13) : noZeros;
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digitsBefore < 0) digitsBefore = 0;
    if (digitsBefore > digits.length) digitsBefore = digits.length;
    final text = groupDigits(digits);
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBefore) {
      if (text[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
