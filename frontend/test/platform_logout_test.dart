import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final all in [false, true]) {
    for (final outcome in ['success', 'offline', 'server error']) {
      testWidgets('logout all=$all clears local session on $outcome', (
        tester,
      ) async {
        final paths = <String>[];
        final api = PlatformApi(
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'private-token',
                    'expiresIn': 900,
                    'user': {
                      'id': 'operator',
                      'fullName': 'Private Operator',
                      'role': 'SUPER_ADMIN',
                    },
                  },
                }),
                200,
              );
            }
            expect(request.headers['Authorization'], 'Bearer private-token');
            if (outcome == 'offline') {
              throw http.ClientException('network unavailable');
            }
            return http.Response(
              jsonEncode({
                'data': {'revoked': 1},
              }),
              outcome == 'server error' ? 503 : 200,
            );
          }),
        );
        await api.login('operator@example.test', 'password', '123456');
        await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
        await tester.tap(find.byTooltip('Sign out options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(all ? 'Sign out all sessions' : 'Sign out'));
        await tester.pumpAndSettle();
        if (all) {
          expect(paths.length, 1);
          await tester.tap(find.text('Confirm sign out everywhere'));
          await tester.pumpAndSettle();
        }
        expect(paths.last, '/api/platform/${all ? 'logout-all' : 'logout'}');
        expect(paths.length, 2);
        expect(api.user, isNull);
        expect(api.expiresAt, isNull);
        expect(find.text('Platform sign in'), findsOneWidget);
        expect(find.textContaining('Welcome, Private Operator'), findsNothing);
        expect(
          find.textContaining('Signed out on this device.'),
          outcome == 'success' ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      });
    }
  }

  for (final change in ['cancel', 'new login', 'expiry']) {
    testWidgets('bulk logout does not submit after $change', (tester) async {
      var writes = 0;
      final api = PlatformApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'token',
                  'expiresIn': 900,
                  'user': {
                    'id': 'operator',
                    'fullName': 'Operator',
                    'role': 'IT_SECURITY',
                  },
                },
              }),
              200,
            );
          }
          writes++;
          return http.Response('{"data":{}}', 200);
        }),
      );
      await api.login('operator@example.test', 'password', '123456');
      if (change == 'expiry') {
        api.expiresAt = DateTime.now().add(const Duration(seconds: 3));
      }
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.tap(find.byTooltip('Sign out options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out all sessions'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out everywhere?'), findsOneWidget);
      if (change == 'expiry') {
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(api.user, isNull);
        expect(find.text('Platform sign in'), findsOneWidget);
      } else {
        if (change == 'new login') {
          await api.login('operator@example.test', 'password', '654321');
        }
        await tester.tap(
          find.text(
            change == 'cancel' ? 'Cancel' : 'Confirm sign out everywhere',
          ),
        );
        await tester.pumpAndSettle();
        expect(api.user, isNotNull);
      }
      expect(find.text('Sign out everywhere?'), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
