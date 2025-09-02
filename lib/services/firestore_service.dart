import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enquiry.dart';
import '../models/expense.dart';
import '../models/service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get enquiriesRef => _db.collection('enquiries');
  CollectionReference<Map<String, dynamic>> get expensesRef => _db.collection('expenses');
  CollectionReference<Map<String, dynamic>> get servicesRef => _db.collection('services');
  CollectionReference<Map<String, dynamic>> get countersRef => _db.collection('counters');

  // Enquiry CRUD
  Future<void> addEnquiry(Enquiry enquiry) {
    return enquiriesRef.add(enquiry.toFirestore());
  }

  Future<void> updateEnquiry(Enquiry enquiry) {
    if (enquiry.id == null) {
      throw ArgumentError('Enquiry id cannot be null for update');
    }
    return enquiriesRef.doc(enquiry.id!).update(enquiry.toFirestore());
  }

  Future<void> deleteEnquiry(String id) {
    return enquiriesRef.doc(id).delete();
  }

  Stream<List<Enquiry>> getEnquiries() {
    return enquiriesRef.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Enquiry.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  // Expense CRUD
  Future<void> addExpense(Expense expense) {
    return expensesRef.add(expense.toFirestore());
  }

  Future<void> updateExpense(Expense expense) {
    if (expense.id == null) {
      throw ArgumentError('Expense id cannot be null for update');
    }
    return expensesRef.doc(expense.id!).update(expense.toFirestore());
  }

  Future<void> deleteExpense(String id) {
    return expensesRef.doc(id).delete();
  }

  Stream<List<Expense>> getExpenses() {
    return expensesRef.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Expense.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  // Service CRUD
  Future<void> addService(Service service) {
    return servicesRef.add(service.toFirestore());
  }

  Future<void> updateService(Service service) {
    if (service.id == null) {
      throw ArgumentError('Service id cannot be null for update');
    }
    return servicesRef.doc(service.id!).update(service.toFirestore());
  }

  Future<void> deleteService(String id) {
    return servicesRef.doc(id).delete();
  }

  Stream<List<Service>> getServices() {
    return servicesRef.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  // Auto-increment Invoice Number
  Future<int> getNextInvoiceNumber() async {
    final DocumentReference<Map<String, dynamic>> counterDoc = countersRef.doc('invoiceCounter');
    return _db.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterDoc);
      int current = 0;
      if (snapshot.exists) {
        current = (snapshot.data()?['current'] as int?) ?? 0;
      }
      final next = current + 1;
      transaction.set(counterDoc, {'current': next});
      return next;
    });
  }
}
