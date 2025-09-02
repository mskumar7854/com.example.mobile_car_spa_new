import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // For date formatting if needed

import '../utils/excel_exporter.dart';
import '../features/staff/staff_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final roleCtrl = TextEditingController();

  bool loading = false;
  String? profilePhotoUrl;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    roleCtrl.dispose();
    super.dispose();
  }

  Future loadProfile() async {
    try {
      final doc = await firestore.collection('profiles').doc('admin').get();
      if (doc.exists) {
        final data = doc.data()!;
        nameCtrl.text = (data['name'] as String?) ?? '';
        phoneCtrl.text = (data['phone'] as String?) ?? '';
        emailCtrl.text = (data['email'] as String?) ?? '';
        roleCtrl.text = (data['role'] as String?) ?? '';
        profilePhotoUrl = data['photoUrl'] as String?;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silent fail acceptable here
    }
  }

  Future saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await firestore.collection('profiles').doc('admin').set({
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'role': roleCtrl.text.trim(),
        'photoUrl': profilePhotoUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      setState(() => isEditing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<String> saveAndShareExcel(Excel excel, {required String fileName}) async {
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel');
    final granted = await _requestStoragePermission();
    if (granted) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(file.path)], text: 'Mobile Car Spa Export');
        return file.path;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final fallback = File('${appDir.path}/$fileName');
      await fallback.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(fallback.path)], text: 'Mobile Car Spa Export');
      return fallback.path;
    }
    throw Exception('Storage permission denied');
  }

  Future exportExcel() async {
    try {
      setState(() => loading = true);
      final savedPath = await ExcelExporter.exportAll();
      await Share.shareXFiles([XFile(savedPath)], text: 'Mobile Car Spa Export');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported and shared file at:\n$savedPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export/share Excel: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Widget buildProfileSection() {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with edit icon aligned right
          Row(
            children: [
              const Expanded(
                child: Text('Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                tooltip: 'Edit Profile',
                onPressed: () => setState(() => isEditing = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Profile avatar and some spacing
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
              child: profilePhotoUrl == null
                  ? Icon(Icons.person, size: 40, color: Colors.grey.shade500)
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Profile fields or editing form below
          if (!isEditing) ...[
            _buildReadOnlyProfileField('Name', nameCtrl.text),
            _buildReadOnlyProfileField('Phone', phoneCtrl.text),
            _buildReadOnlyProfileField('Email', emailCtrl.text),
            _buildReadOnlyProfileField('Role', roleCtrl.text),
          ] else ...[
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter your phone' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      return val.contains('@') ? null : 'Please enter a valid email';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: loading ? null : () async => saveProfile(),
                        child: loading
                            ? const SizedBox(
                                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save'),
                      ),
                      OutlinedButton(
                        onPressed: loading
                            ? null
                            : () {
                                loadProfile();
                                setState(() => isEditing = false);
                              },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildReadOnlyProfileField(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}


  Widget buildMenuTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 28, color: Colors.blueAccent),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, size: 26),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    buildProfileSection(),
                    buildMenuTile(
                      title: 'Manage Vehicle Catalog',
                      icon: Icons.directions_car,
                      onTap: () => Navigator.pushNamed(context, '/vehicle-catalog'),
                    ),
                    buildMenuTile(
                      title: 'Manage Services',
                      icon: Icons.car_repair,
                      onTap: () => Navigator.pushNamed(context, '/service-management'),
                    ),
                    buildMenuTile(
                      title: 'Business Report',
                      icon: Icons.bar_chart,
                      onTap: () => Navigator.pushNamed(context, '/report'),
                    ),
                    buildMenuTile(
                      title: 'Staff Management',
                      icon: Icons.group,
                      onTap: () => Navigator.pushNamed(context, '/staff-list'),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: loading ? null : exportExcel,
                      icon: loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download),
                      label: loading
                          ? const Text('Exporting...')
                          : const Text(
                              'Export and Share Excel',
                              style: TextStyle(fontSize: 18),
                            ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
