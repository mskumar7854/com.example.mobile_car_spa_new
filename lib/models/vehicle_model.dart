import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String? id; // Firestore doc ID
  final int brandId;
  final String name;

  VehicleModel({
    this.id,
    required this.brandId,
    required this.name,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return VehicleModel(
      id: id,
      brandId: _asInt(map['brand_id']),
      name: (map['name'] ?? '').toString(),
    );
  }

  factory VehicleModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return VehicleModel.fromMap(doc.data()!, id: doc.id);
  }

  Map<String, dynamic> toFirestore() => {
        'brand_id': brandId,
        'name': name,
      };
}
