import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import 'add_enquiry_screen.dart';
import 'view_enquiries_screen.dart';
import 'expense_screen.dart';
import 'settings_screen.dart';

import '../models/enquiry.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService firestoreService = FirestoreService();

  // Monthly stats
  int totalEnquiries = 0;
  double totalRevenue = 0;
  double totalExpenses = 0;
  double profit = 0;

  // Daily stats
  int todayEnquiries = 0;
  double todayRevenue = 0;
  double todayExpenses = 0;
  double todayProfit = 0;

  // Today's follow-ups
  int _todayFollowUps = 0;
  bool _loadingFups = true;

  Stream<List<Enquiry>>? _enquiriesStream;
  Stream<List<Expense>>? _expensesStream;
  StreamSubscription? _combinedSub;

  @override
  void initState() {
    super.initState();
    _enquiriesStream = firestoreService.getEnquiries();
    _expensesStream = firestoreService.getExpenses();
    _subscribeStats();
  }

  @override
  void dispose() {
    _combinedSub?.cancel();
    super.dispose();
  }

  void _subscribeStats() {
    _combinedSub?.cancel();
    // Combine streams to avoid nested subscriptions and memory leaks
    _combinedSub = Rx.combineLatest2<List<Enquiry>, List<Expense>, void>(
      _enquiriesStream!,
      _expensesStream!,
      (enquiries, expenses) {
        if (!mounted) return;

        final today = DateTime.now();

        bool _isConverted(String? s) => (s ?? '').trim().toLowerCase() == 'converted';

        // Helpers
        DateTime _normaliseDate(dynamic rawDate) {
          if (rawDate == null || rawDate.toString().isEmpty) return DateTime(1970);
          if (rawDate is DateTime) return DateTime(rawDate.year, rawDate.month, rawDate.day);
          try {
            final parsed = DateTime.parse(rawDate.toString());
            return DateTime(parsed.year, parsed.month, parsed.day);
          } catch (_) {
            try {
              final parsedAlt = DateFormat('dd-MM-yyyy').parse(rawDate.toString());
              return DateTime(parsedAlt.year, parsedAlt.month, parsedAlt.day);
            } catch (_) {
              return DateTime(1970);
            }
          }
        }

        bool _isSameDay(dynamic dateValue, DateTime target) {
          final d = _normaliseDate(dateValue);
          return d.year == target.year && d.month == target.month && d.day == target.day;
        }

        bool _isInMonth(dynamic dateValue, DateTime target) {
          final d = _normaliseDate(dateValue);
          final start = DateTime(target.year, target.month, 1);
          final end = DateTime(target.year, target.month + 1, 0);
          return !d.isBefore(start) && !d.isAfter(end);
        }

        // Daily filters
        final todayEnqs = enquiries.where((e) => _isSameDay(e.date, today)).toList();
        final todayExps = expenses.where((x) => _isSameDay(x.date, today)).toList();
        final todayConverted = todayEnqs.where((e) => _isConverted(e.status)).toList();

        // Monthly filters
        final monthEnqs = enquiries.where((e) => _isInMonth(e.date, today)).toList();
        final monthExps = expenses.where((x) => _isInMonth(x.date, today)).toList();
        final monthConverted = monthEnqs.where((e) => _isConverted(e.status)).toList();

        // Sums
        final dRevenue = todayConverted.fold<double>(0.0, (sum, e) => sum + e.totalPrice);
        final dExpense = todayExps.fold<double>(0.0, (sum, x) => sum + x.amount);
        final mRevenue = monthConverted.fold<double>(0.0, (sum, e) => sum + e.totalPrice);
        final mExpense = monthExps.fold<double>(0.0, (sum, x) => sum + x.amount);

        // Follow-ups for today
        int followUpCount = 0;
        final nowDate = DateTime(today.year, today.month, today.day);
        for (final e in enquiries) {
          final raw = e.followUpDate;
          if (raw == null || raw.isEmpty) continue;
          try {
            final d = DateTime.parse(raw);
            final dd = DateTime(d.year, d.month, d.day);
            if (dd == nowDate) {
              followUpCount++;
            }
          } catch (_) {}
        }

        setState(() {
          todayEnquiries = todayEnqs.length;
          totalEnquiries = monthEnqs.length;

          todayRevenue = dRevenue;
          todayExpenses = dExpense;
          todayProfit = dRevenue - dExpense;

          totalRevenue = mRevenue;
          totalExpenses = mExpense;
          profit = mRevenue - mExpense;

          _todayFollowUps = followUpCount;
          _loadingFups = false;
        });
      },
    ).listen((_) {});
  }

  Future<void> _refresh() async {
    // Re-subscribe to force recompute without creating nested listeners
    _subscribeStats();
  }

  Widget statCard(String title, String value, Color color) {
    return Card(
      color: color,
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _todayFollowUpsCircleContent() {
    final String bigNumber = _loadingFups ? '…' : '$_todayFollowUps';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          bigNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Today's Follow-ups",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'This Month',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  todayStr,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          statCard('Enquiries Today', '$todayEnquiries', Colors.blue),
                          const SizedBox(height: 8),
                          statCard('Revenue Today', '₹${todayRevenue.toStringAsFixed(0)}', Colors.green),
                          const SizedBox(height: 8),
                          statCard('Expenses Today', '₹${todayExpenses.toStringAsFixed(0)}', Colors.red),
                          const SizedBox(height: 8),
                          statCard('Profit Today', '₹${todayProfit.toStringAsFixed(0)}', Colors.orange),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          statCard('Total Enquiries', '$totalEnquiries', Colors.blue),
                          const SizedBox(height: 8),
                          statCard('Revenue This Month', '₹${totalRevenue.toStringAsFixed(0)}', Colors.green),
                          const SizedBox(height: 8),
                          statCard('Expenses This Month', '₹${totalExpenses.toStringAsFixed(0)}', Colors.red),
                          const SizedBox(height: 8),
                          statCard('Profit This Month', '₹${profit.toStringAsFixed(0)}', Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(70),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ViewEnquiriesScreen(
                            initialFollowUpMode: FollowUpMode.today,
                          ),
                        ),
                      ).then((_) {
                        if (!mounted) return;
                        _refresh();
                      });
                    },
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.deepOrange, Colors.orangeAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(child: _todayFollowUpsCircleContent()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                dashboardButton('➕ Add Enquiry', Icons.add, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEnquiryScreen()),
                  ).then((_) {
                    if (!mounted) return;
                    _refresh();
                  });
                }),
                const SizedBox(height: 8),
                dashboardButton('📋 View All Enquiries', Icons.list, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViewEnquiriesScreen()),
                  ).then((_) {
                    if (!mounted) return;
                    _refresh();
                  });
                }),
                const SizedBox(height: 8),
                dashboardButton('💰 Add Expense', Icons.money, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpenseScreen()),
                  ).then((_) {
                    if (!mounted) return;
                    _refresh();
                  });
                }),
                const SizedBox(height: 8),
                dashboardButton('⚙️ Settings & Utilities', Icons.settings, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) {
                    if (!mounted) return;
                    _refresh();
                  });
                }),
                const SizedBox(height: 16),
                const Text('Pull down to refresh stats', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
