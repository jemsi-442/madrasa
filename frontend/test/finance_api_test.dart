import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app_state.dart';

const _session = AuthSession(
  accessToken: 'old-access',
  refreshToken: 'refresh',
  userId: '9',
  fullName: 'Accountant',
  role: 'ACCOUNTANT',
);

void main() {
  test('finance inquiry PATCH uses authenticated AppState request', () async {
    final state = AppState(
      MifApiClient(
        baseUrl: 'https://school.test',
        browserAuth: false,
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.headers['Authorization'], 'Bearer old-access');
          expect(request.url.path, '/api/public-inquiries/4/status');
          expect(jsonDecode(request.body), {'status': 'CONTACTED'});
          return http.Response('{"data":{"id":"4","status":"CONTACTED"}}', 200);
        }),
      ),
    )..session = _session;
    addTearDown(state.dispose);
    final result = await state.update('/api/public-inquiries/4/status', {
      'status': 'CONTACTED',
    });
    expect(result['status'], 'CONTACTED');
  });

  test('CSV reads UTF-8 text with auth and never treats it as JSON', () async {
    const content = 'Month,Amount\r\nJanuari,1250.00\r\n';
    final state = AppState(
      MifApiClient(
        baseUrl: 'https://school.test',
        browserAuth: false,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Accept'], 'text/csv');
          expect(request.headers['Authorization'], 'Bearer old-access');
          expect(request.url.queryParameters['year'], '2026');
          return http.Response(
            content,
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      ),
    )..session = _session;
    addTearDown(state.dispose);
    expect(
      await state.exportCsv(
        '/api/reports/finance/monthly-summary/export?year=2026',
      ),
      content,
    );
  });

  test(
    'CSV request refreshes an expired token and preserves its format',
    () async {
      var exports = 0;
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          browserAuth: false,
          client: MockClient((request) async {
            if (request.url.path == '/api/auth/refresh') {
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'new-access',
                    'refreshToken': 'renewed',
                    'user': {
                      'id': '9',
                      'fullName': 'Accountant',
                      'role': 'ACCOUNTANT',
                    },
                  },
                }),
                200,
              );
            }
            exports++;
            expect(request.headers['Accept'], 'text/csv');
            if (exports == 1) {
              return http.Response('{"message":"Expired"}', 401);
            }
            expect(request.headers['Authorization'], 'Bearer new-access');
            return http.Response(
              'Month,Total\nJan,25.00',
              200,
              headers: {'content-type': 'text/csv'},
            );
          }),
        ),
      )..session = _session;
      addTearDown(state.dispose);
      expect(
        await state.exportCsv(
          '/api/reports/finance/monthly-summary/export?year=2026',
        ),
        contains('Jan,25.00'),
      );
      expect(exports, 2);
    },
  );

  for (final (status, type, body) in [
    (200, 'application/json', '{"data":{}}'),
    (200, 'text/html', '<html>Login</html>'),
    (403, 'application/json', '{"message":"Forbidden"}'),
  ]) {
    test('CSV rejects $status $type instead of saving an error page', () async {
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          browserAuth: false,
          client: MockClient(
            (_) async =>
                http.Response(body, status, headers: {'content-type': type}),
          ),
        ),
      )..session = _session;
      addTearDown(state.dispose);
      await expectLater(
        state.exportCsv('/api/reports/finance/monthly-summary/export'),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test(
    'signed-out user cannot update inquiries or fetch financial CSV',
    () async {
      var calls = 0;
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          browserAuth: false,
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(state.dispose);
      await expectLater(
        state.update('/api/public-inquiries/4/status', {'status': 'CLOSED'}),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        state.exportCsv('/api/reports/finance/monthly-summary/export'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    },
  );
}
