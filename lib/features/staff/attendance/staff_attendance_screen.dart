import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/staff_model.dart';


class StaffAttendanceScreen extends StatelessWidget {
  final String staffId;
  final String staffName;

  const StaffAttendanceScreen({Key? key, required this.staffId, required this.staffName}) : super(key: key);

  Future<void> _editAttendance(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String status = data['status'] ?? 'Present';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Attendance (${data['date'] != null ? (data['date'] as Timestamp).toDate().toLocal().toString().split(" ")[0] : ""})'),
        content: DropdownButtonFormField<String>(
          value: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'Present', child: Text('Present')),
            DropdownMenuItem(value: 'Absent', child: Text('Absent')),
            DropdownMenuItem(value: 'Leave', child: Text('Leave')),
          ],
          onChanged: (val) {
            if (val != null) status = val;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, status), child: const Text('Save')),
        ],
      ),
    );

    if (result == null) return; // User canceled

    await doc.reference.set({
      'status': result,
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance updated to "$result"')));
    }
  }

  Future<void> _deleteAttendance(BuildContext context, DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attendance Entry'),
        content: const Text('Are you sure you want to delete this attendance record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await doc.reference.delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceCollection = FirebaseFirestore.instance
        .collection('staff')
        .doc(staffId)
        .collection('attendance')
        .orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text('$staffName Attendance')),
      body: StreamBuilder<QuerySnapshot>(
        stream: attendanceCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No attendance records'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateTs = data['date'] as Timestamp?;
              final dateStr = dateTs != null ? dateTs.toDate().toLocal().toString().split(" ")[0] : "Unknown";
              final status = data['status'] ?? 'Present';

              return ListTile(
                title: Text(dateStr),
                subtitle: Text('Status: $status'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editAttendance(context, doc)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteAttendance(context, doc)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
