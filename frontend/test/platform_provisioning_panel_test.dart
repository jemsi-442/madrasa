import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/platform_provisioning_panel.dart';

void main() {
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
    'expired',
  ]) {
    testWidgets('IT setup flow on mobile: $outcome', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      var valid = true;
      Future<dynamic> call(String path, {Map<String, dynamic>? body}) async {
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
            _ => 'We could not confirm whether',
          }),
          findsOneWidget,
        );
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
