// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmin/services/notification_service.dart';
import 'package:pharmin/utils/snackbar_utils.dart';
import 'package:pharmin/widgets/glass_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _expiryAlerts = true;
  bool _lowStockAlerts = true;
  bool _dailySummary = true;
  bool _morningReport = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B),
              const Color(0xFF2C3E50),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALERT PREFERENCES',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _expiryAlerts,
                        onChanged: (value) {
                          setState(() => _expiryAlerts = value);
                          if (!value) {
                            SnackBarUtils.showInfo(
                              context,
                              'Expiry alerts disabled',
                            );
                          } else {
                            SnackBarUtils.showInfo(
                              context,
                              'Expiry alerts enabled',
                            );
                          }
                        },
                        title: const Text(
                          'Expiry Alerts',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Notify when medicines are expiring soon',
                          style: TextStyle(color: Colors.white60),
                        ),
                        activeColor: Colors.orange,
                        secondary: Icon(
                          Icons.warning_amber,
                          color: _expiryAlerts ? Colors.orange : Colors.white38,
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      SwitchListTile(
                        value: _lowStockAlerts,
                        onChanged: (value) {
                          setState(() => _lowStockAlerts = value);
                          if (!value) {
                            SnackBarUtils.showInfo(
                              context,
                              'Low stock alerts disabled',
                            );
                          } else {
                            SnackBarUtils.showInfo(
                              context,
                              'Low stock alerts enabled',
                            );
                          }
                        },
                        title: const Text(
                          'Low Stock Alerts',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Notify when stock is below reorder level',
                          style: TextStyle(color: Colors.white60),
                        ),
                        activeColor: Colors.red,
                        secondary: Icon(
                          Icons.error,
                          color: _lowStockAlerts ? Colors.red : Colors.white38,
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      SwitchListTile(
                        value: _dailySummary,
                        onChanged: (value) {
                          setState(() => _dailySummary = value);
                          if (!value) {
                            SnackBarUtils.showInfo(
                              context,
                              'Daily summary disabled',
                            );
                          } else {
                            SnackBarUtils.showInfo(
                              context,
                              'Daily summary enabled',
                            );
                          }
                        },
                        title: const Text(
                          'Daily Summary',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Receive daily business summary',
                          style: TextStyle(color: Colors.white60),
                        ),
                        activeColor: Colors.blue,
                        secondary: Icon(
                          Icons.summarize,
                          color: _dailySummary ? Colors.blue : Colors.white38,
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      SwitchListTile(
                        value: _morningReport,
                        onChanged: (value) {
                          setState(() => _morningReport = value);
                          if (!value) {
                            SnackBarUtils.showInfo(
                              context,
                              'Morning report disabled',
                            );
                          } else {
                            SnackBarUtils.showInfo(
                              context,
                              'Morning report enabled',
                            );
                          }
                        },
                        title: const Text(
                          'Morning Report',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Get a report every morning at 8 AM',
                          style: TextStyle(color: Colors.white60),
                        ),
                        activeColor: Colors.green,
                        secondary: Icon(
                          Icons.notifications_active,
                          color: _morningReport ? Colors.green : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.notifications_off,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'Disable All Notifications',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        subtitle: const Text(
                          'Turn off all notifications',
                          style: TextStyle(color: Colors.white60),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1A237E),
                              title: const Text(
                                'Disable All Notifications?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'This will turn off all notifications including expiry alerts, low stock alerts, and daily summaries.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _expiryAlerts = false;
                                      _lowStockAlerts = false;
                                      _dailySummary = false;
                                      _morningReport = false;
                                    });
                                    NotificationService().cancelAll();
                                    Navigator.pop(context);
                                    SnackBarUtils.showInfo(
                                      context,
                                      'All notifications disabled',
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  child: const Text('Disable All'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notifications run in the background. Make sure the app has permission to show notifications.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      SnackBarUtils.showSuccess(
                        context,
                        '✅ Notification settings saved!',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
