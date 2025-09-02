// lib/screens/staff_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_model.dart';
import '../models/attendance_model.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({Key? key}) : super(key: key);

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // Add or Edit staff dialog (keeps your original behavior)
  Future<void> _addOrEditStaff({Staff? staff}) async {
    final nameController = TextEditingController(text: staff?.name ?? '');
    final roleController = TextEditingController(text: staff?.role ?? '');
    final phoneController = TextEditingController(text: staff?.phone ?? '');
    final salaryController =
        TextEditingController(text: staff != null ? staff.salary.toString() : '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Monthly Salary'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final mapped = {
      'name': nameController.text.trim(),
      'role': roleController.text.trim(),
      'phone': phoneController.text.trim(),
      'salary': double.tryParse(salaryController.text.trim()) ?? 0.0,
    };

    try {
      if (staff == null) {
        await _firestore.collection('staff').add(mapped);
      } else {
        await _firestore.collection('staff').doc(staff.id).update(mapped);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    await _firestore.collection('staff').doc(staffId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // keep default white background as requested
      appBar: AppBar(
        title: const Text('Staff Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Staff'),
            Tab(text: 'Attendance'),
            Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // STAFF LIST
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('staff').orderBy('name').snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No staff added yet'));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (c, i) {
                  final staff = Staff.fromFirestore(docs[i]);
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(staff.name),
                      subtitle: Text('${staff.role} • ₹${staff.salary.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditStaff(staff: staff)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteStaff(staff.id)),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StaffDetailsScreen(staff: staff)),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // ADMIN WIDE ATTENDANCE (keeps your original Attendance tab behavior; this shows attendance collection root)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('attendance').orderBy('date', descending: true).snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No attendance records'));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (c, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final dateTs = d['date'] as Timestamp?;
                  final dateStr = dateTs != null ? (dateTs.toDate().toLocal().toString().split(' ')[0]) : 'N/A';
                  final status = (d['status'] as String?) ?? ((d['isPresent'] == true) ? 'Present' : 'Absent');
                  final staffId = d['staffId'] as String? ?? 'Unknown';
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Staff: $staffId'),
                      subtitle: Text('Date: $dateStr\nStatus: $status'),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),

          // ADMIN WIDE PAYROLL (not per-staff) — show monthly total from attendance + saved payroll adjustments
          // This tab shows organization-wide payroll summary (uses attendance under each staff subcollection and saved payroll docs for adjustments).
          FutureBuilder<double>(
            future: _computeOrgTotalThisMonth(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final totalOrg = snap.data ?? 0.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Total Staff Cost (This Month): ₹${totalOrg.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _OrgPayrollBreakdownList(), // shows per-staff detailed calculated values
                  )
                ],
              );
            },
          ),
        ],
      ),
      // FAB only on Staff tab (index 0)
      floatingActionButton: (_tabController.index == 0)
          ? FloatingActionButton(
              onPressed: () => _addOrEditStaff(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Compute the organization total for current month using:
  /// Net = (baseSalary / daysInMonth * presentDays) - deductions + bonuses
  /// - attendance is read from staff/{id}/attendance for the month
  /// - adjustments (bonuses/deductions) are read from staff/{id}/payroll/{yyyy-MM} if exists
  Future<double> _computeOrgTotalThisMonth() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    double total = 0.0;

    try {
      final staffSnap = await _firestore.collection('staff').get();
      for (final sdoc in staffSnap.docs) {
        final staff = Staff.fromFirestore(sdoc);

        // attendance subcollection for this staff in month
        final start = DateTime(now.year, now.month, 1);
        final endExclusive = DateTime(now.year, now.month + 1, 1);

        final attSnap = await _firestore
            .collection('staff')
            .doc(staff.id)
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(endExclusive))
            .get();

        int presentDays = 0;
        for (final d in attSnap.docs) {
          final m = d.data() as Map<String, dynamic>;
          final status = (m['status'] as String?) ?? ((m['isPresent'] == true) ? 'Present' : 'Absent');
          if (status == 'Present') presentDays++;
        }

        // Fetch payroll adjustment doc if present
        final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final payrollDoc = await _firestore
            .collection('staff')
            .doc(staff.id)
            .collection('payroll')
            .doc(monthKey)
            .get();

        double bonuses = 0.0;
        double deductions = 0.0;
        if (payrollDoc.exists) {
          final data = payrollDoc.data()!;
          // support both 'bonuses' or 'bonus', 'deductions' or 'deduct'
          bonuses = (data['bonuses'] as num?)?.toDouble() ?? (data['bonus'] as num?)?.toDouble() ?? 0.0;
          deductions = (data['deductions'] as num?)?.toDouble() ?? (data['deduct'] as num?)?.toDouble() ?? 0.0;
        }

        final dailyRate = (daysInMonth == 0) ? 0.0 : (staff.salary / daysInMonth);
        final earned = dailyRate * presentDays;
        final net = earned - deductions + bonuses;
        total += net;
      }
    } catch (e) {
      // if something fails, return the partial total or 0
      debugPrint('computeOrgTotalThisMonth error: $e');
      return 0.0;
    }

    return total;
  }
}

