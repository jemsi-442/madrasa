import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

Future<void> openPlatformPage(WidgetTester tester, String label) async {
  if (label == 'Office history') {
    await openPlatformPage(tester, 'Audit trail');
    return;
  }
  if (label == 'Madrassa applications') {
    await openPlatformPage(tester, 'Madrasas');
    return;
  }
  final menu = find.byTooltip('Open navigation');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  final target = find.byType(Drawer).evaluate().isNotEmpty
      ? find.descendant(of: find.byType(Drawer), matching: find.text(label))
      : find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Drawer).evaluate().isNotEmpty
          ? find
                .descendant(
                  of: find.byType(Drawer),
                  matching: find.byType(Scrollable),
                )
                .first
          : find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}
