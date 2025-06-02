import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart'; // Import main.dart to access the callback

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request notification permission for Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Notification response received: ${response.actionId}, payload: ${response.payload}');
        if (response.actionId == 'view_action' && response.payload != null) {
          // Call the global callback function
          onViewActionCallback?.call();
        }
      },
    );
    print('NotificationService initialized');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    print('Showing notification: $title, $body, $payload');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'linknest_channel',
      'LinkNest Notifications',
      channelDescription: 'Notifications for shared links',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      actions: [
        AndroidNotificationAction(
          'view_action',
          'View',
          showsUserInterface: true,
        ),
      ],
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    print('Notification shown');
  }
}