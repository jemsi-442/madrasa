import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  testWidgets(
    'history paginates, retries without stale data, and closes at expiry',
    (tester) async {
      var failOlder = true;
      final pages = <String>[];
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data = [];
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {
                'id': 'admin',
                'fullName': 'Reviewer',
                'role': 'SUPER_ADMIN',
              },
            };
          } else if (req.url.path.endsWith('/access-history')) {
            final page = req.url.queryParameters['page']!;
            pages.add(page);
            if (page == '2' && failOlder) return http.Response('{}', 503);
            data = page == '1'
                ? List.generate(
                    20,
                    (i) => {
                      'action': 'platform.account.disabled',
                      'actorId': 'admin',
                      'createdAt': '2026-10-08T00:00:00Z',
                      'reason': 'First page reason $i',
                    },
                  )
                : [];
          } else if (req.url.path.endsWith('/accounts')) {
            data = [
              {
                'id': 'it',
                'fullName': 'Security Operator',
                'email': 'it@example.test',
                'role': 'IT_SECURITY',
                'status': 'DISABLED',
                'createdAt': '2026-10-08T00:00:00Z',
              },
            ];
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('admin@example.test', 'password', '123456');
      api.expiresAt = DateTime.now().add(const Duration(seconds: 60));
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Company accounts'));
      await tester.tap(find.text('Company accounts'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Access history'));
      await tester.tap(find.text('Access history'));
      await tester.pumpAndSettle();
      expect(find.text('First page reason 0'), findsOneWidget);
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(find.text('First page reason 0'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      failOlder = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No older changes on this page.'), findsOneWidget);
      await tester.tap(find.text('Newer'));
      await tester.pumpAndSettle();
      expect(find.text('First page reason 0'), findsOneWidget);
      expect(pages, ['1', '2', '2', '1']);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('First page reason 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets('Super Admin opens scoped account access history', (
    tester,
  ) async {
    final api = PlatformApi(
      client: MockClient((req) async {
        dynamic data = [];
        if (req.url.path.endsWith('/login')) {
          data = {
            'accessToken': 'token',
            'expiresIn': 900,
            'user': {
              'id': 'admin',
              'fullName': 'Reviewer',
              'role': 'SUPER_ADMIN',
            },
          };
        } else if (req.url.path.endsWith('/access-history')) {
          expect(req.url.path, endsWith('/accounts/it/access-history'));
          expect(req.url.queryParameters, {'page': '1', 'pageSize': '20'});
          data = [
            {
              'action': 'platform.account.disabled',
              'actorId': 'reviewer-2',
              'createdAt': '2026-10-08T00:00:00Z',
              'reason': 'Operator access under review',
            },
          ];
        } else if (req.url.path.endsWith('/accounts')) {
          data = [
            {
              'id': 'it',
              'fullName': 'Security Operator',
              'email': 'it@example.test',
              'role': 'IT_SECURITY',
              'status': 'DISABLED',
              'createdAt': '2026-10-08T00:00:00Z',
            },
          ];
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
    await api.login('admin@example.test', 'password', '123456');
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Company accounts'));
    await tester.tap(find.text('Company accounts'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Access history'));
    await tester.tap(find.text('Access history'));
    await tester.pumpAndSettle();
    expect(find.text('Operator access under review'), findsOneWidget);
    expect(find.text('Access disabled'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Operator access under review'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
