import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

const snapshot = <String, dynamic>{
  'status': 'degraded',
  'checkedAt': '2026-10-08T00:00:00.000Z',
  'checks': [
    {'name': 'database', 'status': 'available', 'latencyMs': 4},
    {'name': 'redis', 'status': 'unavailable', 'latencyMs': null},
  ],
};

void main() {
  testWidgets('degraded health has clear text and fits mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlatformHealthPanel(snapshot: snapshot, loading: false),
          ),
        ),
      ),
    );
    expect(find.text('Service attention needed'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);
    expect(
      find.text('Unavailable. Escalate to the on-call operator.'),
      findsOneWidget,
    );
    expect(find.text('4 ms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing snapshot never claims services are healthy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlatformHealthPanel(snapshot: null, loading: false),
        ),
      ),
    );
    expect(find.text('No health result available'), findsOneWidget);
    expect(find.text('Core services available'), findsNothing);
  });

  testWidgets(
    'IT health tab uses protected API and removes stale results on refresh failure',
    (tester) async {
      var fail = false;
      final api = PlatformApi(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'test-token',
                  'expiresIn': 900,
                  'user': {
                    'id': 'it',
                    'role': 'IT_SECURITY',
                    'fullName': 'IT Operator',
                  },
                },
              }),
              200,
            );
          }
          if (req.url.path.endsWith('/health')) {
            expect(req.headers['Authorization'], 'Bearer test-token');
            return fail
                ? http.Response('{}', 503)
                : http.Response(jsonEncode({'data': snapshot}), 200);
          }
          return http.Response('{"data":[]}', 200);
        }),
      );
      await api.login('it@example.test', 'test-password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('System health'));
      await tester.tap(find.text('System health'));
      await tester.pumpAndSettle();
      expect(find.text('Service attention needed'), findsOneWidget);
      expect(find.text('Request madrassa'), findsNothing);
      fail = true;
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Service attention needed'), findsNothing);
      expect(find.text('No health result available'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
