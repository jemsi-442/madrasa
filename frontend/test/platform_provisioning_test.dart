import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final outcome in ['available', 'occupied', 'linked', 'failure']) {
    testWidgets('setup check on mobile: $outcome', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final api = PlatformApi(
        client: MockClient((request) async {
          requests.add(request);
          dynamic data;
          if (request.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {
                'id': 'reviewer',
                'fullName': 'Reviewer',
                'role': 'SUPER_ADMIN',
              },
            };
          } else if (request.url.path.endsWith('/provisioning-preflight')) {
            if (outcome == 'failure') return http.Response('{}', 503);
            data = {
              'checks': {
                'independentReview': true,
                'schoolCodeAvailable': outcome == 'available',
              },
              'provisioningEnabled': false,
              'alreadyProvisioned': outcome == 'linked',
              'checkedAt': '2026-10-08T10:00:00Z',
            };
          } else {
            data = [
              {
                'id': 'application',
                'schoolName': 'Afaq School',
                'requestedCode': 'afaq-school',
                'adminEmail': 'admin@example.test',
                'status': 'APPROVED',
              },
            ];
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('reviewer@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check setup readiness'));
      await tester.tap(find.text('Check setup readiness'));
      await tester.pumpAndSettle();
      expect(
        requests.last.url.path,
        '/api/platform/tenant-applications/application/provisioning-preflight',
      );
      expect(
        requests.skip(1).every((request) => request.method == 'GET'),
        isTrue,
      );
      if (outcome == 'failure') {
        expect(find.text('Madrassa setup checks'), findsNothing);
        expect(
          find.textContaining('Platform access is not available yet'),
          findsOneWidget,
        );
      } else {
        expect(find.text('Madrassa setup checks'), findsOneWidget);
        expect(
          find.text(
            outcome == 'linked'
                ? 'Already provisioned: this application has a linked madrassa. Do not create another.'
                : outcome == 'available'
                ? 'Passed: school code is currently available.'
                : 'Blocked: school code is already in use.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Automatic provisioning is not enabled yet.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
