import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/screen/secondary/splash_screen.dart';
import 'package:tasktracker/service/bottomnav/bottom_provider.dart';
import 'package:tasktracker/service/category/provider/category_provider.dart';
import 'package:tasktracker/service/note/provider/notes_provider.dart';
import 'package:tasktracker/service/notification/provider/notification_provider.dart';
import 'package:tasktracker/service/notification/service/notification_service.dart';
import 'package:tasktracker/service/setting/setting_provider.dart';
import 'package:tasktracker/service/task/provider/task_provider.dart';
import 'package:tasktracker/service/todo/provider/todo_provider.dart';
import 'package:tasktracker/theme/theme.dart';
import 'package:tasktracker/theme/theme_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tasktracker/service/subscription/subscription_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp();

  await MobileAds.instance.initialize();

  tz.initializeTimeZones();

  await NotificationService.instance.initialize();

  // Initialize all providers
  final notificationProvider = NotificationProvider();
  final categoryProvider = CategoryProvider();
  final settingsProvider = SettingsProvider();
  final taskProvider = TaskProvider.instance;

  await Future.wait([
    notificationProvider.loadNotifications(),
    categoryProvider.loadCategories(),
    settingsProvider.initialize(),
    taskProvider.initialize(),
  ]);

  NotificationService.instance.fiveMinuteReminderEnabled =
      settingsProvider.fiveMinuteReminderEnabled;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => NoteProvider()..loadNotes()),
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<NotificationProvider>(
              context,
              listen: false,
            );
            NotificationService.instance.setProvider(provider);
            debugPrint('✅ NotificationService provider set');
          });

          return const MyApp();
        },
      ),
    ),
  );
}

// THIS IS THE KEY — Rebuild entire app when SettingsProvider changes
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Task Tracker',
          theme: AppTheme.light(context),
          darkTheme: AppTheme.dark(context),
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
