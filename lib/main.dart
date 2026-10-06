import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/notif.dart';
import 'data/repo.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/notes_screen.dart';
import 'services/update_service.dart';
import 'ui.dart';

final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
final ValueNotifier<bool> showLunar = ValueNotifier(true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  try {
    final sp = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values[(sp.getInt('theme') ?? 0).clamp(0, 2)];
    showLunar.value = sp.getBool('lunar') ?? true;
  } catch (_) {}
  try {
    await Repo.categories();
  } catch (_) {}
  try {
    await Notif.init();
    await Notif.rescheduleAll(await Repo.events(), await Repo.bills());
  } catch (_) {}
  runApp(const LifeSyncApp());
}

class LifeSyncApp extends StatelessWidget {
  const LifeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'LifeSync',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await UpdateService.autoEnabled() && mounted) {
        await UpdateService.check(context, silent: true);
      }
    });
  }

  static const _pages = [CalendarScreen(), FinanceScreen(), NotesScreen(), AnalyticsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _i, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Text('🗓️', style: TextStyle(fontSize: 22)), label: 'Lịch'),
          NavigationDestination(icon: Text('👛', style: TextStyle(fontSize: 22)), label: 'Tài chính'),
          NavigationDestination(icon: Text('📝', style: TextStyle(fontSize: 22)), label: 'Ghi chú'),
          NavigationDestination(icon: Text('📊', style: TextStyle(fontSize: 22)), label: 'Thống kê'),
        ],
      ),
    );
  }
}
