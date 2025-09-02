import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollRecord {
  final String id;
  final String staffId;
  final String staffName;
  final double baseSalary;
  final int daysPresent;
  final int totalDaysInMonth;
  final double bonus;
  final double deductions;

  PayrollRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.baseSalary,
    required this.daysPresent,
    required this.totalDaysInMonth,
    this.bonus = 0.0,
    this.deductions = 0.0,
  });

  /// Formula for payroll
  double get amount {
    final dailyRate = baseSalary / totalDaysInMonth;
    return (dailyRate * daysPresent) - deductions + bonus;
  }

  factory PayrollRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return PayrollRecord(
      id: id,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      baseSalary: (data['baseSalary'] ?? 0).toDouble(),
      daysPresent: data['daysPresent'] ?? 0,
      totalDaysInMonth: data['totalDaysInMonth'] ?? 30,
      bonus: (data['bonus'] ?? 0).toDouble(),
      deductions: (data['deductions'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'baseSalary': baseSalary,
      'daysPresent': daysPresent,
      'totalDaysInMonth': totalDaysInMonth,
      'bonus': bonus,
      'deductions': deductions,
    };
  }
}
