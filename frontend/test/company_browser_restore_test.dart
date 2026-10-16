import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/browser_state.dart';

class MemoryBrowser extends BrowserState {
  final values = <String, String>{};
  @override
  String? read(String key, {bool shared = false}) => values[key];
  @override
  void write(String key, String? value, {bool shared = false}) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    test('browser reload restores $role without a school session', () async {
      final browser = MemoryBrowser();
      final state = AppState(
        MifApiClient(
          browserAuth: true,
          client: MockClient((req) async {
            expect(req.url.path, '/api/auth/browser/refresh');
            return http.Response(
              jsonEncode({
                'data': {
                  'scope': 'platform',
                  'accessToken': 'restored-company-token',
                  'expiresIn': 420,
                  'user': {
                    'id': 'company',
                    'fullName': 'Company User',
                    'role': role,
                  },
                },
              }),
              200,
            );
          }),
        ),
        browserState: browser,
      );
      await state.restoreSession();
      expect(state.companyApi!.user!['role'], role);
      expect(state.session, isNull);
      expect(state.restorationError, isNull);
      expect(browser.values.values, isNot(contains('restored-company-token')));
      state.dispose();
    });
  }
  test('expired cookie does not restore any account', () async {
    final state = AppState(
      MifApiClient(
        browserAuth: true,
        client: MockClient(
          (_) async => http.Response('{"message":"Please sign in"}', 401),
        ),
      ),
    );
    await state.restoreSession();
    expect(state.companyApi, isNull);
    expect(state.session, isNull);
    expect(state.restorationError, isNull);
    state.dispose();
  });
}
