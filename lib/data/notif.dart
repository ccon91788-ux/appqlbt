import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../utils.dart';
import 'models.dart';

class Notif {
  static final FlutterLocalNotificationsPlugin _p =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _events = NotificationDetails(
    android: AndroidNotificationDetails(
      'lifesync_reminders',
      'LifeSync Reminders',
      channelDescription: 'Nhắc nhở sự kiện',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );
  static const NotificationDetails _budget = NotificationDetails(
    android: AndroidNotificationDetails(
      'lifesync_budget',
      'LifeSync Budget',
      channelDescription: 'Cảnh báo ngân sách',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );
  static AndroidFlutterLocalNotificationsPlugin? get _android => _p
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _p.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final a = _android;
    await a?.requestNotificationsPermission();
    if (!(await a?.canScheduleExactNotifications() ?? true)) {
      await a?.requestExactAlarmsPermission();
    }
  }

  static DateTimeComponents? _match(int repeat) {
    switch (repeat) {
      case 1:
        return DateTimeComponents.time;
      case 2:
        return DateTimeComponents.dayOfWeekAndTime;
      case 3:
        return DateTimeComponents.dayOfMonthAndTime;
      case 4:
        return DateTimeComponents.dateAndTime; // lặp hằng năm (tháng + ngày + giờ)
      default:
        return null;
    }
  }

  static Future<void> _zoned(
    int id,
    String title,
    String body,
    DateTime f,
    NotificationDetails nd, {
    DateTimeComponents? match,
  }) async {
    final t = tz.TZDateTime(tz.local, f.year, f.month, f.day, f.hour, f.minute);
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _p.zonedSchedule(
      id,
      title,
      body,
      t,
      nd,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }

  /// ID thông báo = id sự kiện (ổn định, không trùng lặp).
  static Future<void> schedule(Event e) async {
    try {
      await _p.cancel(e.id!);
      if (e.reminderMin < 0) return;
      var f = e.start.subtract(Duration(minutes: e.reminderMin));
      final now = DateTime.now();
      var guard = 0;
      while (!f.isAfter(now) && e.repeat > 0 && guard++ < 20000) {
        if (e.repeat == 1) {
          f = DateTime(f.year, f.month, f.day + 1, f.hour, f.minute);
        } else if (e.repeat == 2) {
          f = DateTime(f.year, f.month, f.day + 7, f.hour, f.minute);
        } else if (e.repeat == 3) {
          f = DateTime(f.year, f.month + 1, f.day, f.hour, f.minute);
        } else {
          f = DateTime(f.year + 1, f.month, f.day, f.hour, f.minute);
        }
      }
      if (!f.isAfter(now)) return;
      await _zoned(
        e.id!,
        e.title,
        e.description.isEmpty ? 'Sắp đến giờ sự kiện' : e.description,
        f,
        _events,
        match: _match(e.repeat),
      );
    } catch (_) {
      // Không để lỗi thông báo làm sập ứng dụng.
    }
  }

  static Future<void> cancel(int id) async {
    try {
      await _p.cancel(id);
    } catch (_) {}
  }

  static Future<void> showBudget(int threshold, int spent, int limit) async {
    try {
      await _p.show(
        2000000 + threshold,
        threshold >= 100 ? 'Đã vượt ngân sách tháng' : 'Sắp hết ngân sách tháng',
        'Bạn đã dùng $threshold% ngân sách tháng này '
            '(${fmtMoney(spent)} / ${fmtMoney(limit)}).',
        _budget,
      );
    } catch (_) {}
  }

  static Future<void> rescheduleAll(List<Event> events) async {
    for (final e in events) {
      if (e.id != null) await schedule(e);
    }
  }
}
