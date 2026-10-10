// lib/shared/receipt_fonts.dart
//
// The font every printed document uses.
//
// A PDF's built-in Helvetica only covers Latin-1, and the menu goes past it:
// the en dash of "Veggie – Rösti", the apostrophe of "Nero d’Avola", the
// quotes around „Novantanove“ and the Œ of "Œil de Perdrix" all printed as a
// black box on the paper bill. Embedding Roboto - the font Flutter itself
// ships - covers every character the menu uses today.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class ReceiptFonts {
  ReceiptFonts._();

  static pw.ThemeData? _theme;
  static bool _tried = false;

  /// Loaded once and reused: parsing the fonts for every bill would make
  /// printing noticeably slower on the till.
  ///
  /// Returns null if the fonts cannot be read, which leaves the document on
  /// the built-in font - a bill with a black box in one word still beats no
  /// bill at all.
  static Future<pw.ThemeData?> theme() async {
    if (_tried) return _theme;
    _tried = true;
    try {
      final base = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );
      _theme = pw.ThemeData.withFont(base: base, bold: bold);
    } catch (error) {
      debugPrint('Receipt fonts unavailable, using the built-in one: $error');
    }
    return _theme;
  }
}
