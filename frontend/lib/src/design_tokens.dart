import 'package:flutter/material.dart';

/// Shared visual values. Role permissions and page content do not belong here.
abstract final class AfaqDesign {
  static const ink = Color(0xFF011F3D);
  static const sidebarEnd = Color(0xFF163449);
  static const gold = Color(0xFFB78A2F);
  static const actionGold = Color(0xFF936B20);
  static const paper = Color(0xFFFBF9F4);
  static const canvas = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const muted = Color(0xFF66758B);
  static const border = Color(0xFFE8E7E3);
  static const green = Color(0xFF278258);
  static const blue = Color(0xFF3A70AD);
  static const purple = Color(0xFF7168AA);
  static const bodyFont = 'Lato';
  static const bodySize = 16.0;
  static const secondarySize = 14.0;
  static const labelSize = 15.0;
  static const displayFont = 'NotoSerifDisplay';
  static const panelRadius = 12.0;
  static const controlRadius = 8.0;
  static const headerHeight = 76.0;
  static const desktopBreakpoint = 1000.0;
  static const sidebarWidth = 250.0;
  static const sidebarRailWidth = 84.0;
  static const tableHeader = Color(0xFFF3F5F7);
  static const tableHeadingHeight = 44.0;
  static const tableRowMinHeight = 64.0;
  static const tableRowMaxHeight = 80.0;
  static const tableMargin = 14.0;
  static const tableColumnSpacing = 20.0;
  static const badgePadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const panelPadding = EdgeInsets.all(22);

  static BoxDecoration panelDecoration({Color color = surface}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(panelRadius),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0612263F),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      );
}
