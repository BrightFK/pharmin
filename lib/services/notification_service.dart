// lib/services/notification_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import '../models/transaction.dart';
import '../providers/hive_provider.dart';
import '../services/hive_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _dailyCheckTimer;
  bool _isInitialized = false;
  bool _hasPermission = false;

  // Global navigator key for handling notification taps
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Initialize the notification plugin
  Future<void> init() async {
    if (_isInitialized) return;

    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization with permission requests
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    _isInitialized = true;

    // Create notification channel for Android
    await _createNotificationChannel();

    // Check permissions
    await _checkAndRequestPermissions();

    // Schedule daily checks
    _scheduleDailyCheck();
  }

  // Create notification channel (Android 8+)
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pharmin_channel',
      'PharmIn Alerts',
      description: 'Medicine expiry and stock alerts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Check and request permissions using native methods
  Future<void> _checkAndRequestPermissions() async {
    try {
      // For Android
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        // Check if notifications are enabled
        final enabled = await androidPlugin.areNotificationsEnabled();
        _hasPermission = enabled ?? false;

        if (!_hasPermission) {
          // Request permission for Android 13+
          final permissionGranted = await androidPlugin
              .requestNotificationsPermission();
          _hasPermission = permissionGranted ?? false;

          if (!_hasPermission) {
            // Check again after request
            final recheck = await androidPlugin.areNotificationsEnabled();
            _hasPermission = recheck ?? false;
          }
        }
      }

      // For iOS
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosPlugin != null) {
        final permissions = await iosPlugin.checkPermissions();
        _hasPermission = permissions?.isEnabled ?? false;

        if (!_hasPermission) {
          // Request iOS permissions
          final requested = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
            provisional: false,
          );
          _hasPermission = requested ?? false;
        }
      }
    } catch (e) {
      print('Error checking notification permissions: $e');
      // If we can't check permissions, assume they're granted for older devices
      _hasPermission = true;
    }
  }

  // Handle notification tap when app is in foreground
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.startsWith('medicine_')) {
      // Navigate to medicine detail
      final medicineId = payload.replaceFirst('medicine_', '');
      _navigateToMedicineDetail(medicineId);
    }
  }

  // Handle notification tap when app is in background
  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    // Handle background notification tap
    // This runs in a separate isolate
    print('Background notification tapped: ${response.payload}');
  }

  // Navigation helper
  void _navigateToMedicineDetail(String medicineId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate to medicine detail screen
      // You can implement navigation here
    }
  }

  // Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Try to get permission if not already granted
    if (!_hasPermission) {
      await _checkAndRequestPermissions();
      if (!_hasPermission) {
        // Silently fail if permission denied
        return;
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'pharmin_channel',
          'PharmIn Alerts',
          channelDescription: 'Medicine expiry and stock alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          styleInformation: const BigTextStyleInformation(''),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  // Check for expiring medicines and low stock
  Future<void> checkAndSendAlerts() async {
    try {
      final batchBox = Hive.box<Batch>(HiveProvider.batchesBox);
      final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
      final now = DateTime.now();

      final expiringBatches = <Map<String, dynamic>>[];
      final lowStockItems = <Map<String, dynamic>>[];

      // Check expiry
      for (var batch in batchBox.values) {
        if (batch.quantity <= 0) continue;

        final medicine = medBox.get(batch.medicineId);
        if (medicine == null) continue;

        final daysLeft = batch.expiryDate.difference(now).inDays;

        if (daysLeft <= 30 && daysLeft >= 0) {
          expiringBatches.add({
            'medicine': medicine,
            'batch': batch,
            'daysLeft': daysLeft,
          });
        }
      }

      // Check low stock
      for (var medicine in medBox.values) {
        final stock = HiveService.availableStock(medicine.id);
        if (stock <= medicine.defaultReorderLevel) {
          lowStockItems.add({'medicine': medicine, 'stock': stock});
        }
      }

      // Send alerts
      await _sendExpiryAlerts(expiringBatches);
      await _sendLowStockAlerts(lowStockItems);
      await _sendDailySummary(expiringBatches, lowStockItems);
    } catch (e) {
      print('Error checking alerts: $e');
    }
  }

  // Send expiry alerts
  Future<void> _sendExpiryAlerts(
    List<Map<String, dynamic>> expiringBatches,
  ) async {
    if (expiringBatches.isEmpty) return;

    final critical = expiringBatches.where((b) => b['daysLeft'] <= 7).toList();
    final warning = expiringBatches
        .where((b) => b['daysLeft'] > 7 && b['daysLeft'] <= 30)
        .toList();

    // Critical alerts - separate notifications
    for (var batch in critical) {
      final medicine = batch['medicine'] as Medicine;
      final daysLeft = batch['daysLeft'] as int;

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '🚨 CRITICAL: ${medicine.name} Expiring Soon!',
        body:
            'Batch ${(batch['batch'] as Batch).batchNumber ?? 'N/A'} expires in $daysLeft days.',
        payload: 'medicine_${medicine.id}',
      );

      await Future.delayed(const Duration(seconds: 1));
    }

    // Warning alert - grouped
    if (warning.isNotEmpty) {
      final titles = warning
          .map((b) {
            final med = b['medicine'] as Medicine;
            final days = b['daysLeft'] as int;
            return '$med.name ($days days)';
          })
          .join('\n');

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        title: '⚠️ Medicines Expiring Soon',
        body: 'The following medicines will expire within 30 days:\n$titles',
      );
    }
  }

  // Send low stock alerts
  Future<void> _sendLowStockAlerts(
    List<Map<String, dynamic>> lowStockItems,
  ) async {
    if (lowStockItems.isEmpty) return;

    final outOfStock = lowStockItems
        .where((item) => item['stock'] == 0)
        .toList();
    final lowStock = lowStockItems.where((item) => item['stock'] > 0).toList();

    // Out of stock - separate notifications
    for (var item in outOfStock) {
      final medicine = item['medicine'] as Medicine;

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 200,
        title: '🚨 OUT OF STOCK: ${medicine.name}',
        body:
            '${medicine.name} is completely out of stock! Reorder immediately.',
        payload: 'medicine_${medicine.id}',
      );

      await Future.delayed(const Duration(seconds: 1));
    }

    // Low stock warning - grouped
    if (lowStock.isNotEmpty) {
      final titles = lowStock
          .map((item) {
            final med = item['medicine'] as Medicine;
            final stock = item['stock'] as double;
            return '$med.name (${stock.toStringAsFixed(2)} units left)';
          })
          .join('\n');

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
        title: '⚠️ Low Stock Alert',
        body: 'The following medicines are below reorder level:\n$titles',
      );
    }
  }

  // Send daily summary
  Future<void> _sendDailySummary(
    List<Map<String, dynamic>> expiringBatches,
    List<Map<String, dynamic>> lowStockItems,
  ) async {
    final now = DateTime.now();
    final medBox = Hive.box<Medicine>(HiveProvider.medicinesBox);
    final transactionBox = Hive.box<Transaction>(HiveProvider.transactionsBox);

    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySales = transactionBox.values
        .where((t) => t.type == 'sale' && t.date.isAfter(todayStart))
        .toList();

    final totalSales = todaySales.fold<double>(
      0.0,
      (sum, t) => sum + t.totalAmount,
    );
    final totalMedicines = medBox.values.length;

    String summary = 'Here is your daily summary';
    summary += 'Total Medicines: $totalMedicines\n';
    summary += 'Today\'s Sales: \$${totalSales.toStringAsFixed(2)}\n';
    summary += 'Sales Count: ${todaySales.length}\n';
    summary += 'Low Stock Items: ${lowStockItems.length}\n';
    summary += 'Expiring Soon: ${expiringBatches.length}\n';

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 400,
      title: '📊 Daily Pharmacy Summary',
      body: summary,
    );
  }

  // Schedule daily check
  void _scheduleDailyCheck() {
    _dailyCheckTimer?.cancel();

    // Check every 6 hours
    _dailyCheckTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      await checkAndSendAlerts();
    });

    // Initial check after 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      await checkAndSendAlerts();
    });
  }

  // Schedule morning report at 8 AM
  Future<void> scheduleMorningReport() async {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, 6, 10);
    final delay = scheduledTime.isAfter(now)
        ? scheduledTime.difference(now)
        : scheduledTime.add(const Duration(days: 1)).difference(now);

    Timer(delay, () async {
      await checkAndSendAlerts();
      // Reschedule for next day
      scheduleMorningReport();
    });
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    _dailyCheckTimer?.cancel();
  }

  // Dispose
  void dispose() {
    _dailyCheckTimer?.cancel();
  }
}
