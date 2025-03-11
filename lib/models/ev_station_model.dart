class EVStationModel {
  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;

  EVStationModel({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  /// Factory constructor to create from Firestore document
  factory EVStationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return EVStationModel(
      id: id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
    );
  }

  /// Convert EVStationModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// CopyWith method to update fields
  EVStationModel copyWith({
    String? id,
    String? name,
    String? location,
    double? latitude,
    double? longitude,
  }) {
    return EVStationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Convert EVStationModel to a Map for easy debugging
  @override
  String toString() {
    return 'EVStationModel(id: $id, name: $name, location: $location, latitude: $latitude, longitude: $longitude)';
  }
}