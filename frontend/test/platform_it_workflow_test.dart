import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'IT investigation shortcuts keep session scope clear at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        PlatformPage? destination;
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformWorkspaceShell(
              isAdmin: false,
              name: 'Synthetic IT',
              page: PlatformPage.incidents,
              onNavigate: (page) => destination = page,
              busy: false,
              actions: const [],
              child: const SizedBox.expand(),
            ),
          ),
        );
        if (width < 1000) {
          await tester.tap(find.byTooltip('Open navigation'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Madrassa setup'), findsNothing);
        expect(find.text('Madrasa setup'), findsNothing);
        expect(find.text('Madrasas'), findsNothing);
        if (width < 1000) {
          Navigator.of(tester.element(find.byType(Drawer))).pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Inspect audit evidence'));
        expect(destination, PlatformPage.history);
        await tester.ensureVisible(find.text('My sessions only'));
        await tester.tap(find.text('My sessions only'));
        expect(destination, PlatformPage.sessions);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Busy workflow cannot navigate and admin has no IT shortcuts', (
    tester,
  ) async {
    var calls = 0;
    Future<void> show(bool admin) => tester.pumpWidget(
      MaterialApp(
        home: PlatformWorkspaceShell(
          isAdmin: admin,
          name: 'Synthetic account',
          page: PlatformPage.health,
          onNavigate: (_) => calls++,
          busy: true,
          actions: const [],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await show(false);
    await tester.tap(find.text('Check configuration'));
    expect(calls, 0);
    await show(true);
    expect(find.text('Check configuration'), findsNothing);
  });
}
