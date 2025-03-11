class BookingModel {
  String id;
  String userId;
  String stationId;
  String slotId;
  DateTime bookingTime;
  String status; // 'pending', 'confirmed', 'cancelled'

  BookingModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.slotId,
    required this.bookingTime,
    required this.status,
  });

  // Convert Firestore document to BookingModel
  factory BookingModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BookingModel(
      id: id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      slotId: data['slotId'] ?? '',
      bookingTime: DateTime.tryParse(data['bookingTime'] ?? '') ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  // Convert BookingModel to a JSON object for Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'stationId': stationId,
      'slotId': slotId,
      'bookingTime': bookingTime.toIso8601String(),
      'status': status,
    };
  }

  // CopyWith method for updating specific fields
  BookingModel copyWith({
    String? id,
    String? userId,
    String? stationId,
    String? slotId,
    DateTime? bookingTime,
    String? status,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      slotId: slotId ?? this.slotId,
      bookingTime: bookingTime ?? this.bookingTime,
      status: status ?? this.status,
    );
  }
}
