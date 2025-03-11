import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createBooking(String userId, String stationId, String slotTime, double amount) async {
    DocumentReference bookingRef = _db.collection('bookings').doc();
    await bookingRef.set({
      'user_id': userId,
      'station_id': stationId,
      'slot_time': slotTime,
      'status': 'Pending',
      'amount_paid': amount,
      'created_at': FieldValue.serverTimestamp(),
    });
    return bookingRef.id;
  }

  Future<void> updateBookingStatus(String bookingId, String status) {
    return _db.collection('bookings').doc(bookingId).update({'status': status});
  }

  Stream<QuerySnapshot> getUserBookings(String userId) {
    return _db.collection('bookings').where('user_id', isEqualTo: userId).snapshots();
  }

  Stream<QuerySnapshot> getStationBookings(String stationId) {
    return _db.collection('bookings').where('station_id', isEqualTo: stationId).snapshots();
  }
}
