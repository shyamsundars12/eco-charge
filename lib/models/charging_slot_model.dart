class ChargingSlotModel {
  String id;
  String stationId;
  String slotNumber;
  bool isAvailable;
  String bookedBy; // User ID of the person who booked it
  DateTime? bookedUntil; // Timestamp when the slot will be released

  ChargingSlotModel({
    required this.id,
    required this.stationId,
    required this.slotNumber,
    required this.isAvailable,
    required this.bookedBy,
    this.bookedUntil,
  });

  // Convert Firestore document to ChargingSlotModel
  factory ChargingSlotModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChargingSlotModel(
      id: id,
      stationId: data['stationId'] ?? '',
      slotNumber: data['slotNumber'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      bookedBy: data['bookedBy'] ?? '',
      bookedUntil: data['bookedUntil'] != null
          ? DateTime.parse(data['bookedUntil'])
          : null,
    );
  }

  // Convert ChargingSlotModel to a JSON object for Firestore
  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'slotNumber': slotNumber,
      'isAvailable': isAvailable,
      'bookedBy': bookedBy,
      'bookedUntil': bookedUntil?.toIso8601String(),
    };
  }
}
