import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/platform_provisioning_panel.dart';

void main() {
  for (final checks in <Map<String, dynamic>?>[
    {'independentReview': false, 'schoolCodeAvailable': true},
    {'independentReview': true, 'schoolCodeAvailable': false},
    {'independentReview': false, 'schoolCodeAvailable': false},
    null,
    {'independentReview': true, 'schoolCodeAvailable': true},
  ]) {
    testWidgets('blocked setup routes responsibility safely: $checks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformProvisioningPanel(
                sessionIsCurrent: () => true,
                call: (path, {body}) async {
                  expect(body, isNull);
                  paths.add(path);
                  if (path.endsWith('/provisioning-preflight')) {
                    return {
                      'prerequisitesPassed': false,
                      'alreadyProvisioned': false,
                      'checks': checks,
                    };
                  }
                  return [
                    {
                      'id': 'application',
                      'schoolName': 'School',
                      'requestedCode': 'school',
                    },
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review setup'));
      await tester.tap(find.text('Review setup'));
      await tester.pumpAndSettle();
      final missingApproval = checks?['independentReview'] == false;
      final codeConflict = checks?['schoolCodeAvailable'] == false;
      expect(
        find.textContaining('Office action:'),
        missingApproval ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('Super Admin'),
        missingApproval ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('IT action:'),
        codeConflict || !missingApproval ? findsOneWidget : findsNothing,
      );
      if (!missingApproval && !codeConflict) {
        expect(find.textContaining('could not be verified'), findsOneWidget);
      }
      expect(find.text('Create inactive madrassa'), findsNothing);
      expect(paths.length, 2);
      expect(
        paths.last,
        '/tenant-applications/application/provisioning-preflight',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'setup filters combine with search and preserve inactive status',
    (tester) async {
      final paths = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformProvisioningPanel(
                sessionIsCurrent: () => true,
                call: (path, {body}) async {
                  expect(body, isNull);
                  final uri = Uri.parse(path);
                  paths.add(uri);
                  return [
                    {
                      'id': 'school',
                      'schoolName': 'School',
                      'requestedCode': 'school',
                      'organization': uri.queryParameters['setup'] == 'pending'
                          ? null
                          : {'status': 'PENDING_ACTIVATION'},
                    },
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Awaiting setup'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters['setup'], 'pending');
      expect(paths.last.queryParameters['page'], '1');
      expect(find.text('Review setup'), findsOneWidget);
      final field = find.widgetWithText(
        TextField,
        'Search madrassa name or code',
      );
      await tester.enterText(field, 'School');
      await tester.tap(find.text('Search madrassas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Created madrassas'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters, {
        'page': '1',
        'pageSize': '20',
        'q': 'School',
        'setup': 'created',
      });
      expect(find.text('School status: PENDING_ACTIVATION'), findsOneWidget);
      expect(find.text('Review setup'), findsNothing);
      await tester.tap(find.text('Refresh queue'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters['setup'], 'created');
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters, {
        'page': '1',
        'pageSize': '20',
        'setup': 'created',
      });
      await tester.tap(find.text('All approved'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters, {'page': '1', 'pageSize': '20'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queue search resets pagination and survives refresh until cleared',
    (tester) async {
      final paths = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformProvisioningPanel(
                sessionIsCurrent: () => true,
                call: (path, {body}) async {
                  expect(body, isNull);
                  final uri = Uri.parse(path);
                  paths.add(uri);
                  if (uri.queryParameters.containsKey('q')) return [];
                  return List.generate(
                    20,
                    (index) => {
                      'id': 'application-$index',
                      'schoolName': 'School $index',
                      'requestedCode': 'school-$index',
                      'organization': {'status': 'PENDING_ACTIVATION'},
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next page'));
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters['page'], '2');
      final search = find.widgetWithText(
        TextField,
        'Search madrassa name or code',
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, '  Afaq & School  ');
      await tester.ensureVisible(find.text('Search madrassas'));
      await tester.tap(find.text('Search madrassas'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters, {
        'page': '1',
        'pageSize': '20',
        'q': 'Afaq & School',
      });
      expect(
        find.text('No approved madrassas match this search on this page.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Refresh queue'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters['q'], 'Afaq & School');
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters, {'page': '1', 'pageSize': '20'});
      expect(find.text('School 0'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in [
    'created',
    'replay',
    'blocked',
    'offline',
    'denied',
    'expired',
  ]) {
    testWidgets('IT setup flow on mobile: $outcome', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      var progressReads = 0;
      var valid = true;
      final histories = <String>[];
      Future<dynamic> call(String path, {Map<String, dynamic>? body}) async {
        if (path.endsWith('/onboarding-progress')) {
          expect(path, '/tenant-applications/application/onboarding-progress');
          expect(body, isNull);
          progressReads++;
          if (progressReads == 1) throw Exception('private diagnostic');
          return {
            'schoolName': 'Approved School',
            'requestedCode': 'approved-school',
            'stage': 'INVITATION_PENDING',
            'checkedAt': DateTime.now().toUtc().toIso8601String(),
          };
        }
        if (path.startsWith('/provisioning-queue')) {
          return [
            {
              'id': 'application',
              'schoolName': 'Approved School',
              'requestedCode': 'approved-school',
              'organization': null,
            },
          ];
        }
        if (path.endsWith('/provisioning-preflight')) {
          if (outcome == 'expired') {
            valid = false;
            throw const ApiException('expired', 401);
          }
          return {
            'prerequisitesPassed': outcome != 'blocked',
            'alreadyProvisioned': false,
          };
        }
        expect(path, '/tenant-applications/application/provision');
        expect(body, isEmpty);
        writes++;
        if (outcome == 'offline') throw Exception('network failure');
        if (outcome == 'denied') throw const ApiException('not allowed', 403);
        return {
          'created': outcome == 'created',
          'status': 'PENDING_ACTIVATION',
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformProvisioningPanel(
                call: call,
                onViewHistory: histories.add,
                sessionIsCurrent: () => valid,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review setup'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      if (outcome == 'blocked' || outcome == 'expired') {
        expect(find.text('Create inactive madrassa'), findsNothing);
        expect(
          find.textContaining(
            outcome == 'blocked'
                ? 'Setup is blocked'
                : 'Session changed or expired',
          ),
          findsOneWidget,
        );
        if (outcome == 'expired') {
          expect(find.text('Approved School'), findsNothing);
        }
      } else {
        await tester.tap(find.text('Cancel setup'));
        await tester.pumpAndSettle();
        expect(writes, 0);
        await tester.tap(find.text('Review setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create inactive madrassa'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(find.text('Create inactive madrassa'), findsNothing);
        expect(
          find.textContaining(switch (outcome) {
            'created' => 'Inactive madrassa created.',
            'replay' => 'No duplicate was created.',
            'denied' => 'Creation could not proceed.',
            _ => 'We could not confirm whether',
          }),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('View application history'));
        await tester.tap(find.text('View application history'));
        expect(histories, ['application']);
        expect(writes, 1);
        await tester.ensureVisible(find.text('Check current progress'));
        await tester.tap(find.text('Check current progress'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Progress could not be loaded'),
          findsOneWidget,
        );
        expect(find.textContaining('private diagnostic'), findsNothing);
        expect(find.text('Create inactive madrassa'), findsNothing);
        await tester.tap(find.text('Check current progress'));
        await tester.pumpAndSettle();
        expect(progressReads, 2);
        expect(writes, 1);
        expect(
          find.textContaining('Waiting for an admin invitation.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Back to queue'));
        await tester.tap(find.text('Back to queue'));
        await tester.pumpAndSettle();
        expect(find.text('Review setup'), findsOneWidget);
        expect(find.text('Check current progress'), findsNothing);
        expect(writes, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('linked madrassa has no creation action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformProvisioningPanel(
            sessionIsCurrent: () => true,
            call: (path, {body}) async => [
              {
                'id': 'application',
                'schoolName': 'School',
                'requestedCode': 'school',
                'organization': {'id': '1', 'status': 'PENDING_ACTIVATION'},
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('School status: PENDING_ACTIVATION'), findsOneWidget);
    expect(find.text('Review setup'), findsNothing);
    expect(find.text('Create inactive madrassa'), findsNothing);
  });
}
