import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

Future<void> generateAndPrintInvoicePDF({
  required String date,
  required String invoiceNumber,
  required String customerName,
  required String customerAddress,
  required String carModel,
  required String regNo,
  required String description,
  required double amount,
  required String signatureAssetPath, // e.g. 'assets/sign.jpg'
  double advance = 0.0, // optional, for future use
  double taxRate = 0.0, // optional percent, for future use (e.g., 18 => 18%)
}) async {
  // Load signature image
  late pw.MemoryImage signatureImage;
  try {
    final byteData = await rootBundle.load(signatureAssetPath);
    signatureImage = pw.MemoryImage(byteData.buffer.asUint8List());
  } catch (e) {
    // If signature not available, use a transparent 1x1 pixel
    final transparent = List<int>.filled(4, 0);
    signatureImage = pw.MemoryImage(Uint8List.fromList(transparent));
  }

  String _formatDateToDDMMYYYY(String raw) {
    // Accept yyyy-MM-dd or ISO; fallback: return raw
    try {
      DateTime d;
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        // Try dd-MM-yyyy
        d = DateFormat('dd-MM-yyyy').parse(raw);
      }
      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    } catch (_) {
      return raw;
    }
  }

  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // Optional tax/total logic (kept simple; adjust when adding multiple lines)
  final subtotal = amount;
  final tax = (taxRate > 0) ? (subtotal * (taxRate / 100.0)) : 0.0;
  final total = subtotal + tax;
  final advanceAmt = advance.clamp(0.0, total);
  final balance = (total - advanceAmt).clamp(0.0, double.infinity);

  final pdf = pw.Document();

  pw.Widget _kv(String k, String v, {bool boldKey = true}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k, style: pw.TextStyle(fontWeight: boldKey ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10)),
        pw.Text(v, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('MOBILE CAR SPA',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.SizedBox(height: 2),
                        pw.Text('Vembuli amman koil street, Perungudi', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Chennai - 600 096.', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Phone: 9841938008 / 9940628961', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Website: www.mobilecarspa.in', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('DATE: ',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.Text(_formatDateToDDMMYYYY(date), style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('INVOICE #: ',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.Text(invoiceNumber, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              // Bill To & Car Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL TO',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 6),
                          pw.Text('Name:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(customerName, style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text('Address:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(customerAddress, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Car Model:',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(carModel, style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text('Reg No:',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(regNo, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              // Service table
              pw.Table(
                border: pw.TableBorder(
                  top: const pw.BorderSide(color: PdfColors.grey800, width: 0.8),
                  left: const pw.BorderSide(color: PdfColors.grey800, width: 0.8),
                  right: const pw.BorderSide(color: PdfColors.grey800, width: 0.8),
                  bottom: const pw.BorderSide(color: PdfColors.grey800, width: 0.5),
                  horizontalInside: const pw.BorderSide(color: PdfColors.grey700, width: 0.3),
                  verticalInside: const pw.BorderSide(color: PdfColors.grey700, width: 0.3),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('S.NO',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('DESCRIPTION',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('QTY',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('AMOUNT',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('1', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(description, style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('1', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(currency.format(amount), style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              // Totals box (right aligned)
              pw.Row(
                children: [
                  pw.Spacer(),
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _kv('Subtotal', currency.format(subtotal)),
                        if (taxRate > 0) _kv('Tax (${taxRate.toStringAsFixed(0)}%)', currency.format(tax)),
                        if (advanceAmt > 0) _kv('Advance', '- ${currency.format(advanceAmt)}'),
                        pw.Divider(color: PdfColors.grey600, height: 10, thickness: 0.5),
                        _kv('TOTAL', currency.format(balance), boldKey: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),
              pw.Center(
                child: pw.Text('Thank You For Your Business!',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ),

              pw.SizedBox(height: 24),
              // Signature
              pw.Row(
                children: [
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Authorised Signature', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 8),
                      pw.Image(signatureImage, width: 88, height: 38),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'Invoice_$invoiceNumber.pdf',
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}
