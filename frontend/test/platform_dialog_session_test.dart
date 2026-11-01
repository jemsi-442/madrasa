import 'dart:convert';
import 'helpers/platform_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final width in [800.0, 1400.0]) {
    for (final sessionAction in [false, true]) {
      for (final replaceSession in [false, true]) {
        testWidgets(
          'dialog blocks stale action width=$width account=$sessionAction replaced=$replaceSession',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
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
                      'role': sessionAction ? 'IT_SECURITY' : 'SUPER_ADMIN',
                    },
                  };
                } else if (req.method == 'POST') {
                  writes++;
                  data = {};
                } else if (req.url.path.endsWith('/sessions')) {
                  data = [
                    {
                      'id': 'session',
                      'current': true,
                      'createdAt': '2026-10-08T00:00:00Z',
                      'expiresAt': '2026-10-08T00:15:00Z',
                    },
                  ];
                } else {
                  data = [
                    {
                      'id': 'request',
                      'schoolName': 'School',
                      'requestedCode': 'school-code',
                      'adminEmail': 'school@example.test',
                      'status': 'REQUESTED',
                      'requestedById': 'other',
                    },
                  ];
                }
                return http.Response(jsonEncode({'data': data}), 200);
              }),
            );
            await api.login('admin@example.test', 'password', '123456');
            api.expiresAt = DateTime.now().add(const Duration(seconds: 30));
            await tester.pumpWidget(
              MaterialApp(home: PlatformConsole(api: api)),
            );
            if (sessionAction) {
              await openPlatformPage(tester, 'My sessions');
              await tester.ensureVisible(find.text('Review'));
              await tester.tap(find.text('Review'));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Sign out this session'));
              await tester.tap(find.text('Sign out this session'));
              await tester.pumpAndSettle();
            } else {
              await tester.ensureVisible(find.text('Refresh'));
              await tester.tap(find.text('Refresh'));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Approve'));
              await tester.tap(find.text('Approve'));
              await tester.pumpAndSettle();
              await tester.enterText(
                find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(TextFormField),
                ),
                'Reviewed under the original session',
              );
            }
            if (replaceSession) {
              await api.login('admin@example.test', 'password', '654321');
              await tester.tap(
                find.text(
                  sessionAction ? 'Revoke session' : 'Confirm approval',
                ),
              );
              await tester.pumpAndSettle();
            } else {
              await tester.pump(const Duration(seconds: 31));
              await tester.pumpAndSettle();
              expect(find.text('Platform sign in'), findsOneWidget);
            }
            expect(find.byType(AlertDialog), findsNothing);
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
