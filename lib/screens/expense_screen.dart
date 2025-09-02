import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final firestoreService = FirestoreService();
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  List<Expense> all = [];
  List<Expense> filtered = [];

  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  String? _categoryFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(_applyFilters);
    _subscribeToExpenses();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  void _subscribeToExpenses() {
    firestoreService.getExpenses().listen((expenses) {
      if (!mounted) return;
      setState(() {
        all = expenses;
        _applyFilters();
      });
    });
  }

  DateTime _nDate(dynamic raw) {
    if (raw == null) return DateTime(1970);
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    try {
      final parsed = DateTime.parse(raw.toString());
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return DateTime(1970);
    }
  }

  void _applyFilters() {
    final q = searchCtrl.text.toLowerCase().trim();

    // Parse selectedMonth into Date range
    final dateParsed = DateFormat('MMMM yyyy').parse(selectedMonth);
    _fromDate = DateTime(dateParsed.year, dateParsed.month, 1);
    _toDate = DateTime(dateParsed.year, dateParsed.month + 1, 0);

    setState(() {
      filtered = all.where((e) {
        final hay = [
          e.category ?? '',
          e.notes ?? '',
          _df.format(_nDate(e.date)),
          e.amount.toStringAsFixed(2),
        ].join(' ').toLowerCase();

        if (q.isNotEmpty && !hay.contains(q)) return false;

        if (_categoryFilter != null &&
            (e.category ?? '') != _categoryFilter) {
          return false;
        }

        final dt = _nDate(e.date);
        if (_fromDate != null && dt.isBefore(_fromDate!)) return false;
        if (_toDate != null && dt.isAfter(_toDate!)) return false;

        return true;
      }).toList();

      // Sort by date (newest first)
      filtered.sort((a, b) => _nDate(b.date).compareTo(_nDate(a.date)));
    });
  }

  double _getCategoryTotal(String category) =>
      filtered.where((e) => (e.category ?? '') == category)
          .fold(0.0, (sum, e) => sum + e.amount);

  double get _total =>
      filtered.fold(0.0, (sum, e) => sum + e.amount);

  // ---------------- Add Expense Modal ----------------
  Future<void> _showAddExpenseSheet({Expense? editing}) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController amountCtrl =
        TextEditingController(text: editing?.amount.toStringAsFixed(2) ?? '');
    final TextEditingController notesCtrl =
        TextEditingController(text: editing?.notes ?? '');
    String category = editing?.category ?? 'Fuel';
    DateTime selectedDate = editing?.date ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing == null ? "Add Expense" : "Edit Expense",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter amount';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Enter valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    'Fuel',
                    'Materials',
                    'Staff Salary',
                    'Marketing',
                    'Food',
                    'Misc',
                  ].map((cat) =>
                      DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) => category = val!,
                  decoration: const InputDecoration(
                      labelText: "Category", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text("Date: ${_df.format(selectedDate)}"),
                    const Spacer(),
                    TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365 * 2)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: const Text("Pick Date")),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final expense = Expense(
                        id: editing?.id,
                        category: category,
                        amount: double.parse(amountCtrl.text.trim()),
                        date: selectedDate,
                        notes: notesCtrl.text.trim(),
                      );
                      if (editing == null) {
                        await firestoreService.addExpense(expense);
                      } else {
                        await firestoreService.updateExpense(expense);
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)),
                  child: Text(editing == null ? "Save Expense" : "Update Expense"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Are you sure you want to delete ₹${expense.amount.toStringAsFixed(2)} under ${expense.category}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await firestoreService.deleteExpense(expense.id!);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Expenses")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: selectedMonth,
              decoration: const InputDecoration(
                labelText: "Select Month",
                border: OutlineInputBorder(),
              ),
              items: List.generate(12, (i) {
                final date = DateTime(DateTime.now().year, i + 1, 1);
                final formatted = DateFormat('MMMM yyyy').format(date);
                return DropdownMenuItem(
                    value: formatted, child: Text(formatted));
              }),
              onChanged: (val) {
                if (val != null) setState(() => selectedMonth = val);
                _applyFilters();
              },
            ),
          ),

          // Summary Cards
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSummaryCard(
                    "Total", _total, Colors.blue, Icons.account_balance_wallet),
                _buildSummaryCard(
                    "Fuel", _getCategoryTotal("Fuel"), Colors.orange, Icons.local_gas_station),
                _buildSummaryCard(
                    "Salary", _getCategoryTotal("Staff Salary"), Colors.green, Icons.people),
                _buildSummaryCard(
                    "Food", _getCategoryTotal("Food"), Colors.pink, Icons.fastfood),
                _buildSummaryCard(
                    "Others",
                    _total -
                        (_getCategoryTotal("Fuel") +
                            _getCategoryTotal("Staff Salary") +
                            _getCategoryTotal("Food")),
                    Colors.grey,
                    Icons.more_horiz),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: "Search expenses",
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Expenses List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("No expenses found"))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final dt = _df.format(_nDate(e.date));
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text((e.category ?? "X")[0])),
                          title: Text(e.category ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text("$dt • ${e.notes ?? ''}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "₹${e.amount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showAddExpenseSheet(editing: e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExpense(e),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text("₹${amount.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
