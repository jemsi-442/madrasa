import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_madrasas_page.dart';

void main() {
  for (final outcome in [null, false, true]) {
    testWidgets(
      'review result $outcome keeps profile and prevents uncertain retries',
      (tester) async {
        var requests = 0;
        var status = 'REQUESTED';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformMadrasasPage(
                onApplications: () {},
                onSessionExpired: () {},
                onReview: (_, decision) async {
                  requests++;
                  if (outcome == true) status = 'APPROVED';
                  return outcome;
                },
                load: (_) async => {
                  'total': 1,
                  'items': [
                    {
                      'id': 'application:new',
                      'applicationId': 'new',
                      'name': 'Synthetic Madrasa',
                      'code': 'synthetic',
                      'status': status,
                      'canReview': true,
                      'admins': [],
                      'locations': [],
                      'students': null,
                      'teachers': null,
                    },
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Manage →'));
        await tester.tap(find.text('Manage →'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Approve madrasa'));
        await tester.tap(find.text('Approve madrasa'));
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(find.text('Back to Madrasas'), findsOneWidget);
        if (outcome == false) {
          expect(
            find.textContaining('Decision could not be confirmed'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Approve madrasa'),
                )
                .onPressed,
            isNull,
          );
        } else if (outcome == true) {
          expect(find.text('Approve madrasa'), findsNothing);
          expect(
            find.text('Approved. Continue registration in Madrasas.'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Back to Madrasas'));
          await tester.tap(find.text('Back to Madrasas'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Awaiting setup'), findsOneWidget);
        } else {
          expect(
            find.textContaining('Decision could not be confirmed'),
            findsNothing,
          );
          expect(find.text('Approve madrasa'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'profile refresh replaces status and hides stale details on failure',
    (tester) async {
      var status = 'ACTIVE';
      var fail = false;
      final paths = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformMadrasasPage(
              onApplications: () {},
              onSessionExpired: () {},
              load: (path) async {
                paths.add(path);
                if (fail) throw Exception('Synthetic outage');
                return {
                  'total': 1,
                  'items': [
                    {
                      'id': '7',
                      'code': 'DEMO',
                      'name': 'Synthetic Madrasa',
                      'status': status,
                      'admins': [],
                      'locations': [],
                      'students': 0,
                      'teachers': 0,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Manage →'));
      await tester.tap(find.text('Manage →'));
      await tester.pumpAndSettle();
      status = 'SUSPENDED';
      await tester.tap(find.text('Refresh details'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.last).queryParameters, {'code': 'DEMO'});
      expect(find.textContaining('Access is suspended.'), findsOneWidget);
      expect(find.text('Madrasa is active.'), findsNothing);
      fail = true;
      await tester.tap(find.text('Refresh details'));
      await tester.pumpAndSettle();
      expect(find.text('Madrasa details unavailable'), findsOneWidget);
      expect(find.textContaining('Access is suspended.'), findsNothing);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Access is suspended.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final canReview in [true, false]) {
    testWidgets(
      'pending madrasa review respects independent reviewer=$canReview',
      (tester) async {
        String? decision;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformMadrasasPage(
                onApplications: () {},
                onSessionExpired: () {},
                onReview: (_, value) async {
                  decision = value;
                  return null;
                },
                load: (_) async => {
                  'total': 1,
                  'items': [
                    {
                      'id': 'application:new',
                      'applicationId': 'new',
                      'name': 'New Madrasa',
                      'code': 'new',
                      'status': 'REQUESTED',
                      'canReview': canReview,
                      'admins': [],
                      'locations': [],
                      'students': null,
                      'teachers': null,
                    },
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final manage = find.text('Manage →');
        await tester.ensureVisible(manage);
        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(find.text('Applications'), findsNothing);
        expect(
          find.text('Approve madrasa'),
          canReview ? findsOneWidget : findsNothing,
        );
        if (canReview) {
          await tester.ensureVisible(find.text('Approve madrasa'));
          await tester.tap(find.text('Approve madrasa'));
          await tester.pumpAndSettle();
          expect(decision, 'APPROVED');
        } else {
          expect(
            find.text('Another Super Admin must review this request.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [390.0, 1400.0]) {
    testWidgets('directory at $width loads, searches and opens details', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      var applications = false;
      String? csv;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformMadrasasPage(
              onApplications: () => applications = true,
              onSessionExpired: () {},
              saveCsv: (_, content) async {
                csv = content;
                return true;
              },
              load: (path) async {
                paths.add(path);
                return {
                  'total': 1,
                  'summary': {
                    'total': 1,
                    'active': 1,
                    'onboarding': 0,
                    'assignedAdmins': 1,
                  },
                  'locations': ['Dar es Salaam'],
                  'items': [
                    {
                      'id': '7',
                      'name': 'Afaq Madrasa',
                      'code': 'AFQ',
                      'status': 'ACTIVE',
                      'students': 24,
                      'teachers': 3,
                      'admins': ['School Admin'],
                      'locations': width < 700 ? ['Dar es Salaam'] : [],
                      if (width >= 700)
                        'location': {
                          'country': 'Tanzania',
                          'region': 'Dar es Salaam',
                          'district': 'Synthetic District',
                          'ward': 'Synthetic Ward',
                        },
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Afaq Madrasa'), findsOneWidget);
      expect(find.text('Total madrasas'), findsOneWidget);
      expect(find.text('Assigned admins'), findsOneWidget);
      await tester.ensureVisible(find.text('Export list'));
      await tester.tap(find.text('Export list'));
      await tester.pumpAndSettle();
      expect(csv, contains('Dar es Salaam'));
      if (width >= 700) {
        expect(csv, contains('Tanzania'));
        expect(csv, contains('Synthetic Ward'));
      }
      expect(Uri.parse(paths.last).queryParameters['export'], 'true');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'AFQ');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.last).queryParameters['search'], 'AFQ');
      final details = width < 700
          ? find.text('Afaq Madrasa')
          : find.text('Manage →');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Afaq code'), findsOneWidget);
      expect(find.text('Government registration number'), findsNothing);
      expect(find.text('AFQ'), findsNWidgets(2));
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Administration'), findsOneWidget);
      expect(find.text('Copy Afaq code'), findsOneWidget);
      expect(find.text('Madrasa administrator'), findsOneWidget);
      expect(find.text('Learners'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Active teachers'), findsOneWidget);
      expect(find.text('Madrasa is active.'), findsOneWidget);
      expect(find.text('Onboarding & next steps'), findsOneWidget);
      expect(find.text('Management responsibilities'), findsNothing);
      await tester.ensureVisible(find.text('Back to Madrasas'));
      await tester.tap(find.text('Back to Madrasas'));
      await tester.pumpAndSettle();
      final add = find.text('Add Madrasa');
      await tester.ensureVisible(add);
      await tester.tap(add);
      expect(applications, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
