// lib/utils/excel_exporter.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// Use your typed models
import '../models/enquiry.dart';
import '../models/expense.dart';
import '../models/service.dart';

class ExcelExporter {
  static Future<String> exportAll({
    bool includeEnquiries = true,
    bool includeExpenses = true,
    bool includeServices = true,
    String? fileName,
  }) async {
    final data = await _fetchData(
      includeEnquiries: includeEnquiries,
      includeExpenses: includeExpenses,
      includeServices: includeServices,
    );

    final excel = _buildWorkbook(
      enquiries: data.enquiries,
      expenses: data.expenses,
      services: data.services,
    );

    final defaultName =
        'mobile_car_spa_export_${DateTime.now().toIso8601String().replaceAll(':', '')}.xlsx';
    final usedFileName = fileName ?? defaultName;

    return _saveToAppDocs(excel, fileName: usedFileName);
  }

  static Future<_AllData> _fetchData({
    required bool includeEnquiries,
    required bool includeExpenses,
    required bool includeServices,
  }) async {
    final enquiries = includeEnquiries ? await _getEnquiriesFromFirestore() : <Enquiry>[];
    final expenses = includeExpenses ? await _getExpensesFromFirestore() : <Expense>[];
    final services = includeServices ? await _getServicesFromFirestore() : <Service>[];
    return _AllData(enquiries: enquiries, expenses: expenses, services: services);
  }

  static Future<List<Enquiry>> _getEnquiriesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('enquiries').get();
    return snapshot.docs
        .map((doc) => Enquiry.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  static Future<List<Expense>> _getExpensesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('expenses').get();
    return snapshot.docs
        .map((doc) => Expense.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  static Future<List<Service>> _getServicesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('services').get();
    return snapshot.docs
        .map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  static Excel _buildWorkbook({
    required List<Enquiry> enquiries,
    required List<Expense> expenses,
    required List<Service> services,
  }) {
    final excel = Excel.createExcel();
    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Enquiries
    final sheetEnquiries = excel['Enquiries'];
    sheetEnquiries.appendRow([
      'ID',
      'Invoice No',
      'Date',
      'Customer Name',
      'Phone Number',
      'Vehicle Type',
      'Vehicle Model',
      'Services',
      'Total Price',
      'Source',
      'Status',
      'Follow Up Date',
      'Location',
      'Notes',
    ]);
    _applyHeaderStyle(sheetEnquiries, headerStyle);

    for (final e in enquiries) {
      sheetEnquiries.appendRow([
        e.id ?? '',
        e.invoiceNumber?.toString() ?? '',
        _formatDateFlexible(e.date),
        e.customerName,
        e.phoneNumber,
        e.vehicleType,
        e.vehicleModel,
        e.services,
        e.totalPrice.toStringAsFixed(2),
        e.source,
        e.status,
        _formatDateFlexible(e.followUpDate),
        e.location ?? '',
        e.notes ?? '',
      ]);
    }
    _autoFitColumns(sheetEnquiries, maxColumns: 14);

    // Expenses
    final sheetExpenses = excel['Expenses'];
    sheetExpenses.appendRow(['ID', 'Date', 'Category', 'Amount', 'Notes']);
    _applyHeaderStyle(sheetExpenses, headerStyle);

    for (final x in expenses) {
      sheetExpenses.appendRow([
        x.id ?? '',
        _formatDateFlexible(x.date),
        x.category ?? '',
        x.amount.toStringAsFixed(2),
        x.notes ?? '',
      ]);
    }
    _autoFitColumns(sheetExpenses, maxColumns: 5);

    // Services
    final sheetServices = excel['Services'];
    sheetServices.appendRow(['ID', 'Name', 'Price', 'Vehicle Type']);
    _applyHeaderStyle(sheetServices, headerStyle);

    for (final s in services) {
      sheetServices.appendRow([
        s.id ?? '',
        s.name,
        s.price.toStringAsFixed(2),
        s.vehicleType,
      ]);
    }
    _autoFitColumns(sheetServices, maxColumns: 4);

    return excel;
  }

  // Accepts String/DateTime/Timestamp? as argument (enquiries keep date as String)
  static String _formatDateFlexible(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(date.toDate());
    }
    if (date is DateTime) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
    if (date is String) {
      // If string looks like ISO or yyyy-MM-dd, return as-is; else try parse
      try {
        final d = DateTime.parse(date);
        return DateFormat('yyyy-MM-dd').format(d);
      } catch (_) {
        // Fallback for already formatted strings
        return date;
      }
    }
    return '';
  }

  static Future<String> _saveToAppDocs(Excel excel, {required String fileName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/$fileName';
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel');
    }
    await File(outPath).writeAsBytes(bytes, flush: true);
    return outPath;
  }

  static void _applyHeaderStyle(Sheet sheet, CellStyle style) {
    if (sheet.maxCols == 0) return;
    for (var c = 0; c < sheet.maxCols; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.cellStyle = style;
    }
  }

  static void _autoFitColumns(Sheet sheet, {required int maxColumns}) {
    for (var col = 0; col < maxColumns; col++) {
      int maxLen = 0;
      for (var r = 0; r < sheet.maxRows; r++) {
        final s = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r)).value?.toString() ?? '';
        if (s.length > maxLen) maxLen = s.length;
      }
      final width = _clampDouble(maxLen * 1.2, 10, 40);
      sheet.setColWidth(col, width);
    }
  }

  static double _clampDouble(double v, double min, double max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}

class _AllData {
  final List<Enquiry> enquiries;
  final List<Expense> expenses;
  final List<Service> services;
  _AllData({
    required this.enquiries,
    required this.expenses,
    required this.services,
  });
}
