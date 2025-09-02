import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String? id;
  final String name;
  final double price;
  final String vehicleType;

  Service({
    this.id,
    required this.name,
    required this.price,
    required this.vehicleType,
  });

  factory Service.fromMap(Map<String, dynamic> map, {String? id}) {
    return Service(
      id: id,
      name: (map['name'] as String?) ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0,
      vehicleType: (map['vehicleType'] as String?) ?? '',
    );
  }

  factory Service.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Service.fromMap(doc.data()!, id: doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'vehicleType': vehicleType,
    };
  }
}
