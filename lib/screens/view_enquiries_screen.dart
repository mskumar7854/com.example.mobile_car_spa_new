// lib/screens/view_enquiries_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_enquiry_screen.dart';
import '../models/enquiry.dart';
import '../services/firestore_service.dart';

// Follow-up filter modes (supports deep link from Dashboard)
enum FollowUpMode { none, today, next7, overdue }

class ViewEnquiriesScreen extends StatefulWidget {
  final FollowUpMode initialFollowUpMode;
  const ViewEnquiriesScreen({super.key, this.initialFollowUpMode = FollowUpMode.none});

  @override
  State<ViewEnquiriesScreen> createState() => _ViewEnquiriesScreenState();
}

class _ViewEnquiriesScreenState extends State<ViewEnquiriesScreen> {
  final FirestoreService firestoreService = FirestoreService();

  List<Enquiry> filtered = [];
  final TextEditingController searchCtrl = TextEditingController();

  // Filters (selected)
  String? _status;
  String? _source;
  String? _vehicleType;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Follow-up filter state
  FollowUpMode _followUpMode = FollowUpMode.none;

  // Dynamic options built from data
  final Set<String> _statusOptions = {};
  final Set<String> _sourceOptions = {};
  final Set<String> _vehicleTypeOptions = {};
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _followUpMode = widget.initialFollowUpMode;
    searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _norm(String? v) {
    if (v == null) return '';
    final t = v.trim();
    if (t.isEmpty) return '';
    return t.toUpperCase() + t.substring(1).toLowerCase();
  }

  DateTime _normalizeDate(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return DateTime(1970);
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    try {
      final p = DateTime.parse(raw.toString());
      return DateTime(p.year, p.month, p.day);
    } catch (_) {
      try {
        final p = DateFormat('dd-MM-yyyy').parse(raw.toString());
        return DateTime(p.year, p.month, p.day);
      } catch (_) {
        return DateTime(1970);
      }
    }
  }