/// Shows a breakdown list (per staff) with calculated payroll (used in admin Payroll tab).
class _OrgPayrollBreakdownList extends StatefulWidget {
  @override
  State<_OrgPayrollBreakdownList> createState() => _OrgPayrollBreakdownListState();
}

class _OrgPayrollBreakdownListState extends State<_OrgPayrollBreakdownList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = _daysInMonth(now);
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('staff').orderBy('name').get(),
      builder: (ctx, staffSnap) {
        if (staffSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!staffSnap.hasData) return const Center(child: Text('No staff'));

        final staffDocs = staffSnap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: staffDocs.length,
          itemBuilder: (c, i) {
            final staff = Staff.fromFirestore(staffDocs[i]);

            return FutureBuilder<Map<String, dynamic>>(
              future: _computeForStaff(staff, now, daysInMonth),
              builder: (ctx2, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(title: Text(staff.name), subtitle: const Text('Calculating…')),
                  );
                }
                final data = snap.data ?? {'present': 0, 'bonuses': 0.0, 'deductions': 0.0, 'net': 0.0};
                final present = data['present'] as int;
                final bonuses = data['bonuses'] as double;
                final deductions = data['deductions'] as double;
                final net = data['net'] as double;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(staff.name),
                    subtitle: Text('Present: $present / $daysInMonth  •  Bonus: ₹${bonuses.toStringAsFixed(2)}  •  Deduct: ₹${deductions.toStringAsFixed(2)}'),
                    trailing: Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      // open staff detail payroll tab
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StaffDetailsScreen(staff: staff)),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// compute presentDays, read payroll adjustments if any and return net amount
  Future<Map<String, dynamic>> _computeForStaff(Staff staff, DateTime now, int daysInMonth) async {
    final start = DateTime(now.year, now.month, 1);
    final endExclusive = DateTime(now.year, now.month + 1, 1);

    final attSnap = await _firestore
        .collection('staff')
        .doc(staff.id)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(endExclusive))
        .get();

    int presentDays = 0;
    for (final d in attSnap.docs) {
      final m = d.data() as Map<String, dynamic>;
      final status = (m['status'] as String?) ?? ((m['isPresent'] == true) ? 'Present' : 'Absent');
      if (status == 'Present') presentDays++;
    }

    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final payrollDoc = await _firestore
        .collection('staff')
        .doc(staff.id)
        .collection('payroll')
        .doc(monthKey)
        .get();

    double bonuses = 0.0, deductions = 0.0;
    if (payrollDoc.exists) {
      final p = payrollDoc.data()!;
      bonuses = (p['bonuses'] as num?)?.toDouble() ?? (p['bonus'] as num?)?.toDouble() ?? 0.0;
      deductions = (p['deductions'] as num?)?.toDouble() ?? (p['deduct'] as num?)?.toDouble() ?? 0.0;
    }

    final dailyRate = daysInMonth == 0 ? 0.0 : (staff.salary / daysInMonth);
    final earned = dailyRate * presentDays;
    final net = earned - deductions + bonuses;

    return {
      'present': presentDays,
      'bonuses': bonuses,
      'deductions': deductions,
      'net': net,
    };
  }
}

