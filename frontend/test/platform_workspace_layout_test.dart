import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';

void main() {
  for (final failRequests in [false, true]) {
    testWidgets(
      'office requests use live API and preserve totals on failure=$failRequests',
      (tester) async {
        final api = PlatformApi(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'token',
                    'expiresIn': 900,
                    'user': {
                      'id': 'admin',
                      'fullName': 'Office',
                      'role': 'SUPER_ADMIN',
                    },
                  },
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/overview')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'awaitingYourReview': 7,
                    'applications': {
                      'REQUESTED': 7,
                      'APPROVED': 0,
                      'REJECTED': 0,
                    },
                    'onboarding': {'awaitingSetup': 0, 'pendingActivation': 0},
                  },
                }),
                200,
              );
            }
            expect(request.url.queryParameters, {'page': '1', 'pageSize': '5'});
            return failRequests
                ? http.Response('{}', 503)
                : http.Response(
                    jsonEncode({
                      'data': [
                        {
                          'schoolName': 'Live school request',
                          'requestedCode': 'school-01',
                          'status': 'REQUESTED',
                        },
                      ],
                    }),
                    200,
                  );
          }),
        );
        await api.login('office@example.test', 'password', '123456');
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformConsole(api: api, onSignedOut: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('7'), findsWidgets);
        expect(
          find.text(
            failRequests
                ? 'Requests could not be loaded. Refresh to try again.'
                : 'Live school request',
          ),
          findsOneWidget,
        );
        expect(find.text('No madrassa requests yet.'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }

  for (final status in ['ACTIVE', 'DISABLED', 'UNKNOWN', null]) {
    testWidgets('account badge labels $status without guessing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlatformAccountStatus(status: status)),
        ),
      );
      expect(
        find.text(switch (status) {
          'ACTIVE' => 'Active',
          'DISABLED' => 'Disabled',
          _ => 'Status unavailable',
        }),
        findsOneWidget,
      );
      expect(find.byType(Icon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'application heading wraps long fields and labels unknown status',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: PlatformApplicationHeading(
                  record: {
                    'schoolName':
                        'Afaq Madrassa with a long descriptive school name',
                    'adminEmail': 'administrator.long.name@example.test',
                    'requestedCode': 'afaq-school',
                    'status': 'UNKNOWN',
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Status unavailable'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets('quick actions navigate and respect busy state at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PlatformPage? destination;
      for (final busy in [false, true]) {
        destination = null;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformOverview(
                isAdmin: true,
                name: 'Office',
                snapshot: null,
                busy: busy,
                error: null,
                onRefresh: () {},
                onNavigate: (page) => destination = page,
              ),
            ),
          ),
        );
        final action = find.text('Manage company access');
        await tester.ensureVisible(action);
        await tester.pump();
        await tester.tap(action);
        await tester.pump();
        expect(destination, busy ? isNull : PlatformPage.accounts);
        if (!busy) {
          destination = null;
          Focus.of(tester.element(action)).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(destination, PlatformPage.accounts);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final empty in [true, false]) {
    testWidgets(
      'application chart handles empty=$empty without invented totals',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformOverview(
                isAdmin: true,
                name: 'Office',
                busy: false,
                error: null,
                snapshot: {
                  'applications': empty
                      ? {'REQUESTED': 0, 'APPROVED': 0, 'REJECTED': 0}
                      : {'REQUESTED': 3},
                },
                onRefresh: () {},
                onNavigate: (_) {},
              ),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Applications overview'),
          200,
        );
        expect(
          find.text(
            empty
                ? 'No applications recorded yet.'
                : 'Application breakdown is unavailable. Refresh to try again.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('task guidance fits a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: PlatformTaskIntro(
                page: PlatformPage.applications,
                isAdmin: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('APPLICATION WORKFLOW'), findsOneWidget);
    expect(find.text('2. Independent review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('IT navigation remains reachable in short landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlatformPage? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformWorkspaceShell(
          isAdmin: false,
          name: 'IT Officer',
          page: PlatformPage.home,
          busy: false,
          actions: const [],
          onNavigate: (page) => selected = page,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('My sessions'),
      80,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My sessions'));
    await tester.pumpAndSettle();
    expect(selected, PlatformPage.sessions);
    expect(tester.takeException(), isNull);
  });

  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    for (final width in [320.0, 800.0, 1440.0]) {
      testWidgets('$role redesigned workspace at $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final paths = <String>[];
        final api = PlatformApi(
          client: MockClient((request) async {
            paths.add(request.url.path);
            final data = request.url.path.endsWith('/login')
                ? {
                    'accessToken': 'demo-token',
                    'expiresIn': 900,
                    'user': {
                      'id': 'demo',
                      'fullName': 'Demo Operator',
                      'role': role,
                    },
                  }
                : request.url.path.endsWith('/overview')
                ? {
                    'checkedAt': '2026-10-09T12:00:00Z',
                    'awaitingYourReview': 3,
                    'applications': {
                      'REQUESTED': 5,
                      'APPROVED': 2,
                      'REJECTED': 1,
                    },
                    'onboarding': {'pendingActivation': 1},
                  }
                : request.url.path.endsWith('/health')
                ? {
                    'checkedAt': DateTime.now().toUtc().toIso8601String(),
                    'status': 'healthy',
                    'checks': <dynamic>[],
                  }
                : <dynamic>[];
            return http.Response(jsonEncode({'data': data}), 200);
          }),
        );
        await api.login('demo@example.test', 'password', '123456');
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformConsole(api: api, onSignedOut: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlatformWorkspaceShell), findsOneWidget);
        expect(
          find.text(
            role == 'SUPER_ADMIN'
                ? 'Welcome, Demo Operator!'
                : 'Assalamu alaikum, Demo Operator',
          ),
          findsOneWidget,
        );
        expect(
          paths,
          contains(
            role == 'SUPER_ADMIN'
                ? '/api/platform/overview'
                : '/api/platform/health',
          ),
        );
        expect(tester.takeException(), isNull);
        if (width < 1000) {
          await tester.tap(find.byTooltip('Open navigation'));
          await tester.pumpAndSettle();
        }
        if (role == 'SUPER_ADMIN') {
          expect(find.text('System health'), findsNothing);
          expect(find.text('Audit trail'), findsNothing);
          expect(find.text('My sessions'), findsNothing);
          expect(find.text('Madrassa setup'), findsNothing);
          await tester.tap(find.text('Company accounts'));
          await tester.pumpAndSettle();
          expect(paths, contains('/api/platform/accounts'));
          expect(paths, isNot(contains('/api/platform/health')));
        } else {
          expect(find.text('Company accounts'), findsNothing);
          expect(find.text('Madrassa applications'), findsNothing);
          await tester.tap(find.text('Madrassa setup'));
          await tester.pumpAndSettle();
          expect(paths, contains('/api/platform/provisioning-queue'));
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('School provisioning'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      });
    }
  }

  testWidgets('failed overview does not invent zero totals and can retry', (
    tester,
  ) async {
    final api = PlatformApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'data': {
                'accessToken': 'token',
                'expiresIn': 900,
                'user': {
                  'id': 'admin',
                  'fullName': 'Admin',
                  'role': 'SUPER_ADMIN',
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 503);
      }),
    );
    await api.login('demo@example.test', 'password', '123456');
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformConsole(api: api, onSignedOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not available'), findsNWidgets(6));
    expect(find.byTooltip('Refresh overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
