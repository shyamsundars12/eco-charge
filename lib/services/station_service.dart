import 'package:cloud_firestore/cloud_firestore.dart';

class StationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addStation(String name, String location, double latitude, double longitude, String ownerId) {
    return _db.collection('stations').add({
      'name': name,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'owner_id': ownerId,
      'status': 'active',
    });
  }

  Future<void> updateStation(String stationId, Map<String, dynamic> data) {
    return _db.collection('stations').doc(stationId).update(data);
  }

  Future<void> deleteStation(String stationId) {
    return _db.collection('stations').doc(stationId).delete();
  }

  Stream<QuerySnapshot> getStationsStream() {
    return _db.collection('stations').snapshots();
  }
}
