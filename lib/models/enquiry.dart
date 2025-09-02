import 'package:cloud_firestore/cloud_firestore.dart';

class Enquiry {
  final String? id;
  final int? invoiceNumber;
  final String customerName;
  final String phoneNumber;
  final String vehicleType;
  final String vehicleModel;
  final String services;
  final double totalPrice;
  final String source;
  final String status;
  final String? followUpDate; // ISO string or null
  final String? location;
  final String? notes;
  final String date; // Stored as yyyy-MM-dd string across the app

  Enquiry({
    this.id,
    this.invoiceNumber,
    required this.customerName,
    required this.phoneNumber,
    required this.vehicleType,
    required this.vehicleModel,
    required this.services,
    required this.totalPrice,
    required this.source,
    required this.status,
    this.followUpDate,
    this.location,
    this.notes,
    required this.date,
  });

  // From Firestore
  factory Enquiry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Enquiry(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as int?,
      customerName: (data['customerName'] as String?) ?? '',
      phoneNumber: (data['phoneNumber'] as String?) ?? '',
      vehicleType: (data['vehicleType'] as String?) ?? '',
      vehicleModel: (data['vehicleModel'] as String?) ?? '',
      services: (data['services'] as String?) ?? '',
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      source: (data['source'] as String?) ?? '',
      status: (data['status'] as String?) ?? '',
      followUpDate: data['followUpDate'] as String?,
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      date: (data['date'] as String?) ?? '',
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'services': services,
      'totalPrice': totalPrice,
      'source': source,
      'status': status,
      'followUpDate': followUpDate,
      'location': location,
      'notes': notes,
      'date': date,
    };
  }

  Enquiry copyWith({
    String? id,
    int? invoiceNumber,
    String? customerName,
    String? phoneNumber,
    String? vehicleType,
    String? vehicleModel,
    String? services,
    double? totalPrice,
    String? source,
    String? status,
    String? followUpDate,
    String? location,
    String? notes,
    String? date,
  }) {
    return Enquiry(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      services: services ?? this.services,
      totalPrice: totalPrice ?? this.totalPrice,
      source: source ?? this.source,
      status: status ?? this.status,
      followUpDate: followUpDate ?? this.followUpDate,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      date: date ?? this.date,
    );
  }
}
