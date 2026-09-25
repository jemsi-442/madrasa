import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_state.dart';

void main() {
  test('sign in does not display the server error verbatim', () async {
    final client = MockClient((_) async {
      return http.Response(jsonEncode({'message': 'Invalid credentials'}), 401);
    });
    final state = AppState(
      MifApiClient(client: client, baseUrl: 'https://school.test'),
    );
    addTearDown(state.dispose);

    expect(await state.signIn('amina@example.com', 'wrong'), isFalse);
    expect(state.error, 'The phone number or email and password do not match.');
  });

  testWidgets('registration hides internal server errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({'message': 'Database connection failed'}),
        500,
      );
    });
    final state = AppState(
      MifApiClient(client: client, baseUrl: 'https://school.test'),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(MifApp(state: state));
    await tester.tap(find.text('Join the foundation'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Amina Hassan');
    await tester.enterText(find.byType(TextFormField).at(1), '0712345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'Zainab Hassan');
    await tester.ensureVisible(find.text('Send details'));
    await tester.tap(find.text('Send details'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not send your details. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Database connection'), findsNothing);
  });
}
