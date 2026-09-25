import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/admin_academic_pages.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/donations_page.dart';
import 'package:mif_app/src/workspace.dart';

const donor = {
  'id': '4',
  'fullName': 'Amina Supporter',
  'totalGiven': '1200.50',
};
const campaign = {
  'id': '8',
  'title': 'Learning resources',
  'goalAmount': '10000',
  'collectedAmount': '1200.50',
  'progressPercent': '12.0',
};
const meta = {'page': 1, 'pageSize': 10, 'totalItems': 1, 'totalPages': 1};
Future<dynamic> loadFunding(String path) async {
  if (path.endsWith('/overview')) {
    return {
      'collectedAmount': '1200.50',
      'monthlyPledges': '2000',
      'pendingAmount': '799.50',
      'totalDonors': 1,
      'trend': [
        {'month': '2026-09', 'amount': '1200.50'},
      ],
      'distribution': [
        {'name': 'Learning resources', 'amount': '1200.50'},
      ],
    };
  }
  if (path.contains('/donors')) {
    return {
      'items': [donor],
      'meta': meta,
    };
  }
  if (path.contains('/campaigns')) {
    return {
      'items': [campaign],
      'meta': meta,
    };
  }
  return {
    'items': [],
    'meta': {'page': 1, 'totalItems': 0, 'totalPages': 0},
  };
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('admin additions stay out of other role navigation', () {
    expect(
      sectionsForRole('ADMIN').map((s) => s.title),
      containsAll(['Teachers', 'Subjects', 'Donations']),
    );
    for (final role in ['TEACHER', 'PARENT', 'ACCOUNTANT', 'LEARNER']) {
      expect(
        sectionsForRole(role).map((s) => s.title),
        isNot(contains('Donations')),
      );
      expect(
        sectionsForRole(role).map((s) => s.title),
        isNot(contains('Teachers')),
      );
    }
  });

  test(
    'submission keys are distinct UUIDs and money is formatted accurately',
    () {
      final ids = List.generate(100, (_) => submissionId());
      expect(ids.toSet().length, 100);
      expect(
        ids.every(
          (v) => RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ).hasMatch(v),
        ),
        isTrue,
      );
      expect(moneyText('1200.50'), '1,200.50');
      expect(moneyText('0'), '0');
    },
  );

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('fundraising layout fits $width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(DonationsPage(load: loadFunding, submit: (_, _) async => {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending collections'), findsOneWidget);
      expect(find.text('Collection trend'), findsOneWidget);
      expect(find.text('1,200.50'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('donation form reuses its key after an uncertain save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final submissions = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        DonationsPage(
          load: loadFunding,
          submit: (path, body) async {
            submissions.add(Map.from(body));
            if (submissions.length == 1) {
              throw const ApiException('Network lost', 0);
            }
            return {};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record donation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextFormField, 'Donor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Amina Supporter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextFormField, 'Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Learning resources'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount received (TZS)'),
      '1200.50',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save donation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not confirm the save'), findsOneWidget);
    await tester.tap(find.text('Save donation'));
    await tester.pumpAndSettle();
    expect(submissions.length, 2);
    expect(submissions[0], submissions[1]);
    expect(submissions[0]['donorId'], '4');
    expect(submissions[0]['campaignId'], '8');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teachers search resets pagination and keeps true assignments', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        TeachersPage(
          load: (path) async {
            paths.add(path);
            return {
              'summary': {
                'total': 2,
                'active': 1,
                'assigned': 1,
                'subjects': 0,
              },
              'meta': meta,
              'items': [
                {
                  'id': '12',
                  'fullName': 'Teacher Amina',
                  'status': 'ACTIVE',
                  'taughtClasses': [
                    {
                      'name': 'Level 1',
                      'academicYear': '2026',
                      '_count': {'currentStudents': 8},
                    },
                  ],
                  'teachingCourses': [],
                },
              ],
            };
          },
          submit: (_, _) async => {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active accounts'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Amina');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(paths.last, contains('search=Amina'));
    expect(paths.last, contains('page=1'));
    expect(find.text('Class workload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'subject empty and failure states do not invent course statistics',
    (tester) async {
      var failed = true;
      await tester.pumpWidget(
        host(
          SubjectsPage(
            load: (_) async {
              if (failed) throw const ApiException('Failed', 503);
              return {
                'items': [],
                'summary': {
                  'total': 0,
                  'active': 0,
                  'courses': 0,
                  'lessons': 0,
                },
                'meta': {},
              };
            },
            submit: (_, _) async => {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      failed = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No subjects match this search.'), findsOneWidget);
      expect(find.text('Average completion'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('concurrent reads and writes rotate a session only once', () async {
    var refreshes = 0;
    final bodies = <Map<String, dynamic>>[];
    final state = AppState(
      MifApiClient(
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'new',
                  'refreshToken': 'rotated',
                  'user': {'id': '1', 'fullName': 'Admin', 'role': 'ADMIN'},
                },
              }),
              200,
            );
          }
          if (request.headers['Authorization'] == 'Bearer old') {
            return http.Response('{"message":"Expired"}', 401);
          }
          if (request.method == 'POST') {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response('{"data":{"ok":true}}', 200);
        }),
      ),
    );
    addTearDown(state.dispose);
    state.session = const AuthSession(
      accessToken: 'old',
      refreshToken: 'refresh',
      userId: '1',
      fullName: 'Admin',
      role: 'ADMIN',
    );
    await Future.wait([
      state.load('/api/admin/overview'),
      state.submit('/api/fundraising/donations', {'idempotencyKey': 'same'}),
    ]);
    expect(refreshes, 1);
    expect(bodies, [
      {'idempotencyKey': 'same'},
    ]);
    expect(state.session?.accessToken, 'new');
  });
  test(
    'an old form cannot retry under a different signed-in account',
    () async {
      final firstResponse = Completer<http.Response>();
      var attempts = 0;
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          client: MockClient((request) async {
            if (request.url.path == '/api/auth/logout') {
              return http.Response('{"data":{}}', 200);
            }
            attempts++;
            return firstResponse.future;
          }),
        ),
      );
      addTearDown(state.dispose);
      state.session = const AuthSession(
        accessToken: 'first',
        refreshToken: 'refresh',
        userId: '1',
        fullName: 'First admin',
        role: 'ADMIN',
      );
      final oldSave = state.submit('/api/fundraising/donations', {
        'amount': '20',
      });
      await Future<void>.delayed(Duration.zero);
      await state.signOut();
      state.session = const AuthSession(
        accessToken: 'second',
        refreshToken: 'other',
        userId: '2',
        fullName: 'Second admin',
        role: 'ADMIN',
      );
      final denied = expectLater(oldSave, throwsA(isA<ApiException>()));
      firstResponse.complete(http.Response('{"message":"Expired"}', 401));
      await denied;
      expect(attempts, 1);
      expect(state.session?.userId, '2');
    },
  );
  test(
    'a new account never reuses the previous account refresh in flight',
    () async {
      final oldRefresh = Completer<http.Response>();
      final refreshStarted = Completer<void>();
      final refreshBodies = <String>[];
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          client: MockClient((request) async {
            if (request.url.path == '/api/auth/logout') {
              return http.Response('{"data":{}}', 200);
            }
            if (request.url.path == '/api/auth/refresh') {
              final token =
                  (jsonDecode(request.body) as Map)['refreshToken'] as String;
              refreshBodies.add(token);
              if (token == 'old-refresh') {
                refreshStarted.complete();
                return oldRefresh.future;
              }
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'second-renewed',
                    'refreshToken': 'second-rotated',
                    'user': {'id': '2', 'fullName': 'Second', 'role': 'ADMIN'},
                  },
                }),
                200,
              );
            }
            return request.headers['Authorization'] == 'Bearer second-renewed'
                ? http.Response('{"data":{"ok":true}}', 200)
                : http.Response('{"message":"Expired"}', 401);
          }),
        ),
      );
      addTearDown(state.dispose);
      state.session = const AuthSession(
        accessToken: 'first',
        refreshToken: 'old-refresh',
        userId: '1',
        fullName: 'First',
        role: 'ADMIN',
      );
      final oldLoad = state.load('/api/admin/overview');
      final oldDenied = expectLater(oldLoad, throwsA(isA<ApiException>()));
      await refreshStarted.future;
      await state.signOut();
      state.session = const AuthSession(
        accessToken: 'second',
        refreshToken: 'second-refresh',
        userId: '2',
        fullName: 'Second',
        role: 'ADMIN',
      );
      expect(await state.load('/api/admin/overview'), {'ok': true});
      oldRefresh.complete(
        http.Response(
          jsonEncode({
            'data': {
              'accessToken': 'first-renewed',
              'refreshToken': 'first-rotated',
              'user': {'id': '1', 'fullName': 'First', 'role': 'ADMIN'},
            },
          }),
          200,
        ),
      );
      await oldDenied;
      expect(refreshBodies, ['old-refresh', 'second-refresh']);
      expect(state.session?.userId, '2');
      expect(state.session?.accessToken, 'second-renewed');
    },
  );
}
