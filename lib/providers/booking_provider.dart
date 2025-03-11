import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<BookingModel> _bookings = [];
  bool _isLoading = false;

  List<BookingModel> get bookings => _bookings;
  bool get isLoading => _isLoading;

  /// Fetch user bookings
  Future<void> fetchUserBookings(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      _bookings = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BookingModel.fromFirestore(data, doc.id); // ✅ FIXED
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("🔥 Error fetching bookings: $e");
    }
  }

  /// Create a new booking
  Future<void> createBooking(BookingModel booking) async {
    try {
      DocumentReference ref = _firestore.collection('bookings').doc();
      await ref.set(booking.toJson());

      // ✅ Add the booking with generated ID
      _bookings.add(booking.copyWith(id: ref.id));
      notifyListeners();
    } catch (e) {
      debugPrint("🔥 Error creating booking: $e");
    }
  }

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
      _bookings.removeWhere((booking) => booking.id == bookingId);
      notifyListeners();
    } catch (e) {
      debugPrint("🔥 Error canceling booking: $e");
    }
  }
}
