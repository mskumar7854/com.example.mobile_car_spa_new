import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/staff_model.dart';
import 'attendance/staff_attendance_screen.dart';
import 'payroll/staff_payroll_screen.dart';



class StaffDetailScreen extends StatefulWidget {
  final Staff staff;
  const StaffDetailScreen({Key? key, required this.staff}) : super(key: key);

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staff.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Attendance'),
            Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ProfileDashboardTab(staff: widget.staff),
          AttendanceCalendarTab(staffId: widget.staff.id),
          PayrollTab(staff: widget.staff),
        ],
      ),
    );
  }
}

class ProfileDashboardTab extends StatefulWidget {
  final Staff staff;
  const ProfileDashboardTab({Key? key, required this.staff}) : super(key: key);

  @override
  State<ProfileDashboardTab> createState() => _ProfileDashboardTabState();
}

class _ProfileDashboardTabState extends State<ProfileDashboardTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int presentDays = 0;
  int absentDays = 0;
  double netSalary = 0;
  double totalBonus = 0;
  double totalDeduction = 0;
  bool loading = true;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      loading = true;
    });
    final now = selectedMonth;
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final attendanceSnap = await _firestore
        .collection('staff')
        .doc(widget.staff.id)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    int countedPresent = 0;
    int countedAbsent = 0;
    for (var doc in attendanceSnap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'present') countedPresent++;
      else if (status == 'absent') countedAbsent++;
    }

    final totalDaysInMonth = endOfMonth.day;
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final payrollDoc = await _firestore
        .collection('staff')
        .doc(widget.staff.id)
        .collection('payroll')
        .doc(monthKey)
        .get();

    Map<String, dynamic> payrollData = {};
    if (payrollDoc.exists) {
      payrollData = payrollDoc.data()!;
    }

    double baseSalary = (payrollData['baseSalary'] ?? widget.staff.salary).toDouble();
    List bonuses = payrollData['bonuses'] ?? [];
    List deductions = payrollData['deductions'] ?? [];

    double sumBonus = bonuses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
    double sumDeduction = deductions.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
    double earnedSalary = baseSalary / totalDaysInMonth * countedPresent;
    double calculatedNetSalary = earnedSalary - sumDeduction + sumBonus;

    setState(() {
      presentDays = countedPresent;
      absentDays = countedAbsent;
      netSalary = calculatedNetSalary;
      totalBonus = sumBonus;
      totalDeduction = sumDeduction;
      loading = false;
    });
  }

  List<DropdownMenuItem<DateTime>> _buildMonthItems() {
  final now = DateTime.now();
  final months = List<DateTime>.generate(
    12,
    (i) => DateTime(now.year, now.month - i, 1),
  );

  return months.map((date) {
    final monthName = _monthName(date.month);
    final displayText = '$monthName ${date.year}';
    return DropdownMenuItem(
      value: date,
      child: Text(displayText),
    );
  }).toList();
}

