import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initNotifications() async {
    // Android settings
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Combine settings
    final InitializationSettings initializationSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    // Initialize notifications
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Function to show a random notification
  Future<void> showRandomNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'random_channel', // Channel ID
      'Random Notifications', // Channel Name
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails, iOS: iosNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      2, // Notification ID
      '🔔 EcoCharge Update', // Title
      'This is a random notification for EcoCharge users.', // Body
      notificationDetails,
    );
  }

  // Function to show a booking confirmation notification
  Future<void> showBookingNotification(String stationName) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'booking_channel', // Channel ID
      'Booking Notifications', // Channel Name
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails, iOS: iosNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      3, // Notification ID
      '✅ Booking Confirmed!', // Title
      'Your EV charging slot at $stationName has been successfully booked.', // Body
      notificationDetails,
    );
  }
}
