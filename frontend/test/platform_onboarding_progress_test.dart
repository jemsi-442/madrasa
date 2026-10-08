import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_onboarding_progress.dart';
import 'package:mif_app/src/platform_provisioning_panel.dart';

void main() {
  testWidgets('IT sees withdrawn sign-off as requiring a new review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlatformOnboardingProgress(
              data: {
                'schoolName': 'School',
                'requestedCode': 'school',
                'stage': 'ACTIVATION_REVIEW_PENDING',
                'nextResponsibility': 'IT_REVIEW',
                'activationReview': {
                  'signOffStatus': 'WITHDRAWN',
                  'prerequisitesPassed': true,
                  'manualReviews': ['Access controls'],
                },
              },
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('IT sign-off was withdrawn'), findsOneWidget);
    expect(find.text('Access controls: review required'), findsOneWidget);
    expect(
      find.textContaining('Waiting for independent office approval'),
      findsNothing,
    );
  });
  for (final ready in [false, true]) {
    testWidgets('office sees only next responsibility ready=$ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformOnboardingProgress(
              data: {
                'schoolName': 'School',
                'requestedCode': 'school',
                'stage': 'ACTIVATION_REVIEW_PENDING',
                'nextResponsibility': ready ? 'OFFICE_APPROVAL' : 'IT_REVIEW',
              },
            ),
          ),
        ),
      );
      expect(
        find.textContaining(
          ready
              ? 'Waiting for independent office approval'
              : 'Waiting for IT to complete preparation',
        ),
        findsOneWidget,
      );
      expect(find.text('IT technical readiness'), findsNothing);
      expect(find.textContaining('fingerprint'), findsNothing);
    });
  }
  testWidgets(
    'IT current sign-off does not ask to repeat completed manual review',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformOnboardingProgress(
                data: {
                  'schoolName': 'School',
                  'requestedCode': 'school',
                  'stage': 'ACTIVATION_REVIEW_PENDING',
                  'nextResponsibility': 'OFFICE_APPROVAL',
                  'activationReview': {
                    'signOffStatus': 'CURRENT',
                    'prerequisitesPassed': true,
                    'manualReviews': ['Backup and recovery'],
                  },
                },
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('IT sign-off is current'), findsOneWidget);
      expect(find.text('Backup and recovery: review required'), findsNothing);
      expect(
        find.textContaining('not an automated security certification'),
        findsOneWidget,
      );
    },
  );
  for (final stage in [
    'INVITATION_PENDING',
    'INVITATION_EXPIRED',
    'ACCEPTANCE_PENDING',
    'ACTIVATION_REVIEW_PENDING',
    'ACTIVE',
    'REVIEW_REQUIRED',
  ]) {
    testWidgets('progress fits mobile for $stage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PlatformOnboardingProgress(
                  data: {
                    'schoolName': 'Afaq School',
                    'requestedCode': 'afaq-school',
                    'stage': stage,
                    'checkedAt': '2026-10-08T10:00:00Z',
                    'activationReview': {
                      'activationEnabled': false,
                      'prerequisitesPassed':
                          stage == 'ACTIVATION_REVIEW_PENDING',
                      'checks': [
                        {
                          'label': 'Application independently approved',
                          'passed': true,
                        },
                        {
                          'label': 'You are not the original requester',
                          'passed': false,
                        },
                      ],
                      'manualReviews': [
                        'Tenant isolation',
                        'Backup and recovery',
                      ],
                    },
                    'steps': [
                      {
                        'label': 'Independent approval',
                        'completed': true,
                        'at': '2026-10-08T10:00:00Z',
                      },
                      {
                        'label': 'Invitation record created',
                        'completed': false,
                        'at': null,
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Invitation record created'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('IT technical readiness'), findsOneWidget);
      expect(
        find.text('You are not the original requester: Not met'),
        findsOneWidget,
      );
      expect(find.text('Backup and recovery: review required'), findsOneWidget);
      expect(
        find.textContaining('Activation is not available here.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          stage == 'ACTIVATION_REVIEW_PENDING'
              ? 'Recorded prerequisites pass.'
              : 'Activation prerequisites are not met.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('IT queue loads read-only progress and returns to queue', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlatformProvisioningPanel(
              sessionIsCurrent: () => true,
              call: (path, {body}) async {
                paths.add(path);
                expect(body, isNull);
                if (path.endsWith('/onboarding-progress')) {
                  return {
                    'schoolName': 'School',
                    'requestedCode': 'school',
                    'stage': 'INVITATION_PENDING',
                    'steps': [],
                  };
                }
                return [
                  {
                    'id': 'application',
                    'schoolName': 'School',
                    'requestedCode': 'school',
                    'organization': {'status': 'PENDING_ACTIVATION'},
                  },
                ];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onboarding progress'));
    await tester.pumpAndSettle();
    expect(paths.last, '/tenant-applications/application/onboarding-progress');
    expect(
      find.textContaining('Email delivery is not connected'),
      findsOneWidget,
    );
    expect(find.text('IT technical readiness'), findsNothing);
    await tester.tap(find.text('Refresh progress'));
    await tester.pumpAndSettle();
    expect(
      paths.where((path) => path.endsWith('/onboarding-progress')).length,
      2,
    );
    await tester.tap(find.text('Back to queue'));
    await tester.pumpAndSettle();
    expect(find.text('School status: PENDING_ACTIVATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
