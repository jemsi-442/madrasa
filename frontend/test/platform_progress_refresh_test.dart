import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_onboarding_progress.dart';

void main() {
  for (final invalid in [null, 'invalid', '2099-01-01T00:00:00Z']) {
    testWidgets('unverified progress is hidden: $invalid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RefreshableOnboardingProgress(
            initialData: {'checkedAt': invalid, 'schoolName': 'Hidden School'},
            sessionIsCurrent: () => true,
            load: () async => {},
          ),
        ),
      );
      expect(find.textContaining('Progress is outdated'), findsOneWidget);
      expect(find.byType(PlatformOnboardingProgress), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('progress expires locally and refresh restores current handoff', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 9);
    var calls = 0;
    Map<String, dynamic> snapshot() => {
      'checkedAt': now.toIso8601String(),
      'schoolName': 'School',
      'requestedCode': 'school',
      'stage': 'ACTIVATION_REVIEW_PENDING',
      'nextResponsibility': 'OFFICE_APPROVAL',
      'steps': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RefreshableOnboardingProgress(
            initialData: snapshot(),
            now: () => now,
            sessionIsCurrent: () => true,
            load: () async {
              calls++;
              return snapshot();
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('Preparation is complete'), findsOneWidget);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('Preparation is complete'), findsNothing);
    expect(find.textContaining('Progress is outdated'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Refresh progress'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Preparation is complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
  for (final outcome in ['success', 'failure', 'expired', 'closed']) {
    testWidgets('refresh handles $outcome without stale progress', (
      tester,
    ) async {
      final response = Completer<Map<String, dynamic>>();
      var current = true;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RefreshableOnboardingProgress(
                initialData: {
                  'checkedAt': DateTime.now().toUtc().toIso8601String(),
                  'schoolName': 'Previous School',
                  'requestedCode': 'old',
                  'steps': [],
                },
                sessionIsCurrent: () => current,
                load: () {
                  calls++;
                  return response.future;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Previous School / old'), findsOneWidget);
      await tester.tap(find.text('Refresh progress'));
      await tester.pump();
      expect(find.text('Previous School / old'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Refresh progress'));
      expect(calls, 1);
      if (outcome == 'expired') current = false;
      if (outcome == 'closed') await tester.pumpWidget(const SizedBox());
      if (outcome == 'failure') {
        response.completeError(Exception('private server details'));
      } else {
        response.complete({
          'checkedAt': DateTime.now().toUtc().toIso8601String(),
          'schoolName': 'Updated School',
          'requestedCode': 'new',
          'steps': [],
        });
      }
      await tester.pumpAndSettle();
      expect(find.text('Previous School / old'), findsNothing);
      expect(
        find.text('Updated School / new'),
        outcome == 'success' ? findsOneWidget : findsNothing,
      );
      if (outcome == 'failure') {
        expect(
          find.textContaining('Previous information has been hidden'),
          findsOneWidget,
        );
        expect(find.textContaining('private server details'), findsNothing);
        await tester.tap(find.text('Refresh progress'));
        await tester.pumpAndSettle();
        expect(calls, 2);
      }
      if (outcome == 'expired') {
        expect(
          find.textContaining('Session changed or expired'),
          findsOneWidget,
        );
        expect(find.text('Refresh progress'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
