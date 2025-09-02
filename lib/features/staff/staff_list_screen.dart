import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff_model.dart';
import 'staff_detail_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({Key? key}) : super(key: key);

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> _showAddEditDialog({Staff? staff}) async {
    final nameCtrl = TextEditingController(text: staff?.name ?? '');
    final roleCtrl = TextEditingController(text: staff?.role ?? '');
    final phoneCtrl = TextEditingController(text: staff?.phone ?? '');
    final salaryCtrl = TextEditingController(text: staff != null ? staff.salary.toString() : '');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter name' : null,
                ),
                TextFormField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'Role'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter role' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter phone' : null,
                ),
                TextFormField(
                  controller: salaryCtrl,
                  decoration: const InputDecoration(labelText: 'Monthly Salary'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter salary';
                    if (double.tryParse(value) == null) return 'Enter valid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (result != true) return;

    final data = {
      'name': nameCtrl.text.trim(),
      'role': roleCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
    };

    try {
      if (staff == null) {
        await firestore.collection('staff').add(data);
      } else {
        await firestore.collection('staff').doc(staff.id).update(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save staff: $e')));
      }
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    try {
      await firestore.collection('staff').doc(staffId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff List')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffListDashboard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Text(
              "Staffs List",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 2),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('staff').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No staff added yet'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final staff = Staff.fromFirestore(docs[index]);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?')),
                        title: Text(staff.name),
                        subtitle: Text('${staff.role} • ₹${staff.salary.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _showAddEditDialog(staff: staff)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteStaff(staff.id)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StaffDetailScreen(staff: staff)),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Staff',
      ),
    );
  }
}

class StaffListDashboard extends StatefulWidget {
  const StaffListDashboard({Key? key}) : super(key: key);

  @override
  State<StaffListDashboard> createState() => _StaffListDashboardState();
}

class _StaffListDashboardState extends State<StaffListDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool loading = true;
  int totalStaffs = 0;
  int totalPresent = 0;
  int totalAbsent = 0;
  double totalBonus = 0;
  double totalDeduction = 0;
  double totalNetSalary = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
  final now = DateTime.now();

  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);
  final totalDaysInMonth = monthEnd.day;

  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final staffQuery = await _firestore.collection('staff').get();

  int presentTodayCount = 0;
  int absentTodayCount = 0;
  double bonusTotal = 0.0;
  double deductionTotal = 0.0;
  double totalNetSalary = 0.0;

  for (var staffDoc in staffQuery.docs) {
    // Attendance for today
    final attendanceQueryToday = await _firestore
        .collection('staff')
        .doc(staffDoc.id)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .get();

    String statusToday = 'absent';
    for (var attDoc in attendanceQueryToday.docs) {
      final status = (attDoc['status'] ?? '').toString().toLowerCase();
      if (status == 'present' || status == 'leave') {
        statusToday = status;
        break;
      }
    }
    if (statusToday == 'present') presentTodayCount++;
    else if (statusToday == 'absent') absentTodayCount++;

    // Attendance count for the entire month to pro-rate
    final attendanceQueryMonth = await _firestore
        .collection('staff')
        .doc(staffDoc.id)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
        .get();

    int presentDaysInMonth = 0;
    for (var attDoc in attendanceQueryMonth.docs) {
      final status = (attDoc['status'] ?? '').toString().toLowerCase();
      if (status == 'present' || status == 'leave') {
        presentDaysInMonth++;
      }
    }

    // Payroll data
    final payrollDoc = await _firestore
        .collection('staff')
        .doc(staffDoc.id)
        .collection('payroll')
        .doc(monthKey)
        .get();

    if (payrollDoc.exists) {
      final data = payrollDoc.data()!;
      final double baseSalary = (data['baseSalary'] ?? 0).toDouble();
      final List bonuses = data['bonuses'] ?? [];
      final List deductions = data['deductions'] ?? [];

      final double sumBonus = bonuses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
      final double sumDeduction = deductions.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));

      // Pro-rate base salary according to present days in the month
      final double earnedSalary = (baseSalary / totalDaysInMonth) * presentDaysInMonth;

      final double netSalary = earnedSalary + sumBonus - sumDeduction;

      bonusTotal += sumBonus;
      deductionTotal += sumDeduction;
      totalNetSalary += netSalary;
    }
  }

  setState(() {
    totalStaffs = staffQuery.docs.length;
    totalPresent = presentTodayCount;
    totalAbsent = absentTodayCount;
    totalBonus = bonusTotal;
    totalDeduction = deductionTotal;
    totalNetSalary = totalNetSalary;
    loading = false;
  });
}


  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 20,
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: CircularProgressIndicator(),
    ));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Staffs', totalStaffs.toString(), Colors.indigo, Icons.group)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Present Days', totalPresent.toString(), Colors.green, Icons.event_available)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Absent Days', totalAbsent.toString(), Colors.red, Icons.event_busy)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Bonus', '₹${totalBonus.toStringAsFixed(2)}', Colors.teal, Icons.add_card)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Total Deduction', '₹${totalDeduction.toStringAsFixed(2)}', Colors.orange, Icons.remove_circle)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Net Salary', '₹${totalNetSalary.toStringAsFixed(2)}', Colors.blue, Icons.attach_money)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
