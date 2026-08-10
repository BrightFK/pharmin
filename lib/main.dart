// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pharmin/providers/hive_provider.dart';
import 'package:pharmin/screens/splash_screen.dart';
import 'package:pharmin/services/hive_service.dart';
import 'package:pharmin/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize HiveProvider
  await HiveProvider.init();

  // Initialize HiveService
  await HiveService.init();

  // Initialize Notification Service
  await NotificationService().init();

  // Schedule morning report
  await NotificationService().scheduleMorningReport();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmIn',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue.shade900,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Use SplashScreen as home
      navigatorKey: NotificationService.navigatorKey,
    );
  }
}
