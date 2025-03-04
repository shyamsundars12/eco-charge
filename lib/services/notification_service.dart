// import 'dart:async';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// class NotificationService {
//   static final FlutterLocalNotificationsPlugin _notificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   static Future<void> init() async {
//     const AndroidInitializationSettings androidSettings =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings settings =
//     InitializationSettings(android: androidSettings);
//
//     await _notificationsPlugin.initialize(settings);
//   }
//
//   // Show instant notification
//   static Future<void> showNotification() async {
//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       'reminder_channel',
//       'Reminder Notifications',
//       importance: Importance.high,
//       priority: Priority.high,
//     );
//
//     const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
//
//     await _notificationsPlugin.show(
//       0,
//       'Reminder!',
//       'Your EV charging station is nearby!',
//       platformDetails,
//     );
//   }
//
//   // Schedule repeating notification every 5 minutes
//   static void scheduleRepeatingNotifications() {
//     Timer.periodic(const Duration(minutes: 5), (timer) async {
//       await showNotification();
//     });
//   }
// }
