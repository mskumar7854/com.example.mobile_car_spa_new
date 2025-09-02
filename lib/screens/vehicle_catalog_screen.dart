import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VehicleCatalogScreen extends StatefulWidget {
  const VehicleCatalogScreen({super.key});

  @override
  State<VehicleCatalogScreen> createState() => _VehicleCatalogScreenState();
}

class _VehicleCatalogScreenState extends State<VehicleCatalogScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String? _selectedBrandId;
  String? _selectedBrandName;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _brands = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _currentModels = [];

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    final snapshot = await firestore.collection('brands').orderBy('name').get();
    setState(() {
      _brands = snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
      if (_brands.isNotEmpty) {
        _selectedBrandId = _brands.first.id;
        _selectedBrandName = (_brands.first.data()['name'] as String?) ?? '';
        _loadModels(_selectedBrandId!);
      } else {
        _selectedBrandId = null;
        _selectedBrandName = null;
        _currentModels = [];
      }
    });
  }

  Future<void> _loadModels(String brandId) async {
    final snapshot = await firestore
        .collection('brands')
        .doc(brandId)
        .collection('models')
        .orderBy('name')
        .get();
    setState(() {
      _currentModels = snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    });
  }

  Future<void> _addBrand() async {
    final name = await _promptText('Add Brand');
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();

    final existing = await firestore
        .collection('brands')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      _toast('Brand already exists');
      return;
    }
    await firestore.collection('brands').add({'name': trimmed});
    await _loadBrands();
  }

  Future<void> _editBrand(String brandId, String currentName) async {
    final name = await _promptText('Rename Brand', initial: currentName);
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();

    final existing = await firestore
        .collection('brands')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty && existing.docs.first.id != brandId) {
      _toast('Brand already exists');
      return;
    }
    await firestore.collection('brands').doc(brandId).update({'name': trimmed});
    await _loadBrands();
  }

  Future<void> _deleteBrand(String brandId) async {
    final confirm = await _confirm(
      'Delete Brand?',
      'This will delete the brand and all its models.',
    );
    if (!confirm) return;

    // Delete nested models first
    final modelSnapshot = await firestore
        .collection('brands')
        .doc(brandId)
        .collection('models')
        .get();

    for (final doc in modelSnapshot.docs) {
      await firestore
          .collection('brands')
          .doc(brandId)
          .collection('models')
          .doc(doc.id)
          .delete();
    }

    await firestore.collection('brands').doc(brandId).delete();
    await _loadBrands();
  }

  Future<void> _addModel() async {
    if (_selectedBrandId == null) return;

    final name = await _promptText('Add Model');
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();

    final existing = await firestore
        .collection('brands')
        .doc(_selectedBrandId)
        .collection('models')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      _toast('Model already exists');
      return;
    }
    await firestore
        .collection('brands')
        .doc(_selectedBrandId)
        .collection('models')
        .add({'name': trimmed});
    await _loadModels(_selectedBrandId!);
  }

  Future<void> _editModel(String modelId, String currentName) async {
    if (_selectedBrandId == null) return;

    final name = await _promptText('Rename Model', initial: currentName);
    if (name == null || name.trim().isEmpty) return;
    final trimmed = name.trim();

    final existing = await firestore
        .collection('brands')
        .doc(_selectedBrandId)
        .collection('models')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty && existing.docs.first.id != modelId) {
      _toast('Model already exists');
      return;
    }
    await firestore
        .collection('brands')
        .doc(_selectedBrandId)
        .collection('models')
        .doc(modelId)
        .update({'name': trimmed});
    await _loadModels(_selectedBrandId!);
  }

  Future<void> _deleteModel(String modelId) async {
    if (_selectedBrandId == null) return;

    final confirm = await _confirm('Delete Model?', 'This will delete the model.');
    if (!confirm) return;

    await firestore
        .collection('brands')
        .doc(_selectedBrandId)
        .collection('models')
        .doc(modelId)
        .delete();
    await _loadModels(_selectedBrandId!);
  }

  Future<String?> _promptText(String title, {String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Catalog'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Add Brand', onPressed: _addBrand),
        ],
      ),
      body: Row(
        children: [
          // Brand List
          Container(
            width: 220,
            color: Colors.grey,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Brands', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _brands.length,
                    itemBuilder: (c, i) {
                      final b = _brands[i];
                      final data = b.data();
                      final name = (data['name'] as String?) ?? '';
                      final selected = (_selectedBrandId == b.id);
                      return Container(
                        color: selected ? Colors.white : Colors.grey,
                        child: ListTile(
                          selected: selected,
                          title: Text(name),
                          onTap: () {
                            setState(() {
                              _selectedBrandId = b.id;
                              _selectedBrandName = name;
                            });
                            _loadModels(b.id);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _editBrand(b.id, name)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteBrand(b.id)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Models List
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedBrandName == null ? 'Models' : 'Models of $_selectedBrandName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Model',
                          onPressed: _selectedBrandId == null ? null : _addModel,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _selectedBrandId == null
                        ? const Center(child: Text('Select a brand'))
                        : _currentModels.isEmpty
                            ? const Center(child: Text('No models for this brand'))
                            : ListView.builder(
                                itemCount: _currentModels.length,
                                itemBuilder: (c, i) {
                                  final m = _currentModels[i];
                                  final data = m.data();
                                  final name = (data['name'] as String?) ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontSize: 16),
                                            softWrap: true,
                                          ),
                                        ),
                                        IconButton(
                                          iconSize: 20,
                                          tooltip: 'Edit model',
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editModel(m.id, name),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          iconSize: 20,
                                          tooltip: 'Delete model',
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteModel(m.id),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
