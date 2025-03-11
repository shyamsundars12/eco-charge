import 'package:cloud_firestore/cloud_firestore.dart';

class SlotService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addSlot(String stationId, String time) {
    return _db.collection('charging_slots').doc(stationId).collection('slots').add({
      'time': time,
      'status': 'available',
    });
  }

  Future<void> updateSlotStatus(String stationId, String slotId, String status) {
    return _db.collection('charging_slots').doc(stationId).collection('slots').doc(slotId).update({
      'status': status,
    });
  }

  Future<void> deleteSlot(String stationId, String slotId) {
    return _db.collection('charging_slots').doc(stationId).collection('slots').doc(slotId).delete();
  }

  Stream<QuerySnapshot> getAvailableSlots(String stationId) {
    return _db.collection('charging_slots').doc(stationId).collection('slots')
        .where('status', isEqualTo: 'available').snapshots();
  }
}
