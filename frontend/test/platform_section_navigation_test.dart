import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:mif_app/src/browser_state.dart';

class SavedTechnicalPage extends BrowserState {
  SavedTechnicalPage(this.page);
  final String page;
  @override
  String? read(String key, {bool shared = false}) => page;
  @override
  void write(String key, String? value, {bool shared = false}) {}
}

void main() {
  testWidgets('IT opens company directory without lifecycle actions', (
    tester,
  ) async {
    final api = PlatformApi(
      client: MockClient((request) async {
        dynamic data = <String, dynamic>{};
        if (request.url.path.endsWith('/login')) {
          data = {
            'accessToken': 'demo',
            'expiresIn': 900,
            'user': {'id': 'it', 'fullName': 'Demo IT', 'role': 'IT_SECURITY'},
          };
        } else if (request.url.path.endsWith('/accounts')) {
          data = [
            {
              'id': 'other-it',
              'fullName': 'Demo operator',
              'email': 'operator@example.test',
              'role': 'IT_SECURITY',
              'status': 'ACTIVE',
              'createdAt': '2026-10-01T00:00:00Z',
            },
          ];
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
    await api.login('it@example.test', 'test-only', '123456');
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformConsole(api: api, onSignedOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Company accounts'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo operator'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Disable IT account'), findsNothing);
    expect(find.text('Review restoration'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  for (final saved in [
    'accounts',
    'history',
    'sessions',
    'offlineSync',
    'integrations',
  ]) {
    testWidgets('superadmin cannot restore technical page $saved', (
      tester,
    ) async {
      final paths = <String>[];
      final api = PlatformApi(
        client: MockClient((request) async {
          paths.add(request.url.path);
          final data = request.url.path.endsWith('/login')
              ? {
                  'accessToken': 'demo',
                  'expiresIn': 900,
                  'user': {
                    'id': 'admin',
                    'fullName': 'Demo admin',
                    'role': 'SUPER_ADMIN',
                  },
                }
              : <String, dynamic>{};
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('admin@example.test', 'test-only', '123456');
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformConsole(
            api: api,
            onSignedOut: () {},
            browserState: SavedTechnicalPage(saved),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths, contains('/api/platform/overview'));
      for (final endpoint in ['accounts', 'audit-events', 'sessions']) {
        expect(paths, isNot(contains('/api/platform/$endpoint')));
      }
      expect(find.text('Manage company access'), findsNothing);
      expect(find.text('Follow office decisions'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  for (final width in [390.0, 1440.0]) {
    for (final admin in [true, false]) {
      testWidgets('technical navigation admin=$admin at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformWorkspaceShell(
              isAdmin: admin,
              name: 'Demo office',
              page: admin ? PlatformPage.staff : PlatformPage.home,
              onNavigate: (_) {},
              busy: false,
              actions: const [],
              child: const SizedBox.expand(),
            ),
          ),
        );
        if (width < 900) {
          await tester.tap(find.byTooltip('Open navigation'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Company accounts'),
          admin ? findsNothing : findsOneWidget,
        );
        expect(find.text('Office history'), findsNothing);
        expect(find.text('Activity log'), findsNothing);
        expect(find.text('Settings & Security'), findsNothing);
        expect(find.text('Sessions'), admin ? findsNothing : findsOneWidget);
        expect(find.text('Audit trail'), admin ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
