import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  State<ServiceManagementScreen> createState() => _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Service> services = [];
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final snapshot = await firestore.collection('services').get();
      final list = snapshot.docs
          .map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by name for cleaner UI
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() => services = list);
    } catch (e) {
      _toast('Failed to load services: $e');
    }
  }

  Future<void> _addOrRename({Service? existing}) async {
    _nameCtrl.text = existing?.name ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Service' : 'Rename Service'),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Service package name',
            hintText: 'e.g., Premium Interior + Exterior',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, _nameCtrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;

    final name = result.trim();
    if (name.isEmpty) {
      _toast('Please enter a name');
      return;
    }

    // Check for duplicate, case-insensitive
    final dup = services.any((s) => s.name.toLowerCase() == name.toLowerCase());
    final isSameAsExisting = existing != null && existing.name.toLowerCase() == name.toLowerCase();

    if (dup && !isSameAsExisting) {
      _toast('Service already exists');
      return;
    }

    try {
      if (existing == null) {
        // Add new service document to Firestore
        final docRef = await firestore.collection('services').add({
          'name': name,
          'price': 0,
          'vehicleType': '',
        });
        debugPrint('Added service ${docRef.id}');
      } else {
        // Update existing service document
        if (existing.id == null) {
          _toast('Missing service id');
          return;
        }
        await firestore.collection('services').doc(existing.id!).update({
          'name': name,
          // Keep price and vehicleType unchanged or set defaults if needed
        });
        debugPrint('Updated service ${existing.id}');
      }
      await _loadServices();
    } catch (e) {
      _toast('Failed to save service: $e');
    }
  }

  Future<void> _confirmDelete(Service s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service?'),
        content: Text('Delete "${s.name}"? This will not affect existing enquiries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        if (s.id == null) {
          _toast('Missing service id');
          return;
        }
        await firestore.collection('services').doc(s.id!).delete();
        await _loadServices();
      } catch (e) {
        _toast('Failed to delete service: $e');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Service',
            onPressed: () => _addOrRename(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadServices,
        child: services.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No services yet. Tap + to add one.')),
                ],
              )
            : ListView.separated(
                itemCount: services.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final s = services[index];
                  return ListTile(
                    title: Text(s.name),
                    subtitle: (s.price > 0 || s.vehicleType.isNotEmpty)
                        ? Text([
                            if (s.vehicleType.isNotEmpty) s.vehicleType,
                            if (s.price > 0) '₹${s.price.toStringAsFixed(0)}',
                          ].join(' • '))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _addOrRename(existing: s),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(s),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrRename(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
