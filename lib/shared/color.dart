import 'package:flutter/material.dart';

// Brand palette
const kPrimary =
    Color(0xFFA26334); // requested #A26334 (note: your text had A26334)
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

// Derivatives
const kCard = Color(0xFF312F2E);
const kFieldBg = Color(0xFF3A3A39);

ThemeData appTheme() {
  final base = ThemeData(
      useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Inter');
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: kPrimary,
      onPrimary: kWhite,
      surface: kBg,
      onSurface: kWhite,
      secondary: kMuted,
    ),
    scaffoldBackgroundColor: kBg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kFieldBg,
      hintStyle: const TextStyle(color: kMuted),
      labelStyle: const TextStyle(color: kMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
    ),
  );
}
