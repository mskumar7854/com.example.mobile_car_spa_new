import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/staff_model.dart';

class PayrollListScreen extends StatelessWidget {
  PayrollListScreen({Key? key}) : super(key: key);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper to get total net pay per staff for this month
  Future<double> _staffTotalNetPayThisMonth(String staffId) async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final docSnap = await _firestore
        .collection('staff')
        .doc(staffId)
        .collection('payroll')
        .doc(monthKey)
        .get();

    if (docSnap.exists) {
      final data = docSnap.data()!;
      return (data['netPay'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll Summary')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('staff').orderBy('name').snapshots(),
        builder: (context, staffSnapshot) {
          if (staffSnapshot.hasError) return Center(child: Text('Error: ${staffSnapshot.error}'));
          if (!staffSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final staffDocs = staffSnapshot.data!.docs;
          if (staffDocs.isEmpty) return const Center(child: Text('No staff data'));

          return ListView.builder(
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final staff = Staff.fromFirestore(staffDocs[index]);
              return FutureBuilder<double>(
                future: _staffTotalNetPayThisMonth(staff.id),
                builder: (context, netPaySnapshot) {
                  if (!netPaySnapshot.hasData) return const ListTile(title: Text('Loading...'));
                  final netPay = netPaySnapshot.data ?? 0.0;
                  return ListTile(
                    leading: CircleAvatar(child: Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?')),
                    title: Text(staff.name),
                    subtitle: Text('Role: ${staff.role}'),
                    trailing: Text('Net Pay: ₹${netPay.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      // Navigate to StaffPayrollScreen to view details
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffPayrollScreen(staff: staff),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
