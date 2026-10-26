import 'package:intl/intl.dart';
import '../data/models.dart';

class CsvService {
  static String _q(String s) => '"${s.replaceAll('"', '""')}"';

  static String build(List<Txn> tx) {
    final f = DateFormat('yyyy-MM-dd HH:mm');
    final b = StringBuffer('\uFEFFDate,Type,Category,Amount,Note\r\n');
    for (final t in tx) {
      b.write(
        '${f.format(t.date)},${t.isIncome ? 'Thu' : 'Chi'},${_q(t.category)},'
        '${t.amount},${_q(t.note)}\r\n',
      );
    }
    return b.toString();
  }
}
