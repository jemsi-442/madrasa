import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/workspace_chrome.dart';

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets(
      'profile panel groups information and closes on action at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var signedOut = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: WorkspaceAccountMenu(
                  fullName: 'Afaq Admin',
                  roleLabel: 'Super Admin',
                  email: 'admin@example.test',
                  compact: width < 600,
                  onSessions: () {},
                  onChangePassword: () {},
                  onSignOut: () => signedOut = true,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Account menu'));
        await tester.pumpAndSettle();
        expect(find.text('User info'), findsOneWidget);
        expect(find.text('admin@example.test'), findsOneWidget);
        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('Actions'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(signedOut, isTrue);
        expect(find.text('User info'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
