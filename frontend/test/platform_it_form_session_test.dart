import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

import 'helpers/platform_navigation.dart';

void main() {
  for (final backup in [false, true]) {
    for (final replace in [false, true]) {
      testWidgets('IT form session guard backup=$backup replacement=$replace', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var writes = 0;
        final api = PlatformApi(
          client: MockClient((request) async {
            dynamic data = {'items': [], 'total': 0};
            if (request.url.path.endsWith('/login')) {
              data = {
                'accessToken': 'synthetic-token',
                'expiresIn': 900,
                'user': {
                  'id': 'synthetic-it',
                  'fullName': 'Test IT',
                  'role': 'IT_SECURITY',
                },
              };
            } else if (request.method == 'POST') {
              writes++;
            }
            return http.Response(jsonEncode({'data': data}), 200);
          }),
        );
        await api.login('it@example.test', 'synthetic', '123456');
        api.expiresAt = DateTime.now().add(const Duration(seconds: 30));
        Widget app() => MaterialApp(home: PlatformConsole(api: api));
        await tester.pumpWidget(app());
        await openPlatformPage(
          tester,
          backup ? 'Backups & Recovery' : 'Security Incidents',
        );
        await tester.tap(
          find.text(backup ? 'Request restore test' : 'Record incident'),
        );
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(fields.at(0), 'SYNTHETIC-TEST');
        await tester.enterText(
          fields.at(1),
          'Synthetic test details for an isolated test',
        );
        if (replace) {
          await api.login('other@example.test', 'synthetic', '654321');
          // Parent rebuilds must not rebind an already-open form to the new login.
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          await tester.tap(find.text(backup ? 'Record request' : 'Save'));
          await tester.pumpAndSettle();
          expect(find.text('SYNTHETIC-TEST'), findsOneWidget);
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(seconds: 31));
          await tester.pumpAndSettle();
          expect(find.text('Platform sign in'), findsOneWidget);
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(writes, 0);
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      });
    }
  }
}
