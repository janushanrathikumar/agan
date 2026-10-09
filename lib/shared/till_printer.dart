// lib/shared/till_printer.dart
//
// Where every receipt and kitchen ticket goes out.
//
// In the browser all a page may do is open Chrome's print preview, and that
// preview keeps its own destination and paper size - which is why a bill can
// silently fail to come out of an 80 mm till printer. The desktop build has no
// such limit: a printer is chosen once in Printer Settings and each bill is
// then handed straight to it, with no dialog and nothing to get wrong.

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TillPrinter {
  TillPrinter._();

  static const _urlKey = 'till_printer_url';
  static const _nameKey = 'till_printer_name';

  static String? _url;
  static String? _name;

  /// Only a desktop or mobile build can drive a printer without a dialog.
  static bool get isSupported => !kIsWeb;

  /// The printer bills are sent to, or null while none has been chosen.
  static String? get printerName => _name;

  static bool get hasPrinter => isSupported && (_url?.isNotEmpty ?? false);

  static Future<void> loadSettings() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString(_urlKey);
    _name = prefs.getString(_nameKey);
  }

  /// The printers Windows (or macOS) has installed.
  static Future<List<Printer>> available() async {
    if (!isSupported) return const [];
    try {
      return await Printing.listPrinters();
    } catch (error) {
      debugPrint('Could not list printers: $error');
      return const [];
    }
  }

  static Future<void> use(Printer printer) async {
    _url = printer.url;
    _name = printer.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, printer.url);
    await prefs.setString(_nameKey, printer.name);
  }

  /// Goes back to asking every time.
  static Future<void> forget() async {
    _url = null;
    _name = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_nameKey);
  }

  /// Prints [bytes], straight to the chosen printer where that is possible and
  /// through the usual print dialog otherwise.
  ///
  /// Returns true when a printer accepted the job.
  static Future<bool> printPdf(
    Uint8List bytes, {
    required String jobName,
    PdfPageFormat format = PdfPageFormat.roll80,
  }) async {
    if (hasPrinter) {
      try {
        return await Printing.directPrintPdf(
          printer: Printer(url: _url!, name: _name),
          onLayout: (_) async => bytes,
          name: jobName,
          format: format,
          dynamicLayout: false,
          // Keep the roll size the receipt was laid out for rather than
          // letting the driver's default paper win.
          usePrinterSettings: false,
        );
      } catch (error) {
        // A printer that has been unplugged or renamed should not lose the
        // bill: fall back to the dialog so it can still be printed by hand.
        debugPrint('Direct print failed, falling back to the dialog: $error');
      }
    }

    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: jobName,
      format: format,
      dynamicLayout: false,
    );
  }
}
