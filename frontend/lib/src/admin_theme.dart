import 'package:flutter/material.dart';
import 'foundation_ui.dart';

ThemeData adminTheme(ThemeData base) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: line),
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF936B20),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'NotoSansDisplay',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: line),
        shape: shape,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: blue, shape: shape),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textTheme: base.textTheme.copyWith(
      bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: base.textTheme.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: base.textTheme.labelLarge?.copyWith(letterSpacing: 0),
      titleMedium: base.textTheme.titleMedium?.copyWith(letterSpacing: 0),
    ),
  );
}