/// ---------------- STAFF DETAILS SCREEN (Profile / Attendance / Payroll) ----------------
class StaffDetailsScreen extends StatelessWidget {
  final Staff staff;
  const StaffDetailsScreen({Key? key, required this.staff}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We'll use DefaultTabController inside scaffold for per-staff tabs
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(staff.name),
          bottom: const TabBar(tabs: [
            Tab(text: 'Profile'),
            Tab(text: 'Attendance'),
            Tab(text: 'Payroll'),
          ]),
        ),
        body: TabBarView(
          children: [
            StaffProfileTab(staff: staff),
            AttendanceTab(staffId: staff.id),
            PayrollTab(staffId: staff.id, baseSalary: staff.salary),
          ],
        ),
      ),
    );
  }
}

/// ---------------- PROFILE TAB ----------------
class StaffProfileTab extends StatelessWidget {
  final Staff staff;
  const StaffProfileTab({Key? key, required this.staff}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Name: ${staff.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Role: ${staff.role}'),
            const SizedBox(height: 8),
            Text('Phone: ${staff.phone}'),
            const SizedBox(height: 8),
            Text('Monthly Salary: ₹${staff.salary.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use main list to edit staff.')));
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('staff').doc(staff.id).delete();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// ---------------- ATTENDANCE TAB (per-staff) ----------------
class AttendanceTab extends StatelessWidget {
  final String staffId;
  const AttendanceTab({Key? key, required this.staffId}) : super(key: key);

  Future<void> _markAttendance(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null) return;

