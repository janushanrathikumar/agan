// lib/admin/table_qr_printer.dart
//
// Prints a sheet of chair QR labels to cut out and place on the tables.
// Mirrors the PDF flow used by the order/station printers.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
// pw.BarcodeWidget comes from here, so QR generation for the PDF needs no
// extra dependency.
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:restorant/shared/table_registry.dart';

class TableQrPrinter {
  /// One labelled QR per chair of [table], laid out on A4.
  ///
  /// [origin] is the website address the codes point at; the caller passes the
  /// value the admin confirmed, so stickers are never printed against a local
  /// dev address by accident.
  static Future<void> printSheet(
    BuildContext context,
    TableDoc table, {
    String? origin,
  }) async {
    if (table.chairs.isEmpty) {
      _snack(context, 'This table has no chairs to print.', Colors.orange);
      return;
    }

    final pdfBytes = await _buildSheet(table, origin);

    var printed = false;
    try {
      printed = await Printing.layoutPdf(
        dynamicLayout: false,
        format: PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'QR_${table.name.replaceAll(RegExp(r'\s+'), '_')}',
      );
    } on MissingPluginException {
      if (!context.mounted) return;
      _snack(context, 'Printing is not available on this platform.', Colors.red);
      return;
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, 'Could not print QR codes: $error', Colors.red);
      return;
    }

    if (!context.mounted) return;
    _snack(
      context,
      printed
          ? 'QR sheet sent for ${table.name}'
          : 'QR printing was canceled for ${table.name}',
      printed ? Colors.green : Colors.orange,
    );
  }

  static Future<Uint8List> _buildSheet(TableDoc table, String? origin) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            table.name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: table.chairs
                .map((chair) => _label(table, chair, origin))
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _label(TableDoc table, ChairEntry chair, String? origin) {
    final payload = TableRegistry.qrPayloadFor(
      table.id,
      chairId: chair.id,
      origin: origin,
    );

    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: payload,
            width: 110,
            height: 110,
            drawText: false,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            table.name,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Chair ${chair.no}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