String _monthName(int month) {
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return monthNames[month - 1];
}


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month selector dropdown at top
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Select Month: ', style: TextStyle(fontWeight: FontWeight.w600)),
              DropdownButton<DateTime>(
                value: selectedMonth,
                items: _buildMonthItems(),
                onChanged: (newMonth) {
                  if (newMonth != null) {
                    setState(() {
                      selectedMonth = newMonth;
                    });
                    _loadDashboardData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (loading) const Center(child: CircularProgressIndicator()) else ...[
            // First row (Present & Absent)
            Row(
              children: [
                Expanded(child: _buildStatCard('Present Days', presentDays.toString(), Colors.green, Icons.event_available)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Absent Days', absentDays.toString(), Colors.red, Icons.event_busy)),
              ],
            ),
            const SizedBox(height: 12),
            // Second row (Total Bonus & Total Deduction)
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Bonus', '₹${totalBonus.toStringAsFixed(2)}', Colors.teal, Icons.add_card)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Total Deduction', '₹${totalDeduction.toStringAsFixed(2)}', Colors.orange, Icons.remove_circle)),
              ],
            ),
            const SizedBox(height: 13),
            // Net Salary
            _buildStatCard('Net Salary', '₹${netSalary.toStringAsFixed(2)}', Colors.blue, Icons.attach_money),
            const SizedBox(height: 18),
            _buildProfileInfoCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 22,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildInfoRow('Name', widget.staff.name),
            _buildInfoRow('Role', widget.staff.role),
            _buildInfoRow('Phone', widget.staff.phone),
            _buildInfoRow('Monthly Salary', '₹${widget.staff.salary.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}


class AttendanceCalendarTab extends StatefulWidget {
  final String staffId;

  const AttendanceCalendarTab({Key? key, required this.staffId}) : super(key: key);

  @override
  State<AttendanceCalendarTab> createState() => _AttendanceCalendarTabState();
}

class _AttendanceCalendarTabState extends State<AttendanceCalendarTab> {
  late final FirebaseFirestore _firestore;
  late Map<DateTime, String> _attendanceByDay;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _attendanceByDay = {};
    _loadAttendanceForMonth(_focusedDay);
  }

  Future<void> _loadAttendanceForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final attendanceSnap = await _firestore
        .collection('staff')
        .doc(widget.staffId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    final Map<DateTime, String> loadedAttendance = {};
    for (var doc in attendanceSnap.docs) {
      final data = doc.data();
      final ts = data['date'] as Timestamp?;
      final status = data['status'] as String? ?? 'Present';
      if (ts != null) {
        final dt = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        loadedAttendance[dt] = status;
      }
    }

    setState(() {
      _attendanceByDay = loadedAttendance;
    });
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    if (selectedDay.isAfter(DateTime.now())) {
      // Future dates are not editable
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Future dates cannot be edited')),
      );
      return;
    }
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final currentStatus = _attendanceByDay[selectedDay] ?? 'Present';

    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mark Attendance'),
        children: ['Present', 'Absent', 'Leave'].map((status) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, status),
            child: Text(
              status,
              style: TextStyle(
                fontWeight: currentStatus == status ? FontWeight.bold : FontWeight.normal,
                color: currentStatus == status ? Colors.blue : null,
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (newStatus == null) return;

    final formattedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    await _firestore
        .collection('staff')
        .doc(widget.staffId)
        .collection('attendance')
        .doc('${formattedDate.year}-${formattedDate.month.toString().padLeft(2, '0')}-${formattedDate.day.toString().padLeft(2, '0')}')
        .set({
      'date': Timestamp.fromDate(formattedDate),
      'status': newStatus,
    });

    setState(() {
      _attendanceByDay[formattedDate] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance marked as "$newStatus" on ${formattedDate.toLocal().toString().split(" ")[0]}')),
    );
  }

  Color _getColorForStatus(String? status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'Leave':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDayMarker(DateTime day, DateTime focusedDay) {
    final status = _attendanceByDay[DateTime(day.year, day.month, day.day)];
    final color = _getColorForStatus(status);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      onDaySelected: _onDaySelected,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          if (_attendanceByDay.containsKey(DateTime(day.year, day.month, day.day))) {
            return _buildDayMarker(day, focusedDay);
          }
          return null;
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayMarker(day, focusedDay);
        },
        selectedBuilder: (context, day, focusedDay) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _loadAttendanceForMonth(focusedDay);
      },
    );
  }
}

class PayrollTab extends StatefulWidget {
  final Staff staff;
  const PayrollTab({Key? key, required this.staff}) : super(key: key);

  @override
  State<PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends State<PayrollTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _presentDays = 0;
  bool _loadingAttendance = true;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadAttendancePresentDays(selectedMonth);
  }

  Future<void> _loadAttendancePresentDays(DateTime month) async {
    setState(() {
      _loadingAttendance = true;
    });
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final attendanceSnap = await _firestore
        .collection('staff')
        .doc(widget.staff.id)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    int presentCount = 0;
    for (var doc in attendanceSnap.docs) {
      final data = doc.data();
      if ((data['status'] ?? '') == 'Present') {
        presentCount++;
      }
    }

    setState(() {
      _presentDays = presentCount;
      _loadingAttendance = false;
    });
  }

  double _calculateNetSalary(
      Map<String, dynamic> payrollData, int presentDays, int totalDays) {
    final double baseSalary =
        (payrollData['baseSalary'] ?? widget.staff.salary).toDouble();
    final List bonuses = payrollData['bonuses'] ?? [];
    final List deductions = payrollData['deductions'] ?? [];

    double totalBonus =
        bonuses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
    double totalDeduction =
        deductions.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));

    double earnedSalary = baseSalary / totalDays * presentDays;

    return earnedSalary - totalDeduction + totalBonus;
  }

  Future<void> _addOrEditEntry(String type,
      {Map<String, dynamic>? existingEntry, int? index}) async {
    final amountCtrl = TextEditingController(
        text: existingEntry != null ? existingEntry['amount'].toString() : '');
    final descCtrl = TextEditingController(
        text: existingEntry != null ? existingEntry['description'] : '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${existingEntry != null ? "Edit" : "Add"} ${type == "bonus" ? "Bonus" : "Deduction"}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter description' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null) return 'Enter valid number';
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

    final now = selectedMonth;
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final payrollDocRef =
        _firestore.collection('staff').doc(widget.staff.id).collection('payroll').doc(monthKey);

    final doc = await payrollDocRef.get();
    Map<String, dynamic> data = doc.exists ? doc.data()! : {};

    List list = data[type == "bonus" ? 'bonuses' : 'deductions'] ?? [];

    final entry = {
      'amount': double.parse(amountCtrl.text.trim()),
      'description': descCtrl.text.trim(),
      'date': Timestamp.now(),
    };

    if (existingEntry != null && index != null) {
      list[index] = entry;
    } else {
      list.add(entry);
    }

    data[type == "bonus" ? 'bonuses' : 'deductions'] = list;
    data['month'] = monthKey;
    data['baseSalary'] = data['baseSalary'] ?? widget.staff.salary;
    data['generatedDate'] = data['generatedDate'] ?? Timestamp.fromDate(now);

    await payrollDocRef.set(data, SetOptions(merge: true));
  }

  Future<void> _deleteEntry(String type, int index) async {
    final now = selectedMonth;
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final payrollDocRef =
        _firestore.collection('staff').doc(widget.staff.id).collection('payroll').doc(monthKey);
    final doc = await payrollDocRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      List list = data[type == "bonus" ? 'bonuses' : 'deductions'] ?? [];
      if (index < list.length) {
        list.removeAt(index);
        data[type == "bonus" ? 'bonuses' : 'deductions'] = list;
        await payrollDocRef.set(data, SetOptions(merge: true));
      }
    }
  }

  Widget _buildEntryList(String title, List entries, Color color, String type) {
    if (entries.isEmpty) return Text('No $title');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        const SizedBox(height: 8),
        ...entries.asMap().entries.map((entry) {
          final idx = entry.key;
          final Map<String, dynamic> item = Map<String, dynamic>.from(entry.value);
          final amount = (item['amount'] ?? 0).toDouble();
          final description = (item['description'] ?? '');

          final Timestamp? timestamp = item['date'];
          final String dateStr = timestamp != null
              ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
              : '';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              dense: true,
              title: Text(description, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: dateStr.isNotEmpty ? Text(dateStr) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _addOrEditEntry(type, existingEntry: item, index: idx),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteEntry(type, idx),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<DropdownMenuItem<DateTime>> _buildMonthItems() {
    final now = DateTime.now();
    final months = List<DateTime>.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );

    return months.map((date) {
      final monthName = _monthName(date.month);
      final displayText = '$monthName ${date.year}';
      return DropdownMenuItem(
        value: date,
        child: Text(displayText),
      );
    }).toList();
  }

  String _monthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final totalDaysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    final monthKey = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    final payrollDocRef = _firestore.collection('staff').doc(widget.staff.id).collection('payroll').doc(monthKey);

    return StreamBuilder<DocumentSnapshot>(
      stream: payrollDocRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic> data = {
          'bonuses': [],
          'deductions': [],
          'month': monthKey,
          'baseSalary': widget.staff.salary,
          'generatedDate': Timestamp.now(),
        };

        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        } else {
          payrollDocRef.set(data);
        }

        final netSalary = _calculateNetSalary(data, _presentDays, totalDaysInMonth);

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final choice = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Add Entry'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'bonus'),
                      child: const Text('Add Bonus'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'deduction'),
                      child: const Text('Add Deduction'),
                    ),
                  ],
                ),
              );

              if (choice != null && (choice == 'bonus' || choice == 'deduction')) {
                _addOrEditEntry(choice);
              }
            },
            child: const Icon(Icons.add),
            tooltip: 'Add Bonus or Deduction',
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Month dropdown aligned right at the top
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<DateTime>(
                    value: selectedMonth,
                    items: _buildMonthItems(),
                    onChanged: (newMonth) {
                      if (newMonth != null) {
                        setState(() {
                          selectedMonth = newMonth;
                          _loadingAttendance = true;
                          _loadAttendancePresentDays(newMonth);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Net Salary display
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Salary',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        Text(
                          '₹${netSalary.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bonuses list
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEntryList('Bonuses', data['bonuses'] ?? [], Colors.green, 'bonus'),
                        const SizedBox(height: 24),
                        _buildEntryList('Deductions', data['deductions'] ?? [], Colors.red, 'deduction'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}