    final status = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Status'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Present'), child: const Text('Present')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Absent'), child: const Text('Absent')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Leave'), child: const Text('Leave')),
        ],
      ),
    );
    if (status == null) return;

    final isPresent = status == 'Present';
    final docId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await FirebaseFirestore.instance
        .collection('staff')
        .doc(staffId)
        .collection('attendance')
        .doc(docId)
        .set({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'status': status,
      'isPresent': isPresent,
    }, SetOptions(merge: true));
  }

  Future<void> _editAttendance(BuildContext context, QueryDocumentSnapshot docSnap) async {
    final data = docSnap.data() as Map<String, dynamic>;
    final curStatus = (data['status'] as String?) ?? ((data['isPresent'] == true) ? 'Present' : 'Absent');

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Status'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Present'), child: const Text('Present')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Absent'), child: const Text('Absent')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Leave'), child: const Text('Leave')),
        ],
      ),
    );
    if (newStatus == null) return;

    final isPresent = newStatus == 'Present';
    await docSnap.reference.set({
      'status': newStatus,
      'isPresent': isPresent,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('staff').doc(staffId).collection('attendance').orderBy('date', descending: true);

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No attendance records'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final docData = docs[i].data() as Map<String, dynamic>;
              final date = (docData['date'] as Timestamp?)?.toDate();
              final dateStr = date != null ? date.toLocal().toString().split(' ')[0] : 'N/A';
              final status = (docData['status'] as String?) ?? ((docData['isPresent'] == true) ? 'Present' : 'Absent');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(
                    status == 'Present' ? Icons.check_circle : (status == 'Leave' ? Icons.beach_access : Icons.cancel),
                    color: status == 'Present' ? Colors.green : (status == 'Leave' ? Colors.orange : Colors.red),
                  ),
                  title: Text(dateStr),
                  subtitle: Text('Status: $status'),
                  onTap: () => _editAttendance(context, docs[i]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _markAttendance(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ---------------- PAYROLL TAB (per-staff) ----------------
class PayrollTab extends StatefulWidget {
  final String staffId;
  final double baseSalary;

  const PayrollTab({Key? key, required this.staffId, required this.baseSalary}) : super(key: key);

  @override
  _PayrollTabState createState() => _PayrollTabState();
}

class _PayrollTabState extends State<PayrollTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  int _daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

  Future<Map<String, dynamic>> _computeThisMonthForStaff() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final endExclusive = DateTime(now.year, now.month + 1, 1);

    final attSnap = await _firestore
        .collection('staff')
        .doc(widget.staffId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(endExclusive))
        .get();

    int presentDays = 0;
    for (final doc in attSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final status = (d['status'] as String?) ?? ((d['isPresent'] == true) ? 'Present' : 'Absent');
      if (status == 'Present') presentDays++;
    }

    final daysInMonth = _daysInMonth(now);
    final dailyRate = daysInMonth == 0 ? 0.0 : (widget.baseSalary / daysInMonth);
    final earned = dailyRate * presentDays;

    // Check for saved payroll doc for adjustments (bonuses/deductions)
    final monthKey = _monthKey(now);
    final doc = await _firestore.collection('staff').doc(widget.staffId).collection('payroll').doc(monthKey).get();

    double bonuses = 0.0;
    double deductions = 0.0;
    if (doc.exists) {
      final m = doc.data()!;
      bonuses = (m['bonuses'] as num?)?.toDouble() ?? (m['bonus'] as num?)?.toDouble() ?? 0.0;
      deductions = (m['deductions'] as num?)?.toDouble() ?? (m['deduct'] as num?)?.toDouble() ?? 0.0;
    }

    final net = earned - deductions + bonuses;

    return {
      'presentDays': presentDays,
      'totalDaysInMonth': daysInMonth,
      'earned': earned,
      'bonuses': bonuses,
      'deductions': deductions,
      'net': net,
      'monthKey': monthKey,
    };
  }

  Future<double> _computeOrgTotalThisMonth() async {
    final now = DateTime.now();
    final daysInMonth = _daysInMonth(now);
    double total = 0.0;

    final staffSnap = await _firestore.collection('staff').get();
    for (final s in staffSnap.docs) {
      final st = Staff.fromFirestore(s);
      // attendance for staff this month
      final start = DateTime(now.year, now.month, 1);
      final endExclusive = DateTime(now.year, now.month + 1, 1);
      final attSnap = await _firestore
          .collection('staff')
          .doc(st.id)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .get();

      int presentDays = 0;
      for (final d in attSnap.docs) {
        final m = d.data() as Map<String, dynamic>;
        final status = (m['status'] as String?) ?? ((m['isPresent'] == true) ? 'Present' : 'Absent');
        if (status == 'Present') presentDays++;
      }

      // payroll adjustments if any
      final monthKey = _monthKey(now);
      final pd = await _firestore.collection('staff').doc(st.id).collection('payroll').doc(monthKey).get();
      double bonuses = 0.0;
      double deductions = 0.0;
      if (pd.exists) {
        final m = pd.data()!;
        bonuses = (m['bonuses'] as num?)?.toDouble() ?? (m['bonus'] as num?)?.toDouble() ?? 0.0;
        deductions = (m['deductions'] as num?)?.toDouble() ?? (m['deduct'] as num?)?.toDouble() ?? 0.0;
      }

      final dailyRate = (daysInMonth == 0) ? 0.0 : (st.salary / daysInMonth);
      final earned = dailyRate * presentDays;
      final net = earned - deductions + bonuses;
      total += net;
    }

    return total;
  }

  Future<void> _generatePayroll() async {
    final now = DateTime.now();
    final monthKey = _monthKey(now);
    final summary = await _computeThisMonthForStaff();

    final presentDays = summary['presentDays'] as int;
    final daysInMonth = summary['totalDaysInMonth'] as int;
    final earned = summary['earned'] as double;

    final bonusCtrl = TextEditingController(text: (summary['bonuses'] as double).toString());
    final deductCtrl = TextEditingController(text: (summary['deductions'] as double).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Payroll'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Present Days: $presentDays / $daysInMonth'),
            const SizedBox(height: 8),
            Text('Base Salary: ₹${widget.baseSalary.toStringAsFixed(2)}'),
            Text('Earned (before adj): ₹${earned.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(controller: bonusCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus')),
            TextField(controller: deductCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deduction')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final bonus = double.tryParse(bonusCtrl.text.trim()) ?? 0.0;
      final deduct = double.tryParse(deductCtrl.text.trim()) ?? 0.0;
      final netPay = earned - deduct + bonus;

      await _firestore
          .collection('staff')
          .doc(widget.staffId)
          .collection('payroll')
          .doc(monthKey)
          .set({
        'month': monthKey,
        'baseSalary': widget.baseSalary,
        'presentDays': presentDays,
        'totalDaysInMonth': daysInMonth,
        'earnedSalary': earned,
        'bonuses': bonus,
        'deductions': deduct,
        'netPay': netPay,
        'generatedDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll generated')));
        setState(() {}); // refresh view
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthKeyNow = _monthKey(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<dynamic>>(
        // parallel futures: staff summary for this staff + org total
        future: Future.wait([_computeThisMonthForStaff(), _computeOrgTotalThisMonth()]),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final staffSummary = (snap.data != null && snap.data!.isNotEmpty) ? snap.data![0] as Map<String, dynamic> : null;
          final orgTotal = (snap.data != null && snap.data!.length > 1) ? (snap.data![1] as double) : 0.0;

          final presentDays = staffSummary?['presentDays'] as int? ?? 0;
          final totalDaysInMonth = staffSummary?['totalDaysInMonth'] as int? ?? _daysInMonth(DateTime.now());
          final earned = staffSummary?['earned'] as double? ?? 0.0;
          final bonuses = staffSummary?['bonuses'] as double? ?? 0.0;
          final deductions = staffSummary?['deductions'] as double? ?? 0.0;
          final net = staffSummary?['net'] as double? ?? 0.0;

          return Column(
            children: [
              // Org total summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text('Total Staff Cost (This Month): ₹${orgTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),

              // This staff quick summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('This Staff (This Month):', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Present Days: $presentDays / $totalDaysInMonth'),
                  Text('Base Salary: ₹${widget.baseSalary.toStringAsFixed(2)}'),
                  Text('Earned (before bonus/deductions): ₹${earned.toStringAsFixed(2)}'),
                  Text('Bonuses: ₹${bonuses.toStringAsFixed(2)}  •  Deductions: ₹${deductions.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  Text('Net: ₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),

              const SizedBox(height: 6),

              // Saved payroll records for this staff
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('staff')
                      .doc(widget.staffId)
                      .collection('payroll')
                      .orderBy('generatedDate', descending: true)
                      .snapshots(),
                  builder: (ctx2, snapPayroll) {
                    if (snapPayroll.hasError) return Center(child: Text('Error: ${snapPayroll.error}'));
                    if (!snapPayroll.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapPayroll.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No payroll records'));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final month = data['month'] ?? docs[i].id;
                        final netPay = (data['netPay'] as num?)?.toDouble() ?? 0.0;
                        final gen = (data['generatedDate'] as Timestamp?)?.toDate();
                        final bonusesDoc = (data['bonuses'] as num?)?.toDouble() ?? 0.0;
                        final deductionsDoc = (data['deductions'] as num?)?.toDouble() ?? 0.0;
                        final earnedDoc = (data['earnedSalary'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const Icon(Icons.payment),
                            title: Text('Month: $month'),
                            subtitle: Text('Earned: ₹${earnedDoc.toStringAsFixed(2)}  •  Bonus: ₹${bonusesDoc.toStringAsFixed(2)}  •  Deduct: ₹${deductionsDoc.toStringAsFixed(2)}\nGenerated: ${gen != null ? gen.toLocal().toString().split(' ').first : 'N/A'}'),
                            trailing: Text('₹${netPay.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Generate Payroll',
        onPressed: () => _generatePayroll(),
        child: const Icon(Icons.calculate),
      ),
    );
  }
}
