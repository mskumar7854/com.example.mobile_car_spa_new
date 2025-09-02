import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id;
  final String name;
  final double salary;
  final String phone;
  final String role;

  Staff({
    required this.id,
    required this.name,
    required this.salary,
    required this.phone,
    required this.role,
  });

  // Convert Firestore document to Staff object
  factory Staff.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Staff(
      id: doc.id,
      name: data['name'] ?? '',
      salary: (data['salary'] ?? 0).toDouble(),
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
    );
  }

  // Convert Map to Staff object
  factory Staff.fromMap(Map<String, dynamic> data, String documentId) {
    return Staff(
      id: documentId,
      name: data['name'] ?? '',
      salary: (data['salary'] ?? 0).toDouble(),
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
    );
  }

  // Convert Staff object to Map (for saving to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'salary': salary,
      'phone': phone,
      'role': role,
    };
  }
}
