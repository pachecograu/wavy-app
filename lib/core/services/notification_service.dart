import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _id = 0;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  static Future<void> showChatNotification(String message) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'wavy_chat',
        'Chat WAVY',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFDC143C),
        playSound: true,
      ),
    );
    await _plugin.show(_id++, 'Nuevo mensaje', message, details);
  }
}
