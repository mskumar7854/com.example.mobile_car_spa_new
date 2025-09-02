import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String staffId;
  final DateTime date;
  final bool isPresent;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.date,
    required this.isPresent,
  });

  // Convert Firestore document to AttendanceRecord
  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      isPresent: data['isPresent'] ?? false,
    );
  }

  // Convert Map to AttendanceRecord
  factory AttendanceRecord.fromMap(Map<String, dynamic> data, String documentId) {
    return AttendanceRecord(
      id: documentId,
      staffId: data['staffId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      isPresent: data['isPresent'] ?? false,
    );
  }

  // Convert AttendanceRecord to Map (for saving to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'date': Timestamp.fromDate(date),
      'isPresent': isPresent,
    };
  }
}
