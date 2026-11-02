import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';
import 'helpers/institution_overview_fixture.dart';
import 'helpers/memory_browser_state.dart';

void main() {
  for (final unavailable in [false, true]) {
    testWidgets(
      'institution overview uses API data; unavailable=$unavailable',
      (tester) async {
        final reads = <String>[];
        final api = PlatformApi(
          client: MockClient((request) async {
            reads.add(request.url.path);
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
            expect(request.url.path, '/api/platform/overview');
            if (unavailable) return http.Response('{}', 503);
            return http.Response(
              jsonEncode({'data': institutionOverviewFixture()}),
              200,
            );
          }),
        );
        await api.login('office@example.test', 'synthetic-password', '123456');
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformConsole(
              api: api,
              browserState: MemoryBrowserState(),
              onSignedOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('520'), unavailable ? findsNothing : findsOneWidget);
        expect(
          find.text('Synthetic Madrasa'),
          unavailable ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Madrasa data is unavailable.'),
          unavailable ? findsOneWidget : findsNothing,
        );
        expect(reads.where((path) => path.endsWith('/overview')).length, 1);
        expect(find.text('No registered madrasas yet.'), findsNothing);
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
        final action = find.text('View all madrasas');
        await tester.ensureVisible(action);
        await tester.pump();
        await tester.tap(action);
        await tester.pump();
        expect(destination, busy ? isNull : PlatformPage.madrasas);
        if (!busy) {
          destination = null;
          Focus.of(tester.element(action)).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(destination, PlatformPage.madrasas);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final empty in [true, false]) {
    testWidgets('madrasa summary distinguishes empty=$empty from unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformOverview(
              isAdmin: true,
              name: 'Office',
              busy: false,
              error: null,
              snapshot: empty ? institutionOverviewFixture(empty: true) : {},
              onRefresh: () {},
              onNavigate: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.text(
          empty
              ? 'No registered madrasas yet.'
              : 'Madrasa data is unavailable.',
        ),
        findsOneWidget,
      );
      expect(find.text('0 / 0'), empty ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
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
      find.text('Sessions'),
      80,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
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
            home: PlatformConsole(
              api: api,
              browserState: MemoryBrowserState(),
              onSignedOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlatformWorkspaceShell), findsOneWidget);
        expect(
          find.text(
            role == 'SUPER_ADMIN'
                ? 'Institution Overview'
                : 'IT & Security Overview',
          ),
          findsWidgets,
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
          expect(find.text('Sessions'), findsNothing);
          expect(find.text('Madrassa setup'), findsNothing);
          await tester.tap(find.text('Users & Permissions'));
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(ChoiceChip, 'Company accounts'),
            findsNothing,
          );
          expect(paths, isNot(contains('/api/platform/accounts')));
          expect(paths, isNot(contains('/api/platform/health')));
        } else {
          expect(find.text('Company accounts'), findsWidgets);
          expect(find.text('Madrassa applications'), findsNothing);
          expect(find.text('Madrassa setup'), findsNothing);
          final accountLink = find
              .descendant(
                of: find.byType(Drawer).evaluate().isNotEmpty
                    ? find.byType(Drawer)
                    : find.byType(PlatformWorkspaceShell),
                matching: find.text('Company accounts'),
              )
              .last;
          await tester.ensureVisible(accountLink);
          await tester.tap(accountLink);
          await tester.pumpAndSettle();
          expect(paths, contains('/api/platform/accounts'));
          expect(paths, isNot(contains('/api/platform/provisioning-queue')));
          expect(find.byType(AlertDialog), findsNothing);
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
        home: PlatformConsole(
          api: api,
          browserState: MemoryBrowserState(),
          onSignedOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not available'), findsWidgets);
    expect(find.text('0'), findsNothing);
    expect(find.text('Madrasa data is unavailable.'), findsOneWidget);
    expect(find.byTooltip('Refresh overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
