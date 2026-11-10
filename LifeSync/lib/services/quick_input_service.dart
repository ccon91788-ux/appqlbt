class QuickResult {
  final bool? isIncome;
  final int? amount;
  final String note;
  final String category;
  final bool suspicious;
  const QuickResult({
    this.isIncome,
    this.amount,
    this.note = '',
    this.category = '',
    this.suspicious = false,
  });
  bool get certain =>
      isIncome != null && amount != null && amount! > 0 && !suspicious;
}

const _cats = <String, String>{
  'ăn': 'Ăn uống',
  'uống': 'Ăn uống',
  'cafe': 'Ăn uống',
  'cà phê': 'Ăn uống',
  'xăng': 'Di chuyển',
  'xe': 'Di chuyển',
  'grab': 'Di chuyển',
  'sách': 'Giáo dục',
  'học': 'Giáo dục',
  'điện': 'Hóa đơn',
  'nước': 'Hóa đơn',
  'internet': 'Hóa đơn',
  'thuốc': 'Sức khỏe',
  'lương': 'Lương',
  'thưởng': 'Thu nhập khác',
};

QuickResult parseQuick(String input) {
  final s = input.trim().toLowerCase();
  bool? inc;
  if (RegExp(r'^(?:(?:thu|nhận|nhan)(?![\p{L}])|\+)', unicode: true).hasMatch(s)) {
    inc = true;
  } else if (RegExp(r'^(?:(?:chi|tiêu|tieu)(?![\p{L}])|-)', unicode: true).hasMatch(s)) {
    inc = false;
  }
  final re = RegExp(
    r'(\d+(?:[.,]\d+)*)\s*(triệu|trieu|tr|nghìn|nghin|k|củ)?(?![\p{L}])',
    unicode: true,
  );
  final m = re.firstMatch(s);
  int? amount;
  var suspicious = false;
  var rest = s;
  if (m != null) {
    final tok = m.group(1)!;
    final unit = m.group(2);
    if (unit == null) {
      amount = int.tryParse(tok.replaceAll(RegExp(r'[.,]'), ''));
      if (amount != null && amount < 1000) suspicious = true;
    } else {
      final v = double.tryParse(tok.replaceAll(',', '.')) ??
          double.tryParse(tok.replaceAll(RegExp(r'[.,]'), ''));
      if (v != null) {
        final mult = (unit == 'k' || unit.startsWith('ngh')) ? 1000 : 1000000;
        amount = (v * mult).round();
      }
    }
    rest = s.replaceFirst(m.group(0)!, ' ');
  }
  rest = rest
      .replaceFirst(
        RegExp(r'^\s*(?:thu|chi|nhận|nhan|tiêu|tieu|\+|-)\s*', unicode: true),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  var cat = '';
  for (final e in _cats.entries) {
    if (s.contains(e.key)) {
      cat = e.value;
      break;
    }
  }
  return QuickResult(
    isIncome: inc,
    amount: amount,
    note: rest,
    category: cat,
    suspicious: suspicious,
  );
}
