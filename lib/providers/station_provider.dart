import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ev_station_model.dart';

class StationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<EVStationModel> _stations = [];
  bool _isLoading = false;

  List<EVStationModel> get stations => _stations;
  bool get isLoading => _isLoading;

  /// Fetch all EV stations
  Future<void> fetchStations() async {
    try {
      _isLoading = true;
      notifyListeners();

      QuerySnapshot snapshot = await _firestore.collection('stations').get();
      _stations = snapshot.docs
          .map((doc) => EVStationModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Error fetching stations: $e");
    }
  }

  /// Add a new station
  Future<void> addStation(EVStationModel station) async {
    try {
      DocumentReference ref = _firestore.collection('stations').doc();
      await ref.set(station.toJson());
      _stations.add(station.copyWith(id: ref.id));
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding station: $e");
    }
  }

  /// Remove a station
  Future<void> removeStation(String stationId) async {
    try {
      await _firestore.collection('stations').doc(stationId).delete();
      _stations.removeWhere((station) => station.id == stationId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error removing station: $e");
    }
  }
}
