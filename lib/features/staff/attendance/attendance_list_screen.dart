import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/staff_model.dart';

class AttendanceListScreen extends StatelessWidget {
  const AttendanceListScreen({Key? key}) : super(key: key);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _markAttendance(BuildContext context, Staff staff) async {
    DateTime today = DateTime.now();
    DateTime date = DateTime(today.year, today.month, today.day);

    String? selectedStatus = 'Present';

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Mark Attendance for ${staff.name}'),
          content: DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(labelText: 'Attendance Status'),
            items: const [
              DropdownMenuItem(value: 'Present', child: Text('Present')),
              DropdownMenuItem(value: 'Absent', child: Text('Absent')),
              DropdownMenuItem(value: 'Leave', child: Text('Leave')),
            ],
            onChanged: (val) => selectedStatus = val,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedStatus), child: const Text('Save')),
          ],
        );
      },
    );

    if (result == null) return; // Cancelled

    String docId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('staff')
        .doc(staff.id)
        .collection('attendance')
        .doc(docId)
        .set({
      'date': Timestamp.fromDate(date),
      'status': result,
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked $result attendance for ${staff.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('staff').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final staffDocs = snapshot.data!.docs;
          if (staffDocs.isEmpty) {
            return const Center(child: Text('No staff found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final staff = Staff.fromFirestore(staffDocs[index]);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(staff.name),
                  subtitle: Text(staff.role),
                  trailing: ElevatedButton(
                    onPressed: () => _markAttendance(context, staff),
                    child: const Text('Mark'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
