import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  testWidgets('company filters send scoped query and clear together', (
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
              'role': 'SUPER_ADMIN',
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
    await tester.ensureVisible(find.text('Company accounts'));
    await tester.tap(find.text('Company accounts'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('Account role-')));
    await tester.tap(find.byKey(const ValueKey('Account role-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IT Security').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('Account status-')));
    await tester.tap(find.byKey(const ValueKey('Account status-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disabled').last);
    await tester.pumpAndSettle();
    expect(queries.last, {
      'page': '1',
      'pageSize': '20',
      'role': 'IT_SECURITY',
      'status': 'DISABLED',
    });
    await tester.ensureVisible(find.text('Office history'));
    await tester.tap(find.text('Office history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company accounts'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear account filters'));
    await tester.tap(find.text('Clear account filters'));
    await tester.pumpAndSettle();
    expect(queries.last, {'page': '1', 'pageSize': '20'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets('disable IT requires a valid reason and confirmation', (
    tester,
  ) async {
    var disabled = false;
    var writes = 0;
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
        } else if (req.url.path.endsWith('/disable')) {
          expect(jsonDecode(req.body), {
            'reason': 'Operator access no longer required',
          });
          writes++;
          disabled = true;
          data = {'id': 'it', 'status': 'DISABLED', 'revoked': 1};
        } else if (req.url.path.endsWith('/accounts')) {
          data = [
            {
              'id': 'it',
              'fullName': 'Security Operator',
              'email': 'it@example.test',
              'role': 'IT_SECURITY',
              'status': disabled ? 'DISABLED' : 'ACTIVE',
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
    await tester.ensureVisible(find.text('Disable IT account'));
    await tester.tap(find.text('Disable IT account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Disable IT account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm disable'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 10 characters.'), findsOneWidget);
    expect(writes, 0);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'Operator access no longer required',
    );
    await tester.tap(find.text('Confirm disable'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('DISABLED'), findsOneWidget);
    expect(find.text('Disable IT account'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
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
      if (role == 'SUPER_ADMIN') {
        await tester.ensureVisible(find.text('Office history'));
        await tester.tap(find.text('Office history'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Company accounts'));
        await tester.tap(find.text('Company accounts'));
        await tester.pumpAndSettle();
        expect(reads, 1);
        expect(find.text('Company Reviewer'), findsOneWidget);
        expect(find.text('Your account'), findsOneWidget);
        expect(find.text('Request madrassa'), findsNothing);
        expect(find.text('My sessions'), findsNothing);
        await tester.ensureVisible(find.text('Office history'));
        await tester.tap(find.text('Office history'));
        await tester.pumpAndSettle();
        expect(find.text('Company Reviewer'), findsNothing);
      } else {
        expect(find.text('Company accounts'), findsNothing);
        expect(reads, 0);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
