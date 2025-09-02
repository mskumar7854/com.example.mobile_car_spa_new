import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/staff_model.dart';

class StaffPayrollScreen extends StatelessWidget {
  final Staff staff;
  const StaffPayrollScreen({Key? key, required this.staff}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final payrollRef = FirebaseFirestore.instance
        .collection('staff')
        .doc(staff.id)
        .collection('payroll')
        .orderBy('month', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text('${staff.name} Payroll')),
      body: StreamBuilder<QuerySnapshot>(
        stream: payrollRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No payroll records yet'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final month = data['month'] ?? '';
              final baseSalary = (data['baseSalary'] as num?)?.toDouble() ?? 0.0;
              final bonuses = (data['bonuses'] as num?)?.toDouble() ?? 0.0;
              final deductions = (data['deductions'] as num?)?.toDouble() ?? 0.0;
              final netPay = (data['netPay'] as num?)?.toDouble() ?? 0.0;
              final generatedDateTs = data['generatedDate'] as Timestamp?;
              final generatedDate = generatedDateTs?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text('Month: $month'),
                  subtitle: Text(
                    'Base Salary: ₹${baseSalary.toStringAsFixed(2)}\n'
                    'Bonuses: ₹${bonuses.toStringAsFixed(2)}\n'
                    'Deductions: ₹${deductions.toStringAsFixed(2)}\n'
                    'Generated: ${generatedDate != null ? generatedDate.toLocal().toString().split(" ")[0] : "N/A"}',
                  ),
                  trailing: Text('Net Pay\n₹${netPay.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGeneratePayrollDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Generate Payroll',
      ),
    );
  }

  void _showGeneratePayrollDialog(BuildContext context) async {
    final baseSalary = staff.salary;
    final bonusCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Payroll'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Base Salary: ₹${baseSalary.toStringAsFixed(2)}'),
              TextFormField(
                controller: bonusCtrl,
                decoration: const InputDecoration(labelText: 'Bonuses (₹)'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter bonuses or 0';
                  if (double.tryParse(val) == null) return 'Enter valid number';
                  return null;
                },
              ),
              TextFormField(
                controller: deductionCtrl,
                decoration: const InputDecoration(labelText: 'Deductions (₹)'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter deductions or 0';
                  if (double.tryParse(val) == null) return 'Enter valid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final bonus = double.tryParse(bonusCtrl.text.trim()) ?? 0.0;
    final deduction = double.tryParse(deductionCtrl.text.trim()) ?? 0.0;
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final dailyRate = baseSalary / DateTime(now.year, now.month + 1, 0).day;
    // For simplicity, assuming full month present for the generated payroll
    final earned = baseSalary; 

    final netPay = earned + bonus - deduction;

    await FirebaseFirestore.instance
        .collection('staff')
        .doc(staff.id)
        .collection('payroll')
        .doc(monthKey)
        .set({
      'month': monthKey,
      'baseSalary': baseSalary,
      'bonuses': bonus,
      'deductions': deduction,
      'netPay': netPay,
      'generatedDate': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll generated successfully')));
    }
  }
}
