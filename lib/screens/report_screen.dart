import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../models/enquiry.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

enum ReportChartMode { daily, monthly }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final firestoreService = FirestoreService();

  int totalEnquiries = 0;
  double totalRevenue = 0;
  double totalExpenses = 0;
  double get totalProfit => totalRevenue - totalExpenses;

  List<Map<String, dynamic>> dailyRows = [];
  bool loading = true;

  ReportChartMode chartMode = ReportChartMode.daily;

  Stream<List<Enquiry>>? _enquiriesStream;
  Stream<List<Expense>>? _expensesStream;
  StreamSubscription? _combinedSub;

  // Toggle to count revenue only from Converted enquiries (aligns with Dashboard)
  final bool revenueOnlyFromConverted = true;

  @override
  void initState() {
    super.initState();
    _enquiriesStream = firestoreService.getEnquiries();
    _expensesStream = firestoreService.getExpenses();
    _subscribeToData();
  }

  @override
  void dispose() {
    _combinedSub?.cancel();
    super.dispose();
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

  void _subscribeToData() {
    _combinedSub?.cancel();
    _combinedSub = Rx.combineLatest2<List<Enquiry>, List<Expense>, void>(
      _enquiriesStream!,
      _expensesStream!,
      (enquiries, expenses) {
        if (!mounted) return;

        // Aggregate by date key yyyy-MM-dd
        final Map<String, Map<String, dynamic>> dayMap = {};

        bool isConverted(String? s) => (s ?? '').trim().toLowerCase() == 'converted';

        // Enquiries aggregation
        for (final e in enquiries) {
          final key = DateFormat('yyyy-MM-dd').format(_normalizeDate(e.date));
          final revenue = revenueOnlyFromConverted && !isConverted(e.status) ? 0.0 : e.totalPrice;
          dayMap.putIfAbsent(key, () => {
                'Date': key,
                'Enquiries': 0,
                'Revenue': 0.0,
                'Expenses': 0.0,
                'Profit': 0.0,
              });
          dayMap[key]!['Enquiries'] = (dayMap[key]!['Enquiries'] as int) + 1;
          dayMap[key]!['Revenue'] = (dayMap[key]!['Revenue'] as double) + revenue;
        }

        // Expenses aggregation
        for (final x in expenses) {
          final key = DateFormat('yyyy-MM-dd').format(_normalizeDate(x.date));
          final amount = x.amount;
          dayMap.putIfAbsent(key, () => {
                'Date': key,
                'Enquiries': 0,
                'Revenue': 0.0,
                'Expenses': 0.0,
                'Profit': 0.0,
              });
          dayMap[key]!['Expenses'] = (dayMap[key]!['Expenses'] as double) + amount;
        }

        // Profit per day
        for (final entry in dayMap.values) {
          final revenue = (entry['Revenue'] as num).toDouble();
          final expenses = (entry['Expenses'] as num).toDouble();
          entry['Profit'] = revenue - expenses;
        }

        // Sort rows by date desc
        final rows = dayMap.values.toList()
          ..sort((a, b) {
            final aDate = a['Date'] as String? ?? '';
            final bDate = b['Date'] as String? ?? '';
            return bDate.compareTo(aDate);
          });

        // Totals
        int sumEnquiries = 0;
        double sumRevenue = 0.0;
        double sumExpenses = 0.0;
        for (final r in rows) {
          sumEnquiries += (r['Enquiries'] as num).toInt();
          sumRevenue += (r['Revenue'] as num).toDouble();
          sumExpenses += (r['Expenses'] as num).toDouble();
        }

        setState(() {
          totalEnquiries = sumEnquiries;
          totalRevenue = sumRevenue;
          totalExpenses = sumExpenses;
          dailyRows = rows;
          loading = false;
        });
      },
    ).listen((_) {});
  }

  List<Map<String, dynamic>> getMonthlyRows(List<Map<String, dynamic>> dailyRows) {
    final Map<String, Map<String, dynamic>> monthMap = {};

    for (final row in dailyRows) {
      final date = (row['Date'] as String?) ?? '';
      final month = date.length >= 7 ? date.substring(0, 7) : 'Unknown';
      monthMap.putIfAbsent(month, () => {
            'Date': month,
            'Enquiries': 0,
            'Revenue': 0.0,
            'Expenses': 0.0,
            'Profit': 0.0,
          });
      monthMap[month]!['Enquiries'] =
          (monthMap[month]!['Enquiries'] as int) + ((row['Enquiries'] as num?)?.toInt() ?? 0);
      monthMap[month]!['Revenue'] =
          (monthMap[month]!['Revenue'] as double) + ((row['Revenue'] as num?)?.toDouble() ?? 0.0);
      monthMap[month]!['Expenses'] =
          (monthMap[month]!['Expenses'] as double) + ((row['Expenses'] as num?)?.toDouble() ?? 0.0);
      monthMap[month]!['Profit'] =
          (monthMap[month]!['Profit'] as double) + ((row['Profit'] as num?)?.toDouble() ?? 0.0);
    }

    final rows = monthMap.values.toList()
      ..sort((a, b) => (b['Date'] as String).compareTo(a['Date'] as String));
    return rows;
  }

  Widget chartModeSelector() {
    return Row(
      children: [
        const Text('Chart:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        DropdownButton<ReportChartMode>(
          value: chartMode,
          items: const [
            DropdownMenuItem(value: ReportChartMode.daily, child: Text('Daily')),
            DropdownMenuItem(value: ReportChartMode.monthly, child: Text('Monthly')),
          ],
          onChanged: (mode) {
            if (mode != null) setState(() => chartMode = mode);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartRows = chartMode == ReportChartMode.daily ? dailyRows : getMonthlyRows(dailyRows);
    final columns = ['Date', 'Enquiries', 'Revenue', 'Expenses', 'Profit'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Report'),
        backgroundColor: Colors.blue.shade800,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    reportSummaryCards(
                      enquiries: totalEnquiries,
                      revenue: totalRevenue,
                      expenses: totalExpenses,
                      profit: totalProfit,
                    ),
                    const SizedBox(height: 16),
                    chartModeSelector(),
                    const SizedBox(height: 8),
                    reportBarChart(chartRows, mode: chartMode),
                    const SizedBox(height: 10),
                    zebraReportTable(chartRows, columns),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
    );
  }
}

Widget reportSummaryCards({
  required int enquiries,
  required double revenue,
  required double expenses,
  required double profit,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _StatCard(
        label: 'Enquiries',
        value: enquiries.toString(),
        color: const Color(0xFF1E88E5),
        icon: Icons.question_answer,
      ),
      _StatCard(
        label: 'Revenue',
        value: '₹${revenue.toStringAsFixed(0)}',
        color: const Color(0xFF43A047),
        icon: Icons.attach_money,
      ),
      _StatCard(
        label: 'Expenses',
        value: '₹${expenses.toStringAsFixed(0)}',
        color: const Color(0xFFE53935),
        icon: Icons.money_off,
      ),
      _StatCard(
        label: 'Profit',
        value: '₹${profit.toStringAsFixed(0)}',
        color: const Color(0xFF00897B),
        icon: Icons.trending_up,
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 3,
      margin: const EdgeInsets.all(4),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget reportBarChart(List<Map<String, dynamic>> rows, {ReportChartMode mode = ReportChartMode.daily}) {
  final List<BarChartGroupData> barGroups = [];

  double maxY = 0.0;
  for (int i = 0; i < rows.length; i++) {
    final row = rows[i];
    final revenue = (row['Revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (row['Expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = (row['Profit'] as num?)?.toDouble() ?? 0.0;
    maxY = [maxY, revenue, expenses, profit].reduce((a, b) => a > b ? a : b);

    barGroups.add(
      BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(toY: revenue, color: Colors.green, width: 12),
          BarChartRodData(toY: expenses, color: Colors.red, width: 12),
          BarChartRodData(toY: profit, color: Colors.teal, width: 12),
        ],
      ),
    );
  }
  maxY = maxY * 1.2;

  return Card(
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY > 0 ? maxY : 100,
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                    final label = rows[idx]['Date']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        mode == ReportChartMode.monthly ? label : (label.length >= 5 ? label.substring(5) : label),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY > 0 ? (maxY / 5).clamp(1, double.infinity) : 20,
                  getTitlesWidget: (value, meta) => Text('₹${value.toInt()}'),
                  reservedSize: 40,
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: maxY > 0 ? (maxY / 5).clamp(1, double.infinity) : 20,
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.white70,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final texts = ['Revenue', 'Expenses', 'Profit'];
                  return BarTooltipItem(
                    '${texts[rodIndex]}: ₹${rod.toY.toInt()}',
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget zebraReportTable(List<Map<String, dynamic>> rows, List<String> columns) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade300),
        columns: columns
            .map((col) => DataColumn(
                  label: Text(
                    col,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ))
            .toList(),
        rows: List.generate(rows.length, (index) {
          final row = rows[index];
          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>(
              (states) => index.isEven ? Colors.white : Colors.grey,
            ),
            cells: columns.map((col) {
              final val = row[col];
              final isCurrency = col == 'Revenue' || col == 'Expenses' || col == 'Profit';
              String text;
              if (val is num && isCurrency) {
                text = '₹${val.toStringAsFixed(2)}';
              } else {
                text = val?.toString() ?? '';
              }
              final isNegProfit = col == 'Profit' && (val is num) && val < 0;
              return DataCell(Text(
                text,
                style: isNegProfit ? const TextStyle(color: Colors.red) : null,
              ));
            }).toList(),
          );
        }),
      ),
    ),
  );
}
