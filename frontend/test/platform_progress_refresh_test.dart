import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_onboarding_progress.dart';

void main() {
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
                initialData: const {
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
    });
  }
}
