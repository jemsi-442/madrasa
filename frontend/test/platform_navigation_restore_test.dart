import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/browser_state.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';

class MemoryNavigation extends BrowserState {
  final values = <String, String>{};
  @override
  String? read(String key, {bool shared = false}) {
    expect(shared, false);
    return values[key];
  }

  @override
  void write(String key, String? value, {bool shared = false}) {
    expect(shared, false);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  for (final scenario in [
    ('SUPER_ADMIN', 'oversight', PlatformPage.oversight),
    ('SUPER_ADMIN', 'curriculum', PlatformPage.curriculum),
    ('SUPER_ADMIN', 'health', PlatformPage.home),
    ('SUPER_ADMIN', 'invalid', PlatformPage.home),
    ('IT_SECURITY', 'oversight', PlatformPage.home),
    ('IT_SECURITY', 'health', PlatformPage.health),
  ]) {
    testWidgets('restore ${scenario.$1} ${scenario.$2} safely', (tester) async {
      final storage = MemoryNavigation();
      final key = 'afaq.platform.page.synthetic.${scenario.$1}';
      storage.values[key] = scenario.$2;
      storage.values['afaq.platform.page.other.${scenario.$1}'] = 'accounts';
      final paths = <String>[];
      final api = PlatformApi(
        client: MockClient((request) async {
          paths.add(request.url.path);
          dynamic data = [];
          if (request.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'synthetic-token',
              'expiresIn': 900,
              'user': {
                'id': 'synthetic',
                'role': scenario.$1,
                'fullName': 'Synthetic User',
              },
            };
          } else if (request.url.path.endsWith('/overview')) {
            data = {
              'applications': {},
              'onboarding': {},
              'awaitingYourReview': 0,
            };
          } else if (request.url.path.endsWith('/health')) {
            data = {'status': 'healthy', 'checks': []};
          } else if (request.url.path.contains('/curriculum')) {
            data = {
              'items': [],
              'total': 0,
              'madrasaCount': 0,
              'hasMore': false,
            };
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('synthetic@example.test', 'test-only', '123456');
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformConsole(
            api: api,
            browserState: storage,
            onSignedOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlatformWorkspaceShell>(find.byType(PlatformWorkspaceShell))
            .page,
        scenario.$3,
      );
      expect(storage.values[key], scenario.$3.name);
      expect(
        storage.values['afaq.platform.page.other.${scenario.$1}'],
        'accounts',
      );
      expect(storage.values.values, isNot(contains('synthetic-token')));
      if (scenario.$3 == PlatformPage.oversight) {
        tester
            .widget<PlatformWorkspaceShell>(find.byType(PlatformWorkspaceShell))
            .onNavigate(PlatformPage.curriculum);
        await tester.pumpAndSettle();
        expect(storage.values[key], 'curriculum');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformConsole(
              api: api,
              browserState: storage,
              onSignedOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PlatformWorkspaceShell>(
                find.byType(PlatformWorkspaceShell),
              )
              .page,
          PlatformPage.curriculum,
        );
      }
      if (scenario.$1 == 'IT_SECURITY') {
        expect(paths.where((path) => path.contains('/curriculum')), isEmpty);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
