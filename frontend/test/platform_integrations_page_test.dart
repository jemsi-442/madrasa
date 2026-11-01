import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_integrations_page.dart';

void main() {
  testWidgets(
    'Loads backend configuration and clears stale status on failure',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformIntegrationsPage(
              onAudit: () {},
              onHealth: () {},
              request: () async {
                if (++calls > 1) throw Exception('Synthetic failure');
                return {
                  'services': {'Authentication': 'Password sign-in mode'},
                  'timezone': 'Africa/Dar_es_Salaam',
                  'mfaPolicy': 'Password-only sign-in is enabled.',
                  'checkedAt': '2026-11-02T00:00:00Z',
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Password sign-in mode'), findsWidgets);
      await tester.ensureVisible(find.text('Check configuration'));
      await tester.tap(find.text('Check configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Password sign-in mode'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 1440.0]) {
    testWidgets('Integration tabs and safe controls at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var health = false;
      var audit = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformIntegrationsPage(
              onAudit: () => audit = true,
              onHealth: () => health = true,
            ),
          ),
        ),
      );
      expect(find.text('Status not verified'), findsNWidgets(6));
      expect(find.byType(Switch), findsNothing);
      await tester.ensureVisible(find.text('Open system health'));
      await tester.tap(find.text('Open system health'));
      expect(health, isTrue);
      await tester.ensureVisible(find.text('Credentials'));
      await tester.tap(find.text('Credentials'));
      await tester.pumpAndSettle();
      expect(find.text('Credential handling'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Request credential rotation',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Change history'));
      await tester.tap(find.text('Change history'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open audit logs'));
      await tester.tap(find.text('Open audit logs'));
      expect(audit, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
