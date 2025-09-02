import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/enquiry.dart';
import '../models/service.dart';
import '../services/firestore_service.dart';
import '../utils/invoice_pdf.dart';

class AddEnquiryScreen extends StatefulWidget {
  final Enquiry? enquiry;
  const AddEnquiryScreen({super.key, this.enquiry});
  @override
  State<AddEnquiryScreen> createState() => _AddEnquiryScreenState();
}

class _BrandModel {
  final String brand, model;
  const _BrandModel(this.brand, this.model);
}

class _AddEnquiryScreenState extends State<AddEnquiryScreen> {
  static const MethodChannel _channel =
      MethodChannel('mobile.car.mobile_car_spa/whatsapp');
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _brandsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _modelsSub;
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  String vehicleType = 'Hatchback';
  String status = 'New';
  String source = 'WhatsApp';
  DateTime? followUpDate;
  String? brand;
  String? model;
  List<String> brandOptions = [];
  Map<String, List<String>> modelsByBrand = {};
  List<Service> serviceList = [];
  Service? selectedService;
  static String? _lastVehicleType;
  static String? _lastStatus;
  static String? _lastSource;
  late String _initialStatus;

  @override
  void initState() {
    super.initState();
    _startListeningBrands();
    _loadServices();
    if (widget.enquiry == null) {
      if (_lastVehicleType != null) vehicleType = _lastVehicleType!;
      if (_lastStatus != null) status = _lastStatus!;
      if (_lastSource != null) source = _lastSource!;
    } else {
      final e = widget.enquiry!;
      nameCtrl.text = e.customerName;
      phoneCtrl.text = e.phoneNumber;
      locationCtrl.text = e.location ?? '';
      notesCtrl.text = e.notes ?? '';
      vehicleType = e.vehicleType;
      status = e.status;
      source = e.source;
      followUpDate = e.followUpDate != null ? DateTime.tryParse(e.followUpDate!) : null;
      priceCtrl.text = e.totalPrice.toStringAsFixed(0);
      final bm = _splitBrandModel(e.vehicleModel);
      brand = bm.brand.isNotEmpty ? bm.brand : null;
      model = bm.model.isNotEmpty ? bm.model : null;
      if (brand != null) {
        _listenModelsByBrand(brand!);
      }
    }
    _initialStatus = widget.enquiry?.status ?? 'New';
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    locationCtrl.dispose();
    notesCtrl.dispose();
    priceCtrl.dispose();
    _brandsSub?.cancel();
    _modelsSub?.cancel();
    super.dispose();
  }

