import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String? category;
  final String? notes;
  final DateTime date; // Stored in Firestore as Timestamp
  final double amount;

  Expense({
    this.id,
    this.category,
    this.notes,
    required this.date,
    required this.amount,
  });

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Expense(
      id: doc.id,
      category: data['category'] as String?,
      notes: data['notes'] as String?,
      date: (data['date'] as Timestamp).toDate(),
      amount: (data['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      'date': Timestamp.fromDate(date),
      'amount': amount,
    };
  }
}
