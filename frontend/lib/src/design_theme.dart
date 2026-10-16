import 'package:flutter/material.dart';
import 'foundation_ui.dart';
import 'design_tokens.dart';

/// Root theme for public pages and every authenticated role.
ThemeData buildAfaqTheme() => afaqControlTheme(
  ThemeData(
    useMaterial3: true,
    fontFamily: AfaqDesign.bodyFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ink,
      primary: ink,
      secondary: gold,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: AfaqDesign.displayFont,
        fontSize: 49,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.12,
      ),
      headlineMedium: TextStyle(
        fontFamily: AfaqDesign.displayFont,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.16,
      ),
      titleLarge: TextStyle(
        fontFamily: AfaqDesign.bodyFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: gold, width: 1.7),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AfaqDesign.panelRadius),
        side: const BorderSide(color: line),
      ),
    ),
  ),
);

ThemeData afaqControlTheme(ThemeData base) {
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AfaqDesign.controlRadius),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AfaqDesign.controlRadius),
    borderSide: const BorderSide(color: line),
  );
  return base.copyWith(
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: const Color(0x33011F3D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffdde4eb)),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: AfaqDesign.bodyFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.25,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: AfaqDesign.bodyFont,
        fontSize: 16,
        color: ink,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AfaqDesign.tableHeader),
      headingTextStyle: TextStyle(
        fontSize: AfaqDesign.labelSize,
        fontWeight: FontWeight.w700,
        color: AfaqDesign.ink,
      ),
      dataTextStyle: TextStyle(
        fontSize: AfaqDesign.bodySize,
        color: AfaqDesign.ink,
      ),
      headingRowHeight: AfaqDesign.tableHeadingHeight,
      dataRowMinHeight: AfaqDesign.tableRowMinHeight,
      dataRowMaxHeight: AfaqDesign.tableRowMaxHeight,
      horizontalMargin: AfaqDesign.tableMargin,
      columnSpacing: AfaqDesign.tableColumnSpacing,
      dividerThickness: 0.6,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AfaqDesign.actionGold,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: AfaqDesign.bodyFont,
          fontSize: AfaqDesign.bodySize,
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
      filled: true,
      fillColor: const Color(0xfff7f9fc),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: Color(0xff40536b),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: const TextStyle(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      helperStyle: const TextStyle(color: muted, fontSize: 13),
      errorStyle: const TextStyle(
        color: Color(0xffb42336),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
      prefixIconColor: muted,
      suffixIconColor: muted,
      border: border,
      enabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xffcbd5e1)),
      ),
      disabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xffe2e7ed)),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xffb42336)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xffb42336), width: 2),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    ),
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: AfaqDesign.bodySize,
        height: 1.5,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        fontSize: AfaqDesign.bodySize,
        height: 1.5,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        letterSpacing: 0,
        fontSize: AfaqDesign.secondarySize,
        height: 1.5,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        fontSize: AfaqDesign.labelSize,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
