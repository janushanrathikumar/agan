// lib/admin_colors.dart
import 'package:flutter/material.dart';

const kPrimary = Color(0xFFA63334); // corrected from #A6334
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

ThemeData adminTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      secondary: kMuted,
      surface: kBg,
      background: kBg,
      onPrimary: kWhite,
      onSecondary: kBg,
      onSurface: kWhite,
      onBackground: kWhite,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kWhite,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kWhite,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: kMuted, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: kWhite,
      displayColor: kWhite,
    ),
    dividerColor: kMuted.withOpacity(.25),
  );
}
