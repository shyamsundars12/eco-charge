class UserModel {
  String id;
  String name;
  String email;
  String phone;
  String role; // 'user', 'owner', 'admin'

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  // Convert a Firestore document to a UserModel
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'user',
    );
  }

  // Convert a UserModel to a JSON object for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
    };
  }
}
