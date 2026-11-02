import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_integrations_page.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Service shortcut preserves context during recheck at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<dynamic>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformIntegrationsPage(
              onAudit: () {},
              onHealth: () {},
              request: () async {
                if (++calls > 1) return pending.future;
                return {
                  'services': {'Quran content': 'Synthetic previous status'},
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shortcut = find.byKey(
        const ValueKey('configuration-Quran content'),
      );
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.text('Connected services'), findsNothing);
      expect(find.text('Credential handling'), findsOneWidget);
      expect(find.byKey(const ValueKey('Quran content')), findsOneWidget);
      expect(find.text('Synthetic previous status'), findsOneWidget);
      await tester.ensureVisible(find.text('Check configuration'));
      await tester.tap(find.text('Check configuration'));
      await tester.pump();
      expect(find.text('Synthetic previous status'), findsNothing);
      expect(find.byKey(const ValueKey('Quran content')), findsOneWidget);
      pending.complete({
        'services': {'Quran content': 'Synthetic updated status'},
      });
      await tester.pumpAndSettle();
      expect(find.text('Synthetic updated status'), findsOneWidget);
      expect(find.byKey(const ValueKey('Quran content')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Auto checks preserve selected service and stop on permission denial',
    (tester) async {
      var calls = 0;
      var denied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformIntegrationsPage(
              onAudit: () {},
              onHealth: () {},
              request: () async {
                calls++;
                if (denied) throw const ApiException('Synthetic denial', 403);
                return {
                  'services': {
                    'Quran content': 'Synthetic configuration $calls',
                  },
                  'timezone': 'Africa/Dar_es_Salaam',
                  'checkedAt': '2026-11-02T00:00:00Z',
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Credentials'));
      await tester.tap(find.text('Credentials'));
      await tester.pumpAndSettle();
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 1);
      await tester.tap(find.text('Quran content').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Synthetic configuration 2'), findsOneWidget);
      expect(find.text('Credential handling'), findsOneWidget);
      denied = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic configuration 2'), findsNothing);
      expect(
        find.text(
          'Access could not be verified. Sign in again or check your permissions.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

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
