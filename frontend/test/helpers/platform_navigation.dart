import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

Future<void> openPlatformPage(WidgetTester tester, String label) async {
  if (label == 'Company accounts') {
    await openPlatformPage(tester, 'Users & Permissions');
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
    return;
  }
  if (label == 'Office history') {
    await openPlatformPage(tester, 'Settings & Security');
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
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
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
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}