  String _formatDayMonth(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    DateTime? d = DateTime.tryParse(s);
    if (d == null) {
      try {
        d = DateFormat('dd-MM-yyyy').parse(s);
      } catch (_) {
        return '';
      }
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }

  bool _matchFollowUp(Enquiry e) {
    if (_followUpMode == FollowUpMode.none) return true;
    final raw = e.followUpDate;
    if (raw == null || raw.isEmpty) return false;
    DateTime d;
    try {
      d = DateTime.parse(raw);
    } catch (_) {
      return false;
    }
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dd = DateTime(d.year, d.month, d.day);
    switch (_followUpMode) {
      case FollowUpMode.today:
        return dd == today;
      case FollowUpMode.next7:
        final end = today.add(const Duration(days: 7));
        return (dd.isAtSameMomentAs(today) || dd.isAfter(today)) &&
            dd.isBefore(end.add(const Duration(days: 1)));
      case FollowUpMode.overdue:
        return dd.isBefore(today);
      case FollowUpMode.none:
        return true;
    }
  }

  bool _matches(Enquiry e, String query) {
    if (query.isNotEmpty) {
      final hay = [
        e.customerName,
        e.phoneNumber,
        e.vehicleModel,
        e.vehicleType,
        e.services,
        e.status,
        e.source,
        e.location ?? '',
        e.notes ?? '',
      ].join(' ').toLowerCase();
      if (!hay.contains(query)) return false;
    }
    final statusN = _norm(e.status);
    final sourceN = _norm(e.source);
    final typeN = _norm(e.vehicleType);
    if (_status?.isNotEmpty == true && statusN != _status) return false;
    if (_source?.isNotEmpty == true && sourceN != _source) return false;
    if (_vehicleType?.isNotEmpty == true && typeN != _vehicleType) return false;
    if (_fromDate != null || _toDate != null) {
      final d = _normalizeDate(e.date);
      if (_fromDate != null &&
          d.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
        return false;
      }
      if (_toDate != null &&
          d.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day))) {
        return false;
      }
    }
    if (!_matchFollowUp(e)) return false;
    return true;
  }

  void _applyFilters() {
    final query = searchCtrl.text.trim().toLowerCase();
    setState(() {
      filtered = filtered.where((e) => _matches(e, query)).toList();
    });
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfWeek(DateTime d) => _startOfDay(d).subtract(Duration(days: d.weekday - 1));
  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 6));
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

  void _setToday() {
    final now = DateTime.now();
    final today = _startOfDay(now);
    setState(() {
      _fromDate = today;
      _toDate = today;
    });
    _applyFilters();
  }

  void _setThisWeek() {
    final now = DateTime.now();
    setState(() {
      _fromDate = _startOfWeek(now);
      _toDate = _endOfWeek(now);
    });
    _applyFilters();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = _startOfMonth(now);
      _toDate = _endOfMonth(now);
    });
    _applyFilters();
  }

  void _openFilters() {
    final statusList = _statusOptions.toList()..sort();
    final sourceList = _sourceOptions.toList()..sort();
    final vehicleTypeList = _vehicleTypeOptions.toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusList.isNotEmpty) ...[
                  _sectionTitle('Status'),
                  Wrap(
                    spacing: 8,
                    children: statusList.map((s) {
                      return ChoiceChip(
                        label: Text(s),
                        selected: _status == s,
                        onSelected: (_) {
                          setState(() => _status = (_status == s) ? null : s);
                          _applyFilters();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (sourceList.isNotEmpty) ...[
                  _sectionTitle('Source'),
                  Wrap(
                    spacing: 8,
                    children: sourceList.map((s) {
                      return ChoiceChip(
                        label: Text(s),
                        selected: _source == s,
                        onSelected: (_) {
                          setState(() => _source = (_source == s) ? null : s);
                          _applyFilters();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (vehicleTypeList.isNotEmpty) ...[
                  _sectionTitle('Vehicle Type'),
                  Wrap(
                    spacing: 8,
                    children: vehicleTypeList.map((v) {
                      return ChoiceChip(
                        label: Text(v),
                        selected: _vehicleType == v,
                        onSelected: (_) {
                          setState(() => _vehicleType = (_vehicleType == v) ? null : v);
                          _applyFilters();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                _sectionTitle('Date Range'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          (_fromDate == null || _toDate == null)
                              ? 'Pick range'
                              : '${_df.format(_fromDate!)} → ${_df.format(_toDate!)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_fromDate != null || _toDate != null)
                      IconButton(
                        tooltip: 'Clear date',
                        onPressed: () {
                          setState(() {
                            _fromDate = null;
                            _toDate = null;
                          });
                          _applyFilters();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _setToday,
                        icon: const Icon(Icons.today),
                        label: const Text('Today'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _setThisWeek,
                        icon: const Icon(Icons.date_range),
                        label: const Text('This Week'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _setThisMonth,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('This Month'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _clearFilters();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Clear Filters'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.check),
                        label: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2, 1, 1);
    final last = DateTime(now.year + 2, 12, 31);
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _fromDate = DateTime(range.start.year, range.start.month, range.start.day);
        _toDate = DateTime(range.end.year, range.end.month, range.end.day);
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _status = null;
      _source = null;
      _vehicleType = null;
      _fromDate = null;
      _toDate = null;
      // Follow-up filter remains as set via AppBar actions; user can clear via chips bar
    });
    _applyFilters();
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _callNumber(String number) async {
    final n = number.trim();
    if (n.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: n);
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String number, {String? message}) async {
    // Use the unified channel name, same as AddEnquiryScreen
    const channel = MethodChannel("mobile.car.mobile_car_spa/whatsapp");
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (cleaned.isEmpty) return;
    try {
      final ok = await channel.invokeMethod("launchWhatsApp", {
        "phone": cleaned,
        "message": message ?? "",
      });
      if (ok != true) {
        final text = Uri.encodeComponent(message ?? '');
        final uri = Uri.parse('https://wa.me/$cleaned?text=$text');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final text = Uri.encodeComponent(message ?? '');
      final uri = Uri.parse('https://wa.me/$cleaned?text=$text');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  double _capTextScale(BuildContext context, {double maxScale = 1.2}) {
    final mq = MediaQuery.maybeOf(context);
    final current = mq?.textScaleFactor ?? 1.0;
    return current > maxScale ? maxScale : current;
  }

  Widget _enquiryRow(Enquiry e) {
    final dayMonth = _formatDayMonth(e.date);
    final capped = _capTextScale(context, maxScale: 1.2);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: capped),
      child: Card(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddEnquiryScreen(enquiry: e)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dayMonth • ${e.vehicleModel.isNotEmpty ? e.vehicleModel : '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Call',
                  icon: const Icon(Icons.call, color: Colors.green, size: 20),
                  onPressed: (e.phoneNumber.isEmpty) ? null : () => _callNumber(e.phoneNumber),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'WhatsApp',
                  icon: Image.asset(
                    'assets/icon/whatsapp.png',
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.high,
                  ),
                  onPressed: (e.phoneNumber.isEmpty)
                      ? null
                      : () => _openWhatsApp(
                            e.phoneNumber,
                            message: 'Hello ${e.customerName}, regarding your enquiry for ${e.vehicleModel}.',
                          ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final chips = <Widget>[];
    if (_status?.isNotEmpty == true) {
      chips.add(_chip('Status: $_status', () {
        setState(() => _status = null);
        _applyFilters();
      }));
    }
    if (_source?.isNotEmpty == true) {
      chips.add(_chip('Source: $_source', () {
        setState(() => _source = null);
        _applyFilters();
      }));
    }
    if (_vehicleType?.isNotEmpty == true) {
      chips.add(_chip('Type: $_vehicleType', () {
        setState(() => _vehicleType = null);
        _applyFilters();
      }));
    }
    if (_fromDate != null || _toDate != null) {
      final label =
          '${_fromDate != null ? _df.format(_fromDate!) : '...'} → ${_toDate != null ? _df.format(_toDate!) : '...'}';
      chips.add(_chip('Date: $label', () {
        setState(() {
          _fromDate = null;
          _toDate = null;
        });
        _applyFilters();
      }));
    }
    if (_followUpMode != FollowUpMode.none) {
      final label = _followUpMode == FollowUpMode.today
          ? 'Follow-up: Today'
          : _followUpMode == FollowUpMode.next7
              ? 'Follow-up: Next 7 days'
              : 'Follow-up: Overdue';
      chips.add(_chip(label, () {
        setState(() => _followUpMode = FollowUpMode.none);
        _applyFilters();
      }));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...chips,
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear All'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _setToday,
                icon: const Icon(Icons.today),
                label: const Text('Today'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(text),
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Enquiries'),
        actions: [
          IconButton(tooltip: 'Today', icon: const Icon(Icons.today), onPressed: _setToday),
          IconButton(tooltip: 'This Week', icon: const Icon(Icons.date_range), onPressed: _setThisWeek),
          IconButton(tooltip: 'This Month', icon: const Icon(Icons.calendar_month), onPressed: _setThisMonth),
          IconButton(tooltip: 'Filters', icon: const Icon(Icons.filter_alt), onPressed: _openFilters),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by Name, Phone, Vehicle',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchCtrl.clear();
                          _applyFilters();
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Enquiry>>(
              stream: firestoreService.getEnquiries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final enquiries = snapshot.data ?? [];

                if (enquiries.isNotEmpty) {
                  _statusOptions
                    ..clear()
                    ..addAll(enquiries.map((e) => _norm(e.status)).where((s) => s.isNotEmpty));
                  _sourceOptions
                    ..clear()
                    ..addAll(enquiries.map((e) => _norm(e.source)).where((s) => s.isNotEmpty));
                  _vehicleTypeOptions
                    ..clear()
                    ..addAll(enquiries.map((e) => _norm(e.vehicleType)).where((s) => s.isNotEmpty));
                }

                final query = searchCtrl.text.trim().toLowerCase();
                filtered = enquiries.where((e) => _matches(e, query)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No enquiries match the current search/filters'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    return _enquiryRow(e);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActiveFiltersBar(),
    );
  }
}
