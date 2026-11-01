import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/platform_navigation.dart';

void main() {
  testWidgets('company filters send scoped query and can be reset', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
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
              'role': 'IT_SECURITY',
            },
          };
        } else if (req.url.path.endsWith('/accounts')) {
          queries.add(req.url.queryParameters);
        } else if (req.url.path.endsWith('/audit-events')) {
          expect(req.url.queryParameters.containsKey('role'), isFalse);
          expect(req.url.queryParameters.containsKey('status'), isFalse);
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
    await api.login('admin@example.test', 'password', '123456');
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    await tester.pumpAndSettle();
    await openPlatformPage(tester, 'Company accounts');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('role-')));
    await tester.tap(find.byKey(const ValueKey('role-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IT Security').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('status-')));
    await tester.tap(find.byKey(const ValueKey('status-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disabled').last);
    await tester.pumpAndSettle();
    expect(queries.last, {
      'page': '1',
      'pageSize': '20',
      'role': 'IT_SECURITY',
      'status': 'DISABLED',
    });
    await openPlatformPage(tester, 'Office history');
    await tester.pumpAndSettle();
    await openPlatformPage(tester, 'Company accounts');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('role-IT_SECURITY')));
    await tester.tap(find.byKey(const ValueKey('role-IT_SECURITY')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All company roles').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('status-DISABLED')));
    await tester.tap(find.byKey(const ValueKey('status-DISABLED')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All statuses').last);
    await tester.pumpAndSettle();
    expect(queries.last, {'page': '1', 'pageSize': '20'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  for (final status in ['ACTIVE', 'DISABLED']) {
    testWidgets('IT account review stays read-only for $status', (
      tester,
    ) async {
      var writes = 0;
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data = [];
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {
                'id': 'operator',
                'fullName': 'Operator',
                'role': 'IT_SECURITY',
              },
            };
          } else {
            if (req.method != 'GET') writes++;
            if (req.url.path.endsWith('/accounts')) {
              data = [
                {
                  'id': 'it',
                  'fullName': 'Synthetic Operator',
                  'email': 'it@example.test',
                  'role': 'IT_SECURITY',
                  'status': status,
                },
              ];
            }
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('operator@example.test', 'synthetic-password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await openPlatformPage(tester, 'Company accounts');
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Read-only account review.'), findsOneWidget);
      expect(find.text('Disable IT account'), findsNothing);
      expect(find.text('Review restoration'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    testWidgets('company directory access for $role on mobile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reads = 0;
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data = [];
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {'id': 'operator', 'fullName': 'Operator', 'role': role},
            };
          } else if (req.url.path.endsWith('/accounts')) {
            reads++;
            expect(req.url.queryParameters, {'page': '1', 'pageSize': '20'});
            data = [
              {
                'id': 'operator',
                'fullName': 'Company Reviewer',
                'email': 'reviewer@example.test',
                'role': 'SUPER_ADMIN',
                'status': 'ACTIVE',
                'createdAt': '2026-10-08T00:00:00Z',
              },
            ];
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('operator@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.pumpAndSettle();
      if (role == 'IT_SECURITY') {
        await openPlatformPage(tester, 'Office history');
        await openPlatformPage(tester, 'Company accounts');
        expect(reads, 1);
        expect(find.text('Company Reviewer'), findsOneWidget);
        expect(find.text('ACTIVE'), findsWidgets);
        expect(find.text('Request madrassa'), findsNothing);

        await openPlatformPage(tester, 'Office history');
        expect(find.text('Company Reviewer'), findsNothing);
      } else {
        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();
        expect(find.text('Company accounts'), findsNothing);
        expect(reads, 0);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
