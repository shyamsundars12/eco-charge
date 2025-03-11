import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Add an EV Owner (Admin assigns an owner)
  Future<void> addEVOwner(String ownerId, String email, String name, String phone) async {
    await _db.collection('ev_owners').doc(ownerId).set({
      'email': email,
      'name': name,
      'phone': phone,
    });
  }

  /// Add an EV Station (Assigned to an Owner)
  Future<void> addEVStation(String stationId, String name, double lat, double lng, String ownerEmail) async {
    await _db.collection('ev_stations').doc(stationId).set({
      'name': name,
      'location': {'latitude': lat, 'longitude': lng},
      'ownerEmail': ownerEmail,
      'availableSlots': 5,
      'status': "Active",
    });
  }

  /// Add a Charging Slot under a Station & Date
  Future<void> addChargingSlot(String stationId, String date, String slotId, String time) async {
    await _db
        .collection('charging_slots')
        .doc(stationId)
        .collection(date)
        .doc(slotId) // <-- Fix: Slot ID should be a document inside a collection
        .set({
      'time': time,
      'isBooked': false,
      'bookedBy': null,
    });
  }

  /// Add a Booking (User books a slot)
  Future<void> addBooking(String bookingId, String stationId, String userId, String slotTime, String ownerEmail) async {
    await _db.collection('bookings').doc(bookingId).set({
      'stationId': stationId,
      'userId': userId,
      'slotTime': slotTime,
      'ownerEmail': ownerEmail,
    });
  }
}
