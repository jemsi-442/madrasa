import 'package:flutter_test/flutter_test.dart';

Future<void> openPlatformPage(WidgetTester tester, String label) async {
  if (label == 'Madrassa applications') {
    await openPlatformPage(tester, 'Madrasas');
    return;
  }
  final menu = find.byTooltip('Open navigation');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
