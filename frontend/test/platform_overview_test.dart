import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/institution_overview_fixture.dart';
import 'helpers/platform_navigation.dart';

void main() {
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    testWidgets('overview visibility and failure recovery for $role', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var unavailable = false;
      var reads = 0;
      var madrasaReads = 0;
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data = [];
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {'id': 'operator', 'fullName': 'Operator', 'role': role},
            };
          } else if (req.url.path.endsWith('/overview')) {
            reads++;
            if (unavailable) return http.Response('{}', 503);
            data = institutionOverviewFixture();
          } else if (req.url.path.endsWith('/health')) {
            data = {
              'checks': [],
              'checkedAt': DateTime.now().toUtc().toIso8601String(),
            };
          } else if (req.url.path.endsWith('/madrasas')) {
            madrasaReads++;
            data = {'items': [], 'total': 0};
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('operator@example.test', 'synthetic-password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await openPlatformPage(tester, 'Overview');
      expect(find.byKey(const ValueKey('workspace-footer')), findsOneWidget);
      if (role == 'SUPER_ADMIN') {
        expect(find.text('Institution Overview'), findsOneWidget);
        expect(find.text('520'), findsOneWidget);
        expect(find.text('Disabled IT accounts'), findsNothing);
        for (final action in ['View onboarding', 'Review madrasa requests']) {
          await tester.ensureVisible(find.text(action));
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(find.text('Madrasa directory'), findsWidgets);
          await openPlatformPage(tester, 'Overview');
        }
        expect(madrasaReads, 2);
        unavailable = true;
        await tester.tap(find.byTooltip('Refresh overview'));
        await tester.pumpAndSettle();
        expect(find.text('520'), findsNothing);
        expect(find.text('0'), findsNothing);
        expect(find.text('Madrasa data is unavailable.'), findsOneWidget);
        unavailable = false;
        await tester.tap(find.byTooltip('Refresh overview'));
        await tester.pumpAndSettle();
        expect(find.text('520'), findsOneWidget);
        expect(reads, 5);
      } else {
        expect(find.text('IT & Security Overview'), findsOneWidget);
        expect(find.text('Institution Overview'), findsNothing);
        expect(reads, 0);
        expect(madrasaReads, 0);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
