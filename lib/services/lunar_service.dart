import 'dart:math' as math;

class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool leap;
  const LunarDate(this.day, this.month, this.year, this.leap);

  String get short => day == 1 ? '$day/$month' : '$day';

  String get label =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}'
      '${leap ? ' (nhuận)' : ''} Âm lịch';
}

/// Chuyển dương → âm lịch Việt Nam (múi giờ UTC+7), thuật toán Hồ Ngọc Đức.
class LunarService {
  static const double _tz = 7.0;

  static int _jd(int dd, int mm, int yy) {
    final a = (14 - mm) ~/ 12;
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var j = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    if (j < 2299161) {
      j = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
    }
    return j;
  }

  static int _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = math.pi / 180;
    var j = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    j += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mp = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m);
    c -= 0.4068 * math.sin(mp * dr);
    c += 0.0161 * math.sin(dr * 2 * mp);
    c -= 0.0004 * math.sin(dr * 3 * mp);
    c += 0.0104 * math.sin(dr * 2 * f);
    c -= 0.0051 * math.sin(dr * (m + mp));
    c -= 0.0074 * math.sin(dr * (m - mp));
    c += 0.0004 * math.sin(dr * (2 * f + m));
    c -= 0.0004 * math.sin(dr * (2 * f - m));
    c -= 0.0006 * math.sin(dr * (2 * f + mp));
    c += 0.0010 * math.sin(dr * (2 * f - mp));
    c += 0.0005 * math.sin(dr * (2 * mp + m));
    final double dt;
    if (t < -11) {
      dt = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3;
    } else {
      dt = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    return (j + c - dt + 0.5 + _tz / 24).floor();
  }

  static int _sunLongitude(int jdn) {
    final t = (jdn - 0.5 - _tz / 24 - 2451545.0) / 36525;
    final t2 = t * t;
    const dr = math.pi / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m);
    var l = (l0 + dl) * dr;
    l -= math.pi * 2 * (l / (math.pi * 2)).floor();
    return (l / math.pi * 6).floor();
  }

  static int _month11(int yy) {
    final off = _jd(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = _newMoon(k);
    if (_sunLongitude(nm) >= 9) nm = _newMoon(k - 1);
    return nm;
  }

  static int _leapOffset(int a11) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var i = 1;
    var arc = _sunLongitude(_newMoon(k + i));
    int last;
    do {
      last = arc;
      i++;
      arc = _sunLongitude(_newMoon(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  static final Map<int, LunarDate> _cache = <int, LunarDate>{};

  /// Có bộ nhớ đệm: mỗi ngày chỉ tính một lần.
  static LunarDate toLunar(DateTime d) {
    final key = d.year * 10000 + d.month * 100 + d.day;
    final hit = _cache[key];
    if (hit != null) return hit;
    final r = _compute(d);
    if (_cache.length > 6000) _cache.clear();
    _cache[key] = r;
    return r;
  }

  static LunarDate _compute(DateTime d) {
    final dn = _jd(d.day, d.month, d.year);
    final k = ((dn - 2415021.076998695) / 29.530588853).floor();
    var ms = _newMoon(k + 1);
    if (ms > dn) ms = _newMoon(k);
    var a11 = _month11(d.year);
    var b11 = a11;
    int ly;
    if (a11 >= ms) {
      ly = d.year;
      a11 = _month11(d.year - 1);
    } else {
      ly = d.year + 1;
      b11 = _month11(d.year + 1);
    }
    final ld = dn - ms + 1;
    final diff = (ms - a11) ~/ 29;
    var leap = false;
    var lm = diff + 11;
    if (b11 - a11 > 365) {
      final lo = _leapOffset(a11);
      if (diff >= lo) {
        lm = diff + 10;
        if (diff == lo) leap = true;
      }
    }
    if (lm > 12) lm -= 12;
    if (lm >= 11 && diff < 4) ly -= 1;
    return LunarDate(ld, lm, ly, leap);
  }
}
