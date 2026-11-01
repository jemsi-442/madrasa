import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/platform_navigation.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final disabled in [false, true]) {
      for (final historyAvailable in [false, true]) {
        testWidgets(
          'read-only account feedback disabled=$disabled history=$historyAvailable at $width',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var writes = 0;
            var historyReads = 0;
            var available = historyAvailable;
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
                } else if (req.url.path.endsWith('/access-history')) {
                  historyReads++;
                  expect(req.url.path, endsWith('/accounts/it/access-history'));
                  if (!available) return http.Response('{}', 503);
                  data = [
                    {
                      'id': 'event',
                      'action': 'platform.account.disabled',
                      'actorId': 'other-admin',
                      'createdAt': '2026-10-08T00:00:00Z',
                      'reason': 'Access under review',
                    },
                  ];
                } else if (req.method == 'POST') {
                  writes++;
                  return http.Response('{}', 403);
                } else if (req.url.path.endsWith('/accounts')) {
                  if (writes > 0) return http.Response('{}', 503);
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
            await tester.pumpWidget(
              MaterialApp(home: PlatformConsole(api: api)),
            );
            await tester.pumpAndSettle();
            await openPlatformPage(tester, 'Company accounts');
            await tester.ensureVisible(find.text('Review'));
            await tester.tap(find.text('Review'));
            await tester.pumpAndSettle();
            expect(find.text('Disable IT account'), findsNothing);
            expect(find.text('Review restoration'), findsNothing);
            await tester.ensureVisible(find.text('Access history'));
            await tester.tap(find.text('Access history'));
            await tester.pumpAndSettle();
            if (!available) {
              expect(find.text('Retry'), findsOneWidget);
              expect(find.text('Access under review'), findsNothing);
              available = true;
              await tester.tap(find.text('Retry'));
              await tester.pumpAndSettle();
            }
            expect(find.text('Access under review'), findsOneWidget);
            expect(historyReads, historyAvailable ? 1 : 2);
            expect(find.text('Confirm restore'), findsNothing);
            expect(find.text('Confirm disable'), findsNothing);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
            expect(find.text('Access under review'), findsNothing);
            expect(writes, 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            api.close();
          },
        );
      }
    }
  }
}
