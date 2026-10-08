import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

Map<String, dynamic> get snapshot => <String, dynamic>{
  'status': 'degraded',
  'checkedAt': DateTime.now().toUtc().toIso8601String(),
  'checks': [
    {'name': 'database', 'status': 'available', 'latencyMs': 4},
    {'name': 'redis', 'status': 'unavailable', 'latencyMs': null},
  ],
};

void main() {
  testWidgets(
    'fresh results expire without fetching and recover on new snapshot',
    (tester) async {
      var now = DateTime.utc(2026, 10, 8);
      final data = <String, dynamic>{
        'status': 'healthy',
        'checkedAt': now.toIso8601String(),
        'checks': <dynamic>[],
      };
      Widget panel() => MaterialApp(
        home: Scaffold(
          body: PlatformHealthPanel(
            snapshot: data,
            loading: false,
            now: () => now,
          ),
        ),
      );
      await tester.pumpWidget(panel());
      expect(find.text('Core services available'), findsOneWidget);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Health results need refreshing'), findsOneWidget);
      expect(find.text('Core services available'), findsNothing);
      data['checkedAt'] = now.toIso8601String();
      await tester.pumpWidget(panel());
      expect(find.text('Core services available'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    },
  );

  for (final timestamp in [null, 'invalid', '2099-01-01T00:00:00Z']) {
    testWidgets(
      'unverified timestamp never claims current health: $timestamp',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlatformHealthPanel(
                  snapshot: {'status': 'healthy', 'checkedAt': timestamp},
                  loading: false,
                  now: () => DateTime.utc(2026, 10, 8),
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('Health check time cannot be verified'),
          findsOneWidget,
        );
        expect(find.text('Core services available'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('degraded health has clear text and fits mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
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
    expect(find.text('Operator next steps'), findsOneWidget);
    expect(find.textContaining('Redis: verify'), findsOneWidget);
    expect(find.textContaining('Database: verify'), findsNothing);
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
    expect(find.text('Operator next steps'), findsNothing);
  });

  for (final unavailable in [true, false]) {
    testWidgets(
      'database guidance follows current availability: $unavailable',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlatformHealthPanel(
                  snapshot: {
                    'status': unavailable ? 'degraded' : 'healthy',
                    'checkedAt': DateTime.now().toUtc().toIso8601String(),
                    'checks': [
                      {
                        'name': 'database',
                        'status': unavailable ? 'unavailable' : 'available',
                      },
                      {'name': 'redis', 'status': 'available'},
                    ],
                  },
                  loading: false,
                ),
              ),
            ),
          ),
        );
        expect(
          find.textContaining('Database: verify'),
          unavailable ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining('Redis: verify'), findsNothing);
        expect(
          find.textContaining('This panel does not create an incident'),
          unavailable ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      expect(find.text('Operator next steps'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
