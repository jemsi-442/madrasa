import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/platform_navigation.dart';

void main() {
  for (final width in [800.0, 1440.0]) {
    for (final health in [false, true]) {
      testWidgets(
        'Investigation draft is consumed once at $width health=$health',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var writes = 0;
          final api = PlatformApi(
            client: MockClient((request) async {
              dynamic data = {
                'items': [],
                'total': 0,
                'open': 0,
                'high': 0,
                'resolved': 0,
              };
              if (request.url.path.endsWith('/login')) {
                data = {
                  'accessToken': 'synthetic',
                  'expiresIn': 900,
                  'user': {
                    'id': 'synthetic-it',
                    'fullName': 'Test IT',
                    'role': 'IT_SECURITY',
                  },
                };
              } else if (request.method == 'POST') {
                writes++;
              } else if (request.url.path.endsWith('/health')) {
                data = {
                  'checkedAt': DateTime.now().toUtc().toIso8601String(),
                  'checks': [
                    {
                      'name': 'database',
                      'status': 'unavailable',
                      'detail': 'private-sentinel',
                    },
                  ],
                };
              } else if (request.url.path.endsWith('/sync/received')) {
                data = {
                  'items': [
                    {
                      'receiptId': 'RECEIPT-TEST',
                      'madrasaId': 'MADRASA-TEST',
                      'receivedAt': '2026-01-01T00:00:00Z',
                    },
                  ],
                  'total': 1,
                  'capturedAt': '2026-01-01T00:00:00Z',
                };
              }
              return http.Response(jsonEncode({'data': data}), 200);
            }),
          );
          await api.login('it@example.test', 'synthetic', '123456');
          await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
          final page = health ? 'System health' : 'Offline Sync';
          final action = health
              ? 'Investigate failed checks'
              : 'Investigate receipt';
          await openPlatformPage(tester, page);
          await tester.ensureVisible(find.text(action));
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).at(1))
                .controller!
                .text,
            contains(
              health ? 'Unavailable services: Database' : 'RECEIPT-TEST',
            ),
          );
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).at(1))
                .controller!
                .text,
            isNot(contains('private-sentinel')),
          );
          expect(writes, 0);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Record incident'));
          await tester.tap(find.text('Record incident'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).at(1))
                .controller!
                .text,
            isEmpty,
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await openPlatformPage(tester, page);
          await openPlatformPage(tester, 'Security Incidents');
          expect(find.byType(AlertDialog), findsNothing);
          expect(writes, 0);
          await tester.pumpWidget(const SizedBox());
          api.close();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
