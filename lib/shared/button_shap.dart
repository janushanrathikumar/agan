import 'package:flutter/material.dart';
import 'color.dart';

class ButtonShap {
  static ButtonStyle primary = FilledButton.styleFrom(
    backgroundColor: kPrimary,
    foregroundColor: kWhite,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
  );

  static ButtonStyle ghost = OutlinedButton.styleFrom(
    foregroundColor: kWhite,
    side: const BorderSide(color: kMuted),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  static ButtonStyle textLink = TextButton.styleFrom(
    foregroundColor: kMuted,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
