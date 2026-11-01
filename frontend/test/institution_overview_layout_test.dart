import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_office_dashboard.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('institution overview fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformOfficeDashboard(
              name: 'Demo',
              snapshot: {
                'institution': {
                  'month': '2026-10',
                  'summary': {
                    'madrasas': 1,
                    'learners': 4,
                    'teachers': 1,
                    'withLearningRecords': 1,
                    'lessonsTaught': 2,
                    'quranObservations': 3,
                    'openSupportNotes': 0,
                  },
                  'madrasas': [
                    {
                      'name': 'Synthetic madrasa',
                      'code': 'AFQ-000001',
                      'learners': 4,
                      'teachers': 1,
                      'hasLearningRecords': true,
                    },
                  ],
                  'receipts': [],
                  'pledges': [],
                },
                'onboarding': {'awaitingSetup': 0, 'pendingActivation': 0},
                'awaitingYourReview': 0,
              },
              busy: false,
              error: null,
              onRefresh: () {},
              onApplications: () {},
            ),
          ),
        ),
      );
      expect(find.text('Institution Overview'), findsOneWidget);
      expect(find.text('Applications overview'), findsNothing);
      expect(find.text('Company accounts'), findsNothing);
      expect(find.text('Submitted'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
