import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app_state.dart';

void main() {
  test('sign in does not display the server error verbatim', () async {
    final state = AppState(
      MifApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Invalid credentials'}),
            401,
          ),
        ),
      ),
    );
    addTearDown(state.dispose);
    expect(await state.signIn('amina@example.com', 'wrong'), isFalse);
    expect(state.error, 'The phone number or email and password do not match.');
  });

  test(
    'registration hides internal errors and explains duplicate accounts',
    () async {
      var status = 500;
      final state = AppState(
        MifApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'message': 'Database connection failed'}),
              status,
            ),
          ),
        ),
      );
      addTearDown(state.dispose);
      Future<bool> register() => state.register(
        fullName: 'Amina Hassan',
        email: 'amina@example.com',
        password: 'Learning123!',
        confirmPassword: 'Learning123!',
      );
      expect(await register(), isFalse);
      expect(
        state.error,
        'We could not create your account. Please try again later.',
      );
      expect(state.session, isNull);
      status = 409;
      expect(await register(), isFalse);
      expect(
        state.error,
        'This email already has an account. Please log in instead.',
      );
      state.clearError();
      expect(state.error, isNull);
    },
  );
}
