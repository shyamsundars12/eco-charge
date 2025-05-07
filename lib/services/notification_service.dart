import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initNotifications() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        if (response.payload != null) {
          final parts = response.payload!.split('|');
          if (parts.length == 2 && parts[0] == 'cancel_booking') {
            await _cancelBooking(parts[1]);
          }
        }
      },
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      // Get booking details
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) return;

      Map<String, dynamic> booking = bookingDoc.data() as Map<String, dynamic>;

      // Get slot document
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .get();

      if (!slotDoc.exists) return;

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      // Find and update the charging point status
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == booking['point_id']) {
          chargingPoints[i]['status'] = 'available';
          chargingPoints[i]['booked_by'] = null;
          chargingPoints[i]['pending_by'] = null;
          chargingPoints[i]['updated_at'] = DateTime.now().toIso8601String();
          break;
        }
      }

      // Update the slot
      await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Show cancellation confirmation notification
      await showCancellationNotification(booking['station_name'] ?? 'Unknown Station');
    } catch (e) {
      print('Error cancelling booking: $e');
    }
  }

  Future<void> showCancellationNotification(String stationName) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'cancellation_channel',
      'Cancellation Notifications',
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
      5,
      '❌ Booking Cancelled',
      'Your booking at $stationName has been cancelled.',
      notificationDetails,
    );
  }

  // Function to show a booking confirmation notification
  Future<void> showBookingNotification(String stationName, String bookingId) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      actions: [
        AndroidNotificationAction('cancel', 'Cancel Booking'),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails, iOS: iosNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      3,
      '✅ Booking Confirmed!',
      'Your EV charging slot at $stationName has been successfully booked.',
      notificationDetails,
      payload: 'cancel_booking|$bookingId',
    );
  }

  // Function to schedule a reminder notification 1 hour before the booking
  Future<void> scheduleReminderNotification(String bookingId, String stationName, DateTime bookingTime) async {
    DateTime reminderTime = bookingTime.subtract(const Duration(hours: 1));
    
    if (reminderTime.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        int.parse(bookingId.hashCode.toString().replaceAll('-', '')),
        '⏰ Booking Reminder',
        'Your charging slot at $stationName is in 1 hour. Please confirm if you will arrive.',
        tz.TZDateTime.from(reminderTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminder Notifications',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction('cancel', 'Cancel Booking'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'cancel_booking|$bookingId',
      );
    }
  }

  // Function to show geofencing notification when user is near the station
  Future<void> showGeofencingNotification(String stationName, String bookingId) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      actions: [
        AndroidNotificationAction('cancel', 'Cancel Booking'),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails, iOS: iosNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      4,
      '📍 You\'re Near Your Charging Station',
      'You have arrived at $stationName. Your booking is active.',
      notificationDetails,
      payload: 'cancel_booking|$bookingId',
    );
  }

  // Function to check if user is within geofence radius
  Future<bool> isWithinGeofence(double stationLat, double stationLng, double radiusInMeters) async {
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        stationLat,
        stationLng,
      );

      return distanceInMeters <= radiusInMeters;
    } catch (e) {
      print('Error checking geofence: $e');
      return false;
    }
  }
}
