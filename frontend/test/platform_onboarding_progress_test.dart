import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_onboarding_progress.dart';

void main() {
  testWidgets('refresh requires fresh confirmation before invitation sending', (
    tester,
  ) async {
    final data = <String, dynamic>{
      'schoolName': 'Synthetic School',
      'requestedCode': 'AFQ-000001',
      'stage': 'INVITATION_PENDING',
      'canSendInvitation': true,
      'deliveryConfigured': true,
      'checkedAt': DateTime.now().toIso8601String(),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RefreshableOnboardingProgress(
              initialData: data,
              sessionIsCurrent: () => true,
              load: () async => data,
              sendInvitation: () async => 'SMTP_ACCEPTED',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Refresh progress'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Afaq code'), findsOneWidget);
    expect(find.text('Invitation needed'), findsOneWidget);
    expect(find.text('Setup checklist'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'invitation send requires confirmation and refreshes without exposing a code',
    (tester) async {
      var sent = 0;
      var refreshed = 0;
      final data = <String, dynamic>{
        'schoolName': 'Synthetic School',
        'requestedCode': 'synthetic',
        'stage': 'INVITATION_PENDING',
        'canSendInvitation': true,
        'deliveryConfigured': true,
        'checkedAt': DateTime.now().toIso8601String(),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RefreshableOnboardingProgress(
                initialData: data,
                sessionIsCurrent: () => true,
                load: () async {
                  refreshed++;
                  return {...data, 'stage': 'ACCEPTANCE_PENDING'};
                },
                sendInvitation: () async {
                  sent++;
                  return 'SMTP_ACCEPTED';
                },
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Send invitation email'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(refreshed, 1);
      expect(
        find.textContaining('Inbox delivery is not yet confirmed'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final entry in [
    ('PROVISIONING_PENDING', null, false, 'IT team'),
    ('INVITATION_PENDING', null, false, 'IT team'),
    ('INVITATION_EXPIRED', null, false, 'IT team'),
    ('ACCEPTANCE_PENDING', null, false, 'IT team'),
    ('ACCEPTANCE_PENDING', null, true, 'Invited madrassa administrator'),
    ('ACTIVATION_REVIEW_PENDING', 'IT_REVIEW', false, 'IT team'),
    (
      'ACTIVATION_REVIEW_PENDING',
      'OFFICE_APPROVAL',
      false,
      'Independent office approver',
    ),
    ('ACTIVE', null, false, 'Madrassa administrator'),
    ('REVIEW_REQUIRED', null, false, 'IT team'),
    ('UNKNOWN', null, false, 'IT team'),
  ]) {
    testWidgets('handoff owner for ${entry.$1} / ${entry.$2} / ${entry.$3}', (
      tester,
    ) async {
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
                    'schoolName': 'School',
                    'requestedCode': 'school',
                    'stage': entry.$1,
                    'nextResponsibility': entry.$2,
                    'deliveryConfigured': entry.$3,
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Responsible next: ${entry.$4}'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);
      expect(
        find.textContaining(
          'An invitation record does not confirm email delivery.',
        ),
        entry.$1 == 'ACCEPTANCE_PENDING' ? findsOneWidget : findsNothing,
      );
      final blocked =
          !entry.$3 &&
          [
            'INVITATION_PENDING',
            'INVITATION_EXPIRED',
            'ACCEPTANCE_PENDING',
          ].contains(entry.$1);
      expect(
        find.textContaining('Delivery setup pending:'),
        blocked ? findsOneWidget : findsNothing,
      );
      expect(find.text('IT technical readiness'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      if (entry.$2 == 'OFFICE_APPROVAL') {
        expect(
          find.textContaining('original requester cannot give final approval'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
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
            body: SingleChildScrollView(
              child: PlatformOnboardingProgress(
                data: {
                  'schoolName': 'School',
                  'requestedCode': 'school',
                  'stage': 'ACTIVATION_REVIEW_PENDING',
                  'nextResponsibility': ready ? 'OFFICE_APPROVAL' : 'IT_REVIEW',
                },
              ),
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
}