  void _startListeningBrands() {
    _brandsSub = firestore
        .collection('brands')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      final brands =
          snapshot.docs.map((doc) => (doc.data()['name'] as String?) ?? '').where((e) => e.isNotEmpty).toList();
      setState(() {
        brandOptions = brands;
        if (brand == null || !brandOptions.contains(brand)) {
          brand = brands.isNotEmpty ? brands.first : null;
          model = null;
          if (brand != null) {
            _listenModelsByBrand(brand!);
          } else {
            modelsByBrand.clear();
          }
        }
      });
    });
  }

  void _listenModelsByBrand(String brandName) async {
    _modelsSub?.cancel();
    final brandQuery = await firestore
        .collection('brands')
        .where('name', isEqualTo: brandName)
        .limit(1)
        .get();
    if (brandQuery.docs.isEmpty) {
      setState(() {
        modelsByBrand[brandName] = [];
        model = null;
      });
      return;
    }
    final brandDocId = brandQuery.docs.first.id;
    _modelsSub = firestore
        .collection('brands')
        .doc(brandDocId)
        .collection('models')
        .orderBy('name')
        .snapshots()
        .listen((modelSnapshot) {
      final modelNames = modelSnapshot.docs
          .map((doc) => (doc.data()['name'] as String?) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() {
        modelsByBrand[brandName] = modelNames;
        if (model != null && !modelNames.contains(model)) model = null;
      });
    });
  }

  Future<void> _loadServices() async {
    try {
      final snapshot = await firestore.collection('services').orderBy('name').get();
      final services = snapshot.docs
          .map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      Service? preselect;
      if (widget.enquiry != null) {
        final currentName = widget.enquiry!.services;
        if (currentName.isNotEmpty) {
          preselect = services.firstWhere(
            (s) => s.name == currentName,
            orElse: () => Service(name: '', price: 0, vehicleType: ''),
          );
          if (preselect.name.isEmpty) preselect = null;
        }
      }
      if (!mounted) return;
      setState(() {
        serviceList = services;
        selectedService = preselect;
      });
    } catch (e) {
      _toast('Failed to load services.');
    }
  }

  _BrandModel _splitBrandModel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const _BrandModel('', '');
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) return _BrandModel(parts.first, '');
    final b = parts.first;
    final m = parts.sublist(1).join(' ').trim();
    return _BrandModel(b, m);
  }

  Future<void> sendWhatsAppMessage(String phone, String message) async {
    try {
      final bool result = await _launchWhatsAppNative(phone, message);
      if (!result) {
        final normalizedPhone = _normalizePhone(phone);
        final header = normalizedPhone.isEmpty ? '' : 'To: $normalizedPhone\n';
        await Share.share(
          header + message,
          subject: 'WhatsApp Message',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 1, 1),
        );
      }
    } catch (e) {
      debugPrint('Error sending WhatsApp message: $e');
    }
  }

  Future<bool> _launchWhatsAppNative(String phone, String message) async {
    try {
      final bool result = await _channel.invokeMethod('launchWhatsApp', {
        'phone': phone,
        'message': message,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to open WhatsApp: ${e.message}');
    }
    return false;
  }

  String _normalizePhone(String phone) {
    final s = phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (s.isEmpty) return '';
    if (s.startsWith('+')) return s;
    if (s.length == 10) return '+91$s';
    return '+$s';
  }

  String _newEnquiryMessage(String customer) => '''
Hi $customer, thank you for speaking with our Mobile Car Spa 🚗✨ team today. 
If you have any more questions, feel free to contact us anytime or check our website 👉 [https://www.mobilecarspa.in](https://www.mobilecarspa.in)
We look forward to serving you soon! 🙏
– Team Mobile Car Spa
''';

  String _convertedMessage(String customer) => '''
Hi $customer, thank you for choosing Mobile Car Spa 🚗✨. 
Your service has been successfully completed, and we hope you loved the shine! 🌟 
We’d love to hear your feedback 🙏 Please take a moment to share your experience/review — it really helps us improve and serve you better 👉 [https://g.page/r/CQd67R5emudzEAE/review](https://g.page/r/CQd67R5emudzEAE/review). 
Looking forward to seeing you again!
– Team Mobile Car Spa
''';

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    _lastVehicleType = vehicleType;
    _lastStatus = status;
    _lastSource = source;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final vehicleModel =
        [brand, model].where((e) => e != null && e!.isNotEmpty).join(' ');
    var enquiry = Enquiry(
      id: widget.enquiry?.id,
      customerName: nameCtrl.text,
      phoneNumber: phoneCtrl.text,
      location: locationCtrl.text,
      notes: notesCtrl.text,
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      services: selectedService?.name ?? '',
      totalPrice: price,
      source: source,
      status: status,
      followUpDate: followUpDate?.toIso8601String(),
      date: widget.enquiry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final isNew = widget.enquiry == null;
    try {
      if (isNew) {
        final nextInvoiceNumber = await firestoreService.getNextInvoiceNumber();
        enquiry = enquiry.copyWith(invoiceNumber: nextInvoiceNumber);
        await firestoreService.addEnquiry(enquiry);
      } else {
        await firestoreService.updateEnquiry(enquiry);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
      return;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customer = nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Sir/Madam';
      if (isNew) {
        await sendWhatsAppMessage(phoneCtrl.text, _newEnquiryMessage(customer));
      } else if (_initialStatus.toLowerCase() != 'converted' &&
          status.toLowerCase() == 'converted') {
        await sendWhatsAppMessage(phoneCtrl.text, _convertedMessage(customer));
      }
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    if (widget.enquiry?.id == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Enquiry?'),
            content: Text(
                'Are you sure you want to delete ${widget.enquiry!.customerName}\'s enquiry?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await firestoreService.deleteEnquiry(widget.enquiry!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> launchCall(String phone) async {
    if (phone.trim().isEmpty) {
      _toast('Please enter a phone number');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Cannot place call');
    }
  }

  Future<void> launchWhatsApp(String phone) async {
    await sendWhatsAppMessage(phone, '');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: followUpDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null && mounted) {
      setState(() {
        followUpDate = selected;
      });
    }
  }

  Future<void> _printInvoice(Enquiry enquiry) async {
    final regNo = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Car Registration Number'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'TNAB1234'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('OK')),
          ],
        );
      },
    );
    if (regNo == null || regNo.isEmpty) return;
    try {
      await generateAndPrintInvoicePDF(
        date: enquiry.date,
        invoiceNumber: enquiry.invoiceNumber?.toString() ?? 'N/A',
        customerName: enquiry.customerName,
        carModel: enquiry.vehicleModel,
        regNo: regNo,
        description: enquiry.services,
        amount: enquiry.totalPrice,
        signatureAssetPath: 'assets/sign.jpg',
        customerAddress: enquiry.location ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e')),
        );
      }
    }
  }

  InputDecoration _input(String label, {Widget? prefixIcon}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E7EF))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        prefixIcon: prefixIcon,
      );

  Widget _buildCardSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
          const Divider(),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsList = brand != null ? (modelsByBrand[brand!] ?? []) : <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.enquiry == null ? 'Add Enquiry' : 'Edit Enquiry'),
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () => launchCall(phoneCtrl.text)),
          IconButton(icon: const Icon(Icons.chat), onPressed: () => launchWhatsApp(phoneCtrl.text)),
          if (widget.enquiry != null) ...[
            IconButton(icon: const Icon(Icons.delete), onPressed: _confirmDelete),
            IconButton(icon: const Icon(Icons.print), onPressed: () => _printInvoice(widget.enquiry!)),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildCardSection(
                  title: "Customer",
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration:
                            _input('Customer Name', prefixIcon: const Icon(Icons.person)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration:
                            _input('Phone Number', prefixIcon: const Icon(Icons.phone)),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter phone';
                          if (v.trim().length < 10) return 'Enter valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationCtrl,
                        decoration: _input('Location', prefixIcon: const Icon(Icons.location_on)),
                      ),
                    ],
                  ),
                ),
                _buildCardSection(
                  title: "Vehicle",
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration:
                            _input('Vehicle Type', prefixIcon: const Icon(Icons.directions_car)),
                        value: vehicleType,
                        items: const [
                          DropdownMenuItem(value: 'Hatchback', child: Text('Hatchback')),
                          DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                          DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                          DropdownMenuItem(value: 'MUV', child: Text('MUV')),
                          DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                          DropdownMenuItem(value: 'Luxury', child: Text('Luxury')),
                        ],
                        onChanged: (v) => setState(() => vehicleType = v!),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: brand != null && brandOptions.contains(brand) ? brand : null,
                              decoration:
                                  _input('Brand', prefixIcon: const Icon(Icons.local_offer)),
                              items: brandOptions
                                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  brand = val;
                                  model = null;
                                  if (brand != null) _listenModelsByBrand(brand!);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: modelsList.contains(model) ? model : null,
                              decoration:
                                  _input('Model', prefixIcon: const Icon(Icons.directions_car)),
                              items: modelsList
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (val) => setState(() => model = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildCardSection(
                  title: "Service",
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<Service>(
                          decoration: _input('Package', prefixIcon: const Icon(Icons.build)),
                          value: selectedService,
                          validator: (v) => v == null ? 'Select package' : null,
                          items: serviceList
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedService = val;
                              if (val != null &&
                                  (priceCtrl.text.isEmpty || double.tryParse(priceCtrl.text) == null)) {
                                priceCtrl.text = val.price.toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: priceCtrl,
                          decoration:
                              _input('Price (₹)', prefixIcon: const Icon(Icons.currency_rupee)),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter price';
                            if (double.tryParse(val) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCardSection(
                  title: "Status & Source",
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: _input('Status', prefixIcon: const Icon(Icons.flag)),
                          items: const [
                            DropdownMenuItem(value: 'New', child: Text('New')),
                            DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
                            DropdownMenuItem(value: 'Converted', child: Text('Converted')),
                            DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                          ],
                          onChanged: (val) => setState(() => status = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: source,
                          decoration: _input('Source', prefixIcon: const Icon(Icons.source)),
                          items: const [
                            DropdownMenuItem(value: 'WhatsApp', child: Text('WhatsApp')),
                            DropdownMenuItem(value: 'Website', child: Text('Website')),
                            DropdownMenuItem(value: 'Referral', child: Text('Referral')),
                            DropdownMenuItem(value: 'Mail', child: Text('Mail')),
                            DropdownMenuItem(value: 'Existing', child: Text('Existing')),
                            DropdownMenuItem(value: 'Field Visit', child: Text('Field Visit')),
                            DropdownMenuItem(value: 'GMB', child: Text('GMB')),
                          ],
                          onChanged: (val) => setState(() => source = val!),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCardSection(
                  title: "Follow-up",
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text(
                            followUpDate == null
                                ? 'Set Follow-up Date'
                                : DateFormat('yyyy-MM-dd').format(followUpDate!),
                          ),
                          onPressed: _pickDate,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (followUpDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => followUpDate = null),
                        ),
                    ],
                  ),
                ),
                _buildCardSection(
                  title: "Notes",
                  child: TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: _input('Notes'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 3,
                    ),
                    onPressed: save,
                  ),
                ),
                if (widget.enquiry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print Invoice'),
                        onPressed: () => _printInvoice(widget.enquiry!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
