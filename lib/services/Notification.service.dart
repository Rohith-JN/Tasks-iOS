import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  DarwinNotificationDetails iOSPlatformChannelSpecifics =
      const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: false);

  Future<void> initNotification() async {
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(iOS: initializationSettingsDarwin);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(
      int id, String? title, String? body, time) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(id, title, body, time,
        NotificationDetails(iOS: iOSPlatformChannelSpecifics),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: false);
  }
}

// Method definition for 'setRegisterPlugins:' not found