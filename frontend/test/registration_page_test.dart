import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_state.dart';

void main() {
  testWidgets('registration sends parent details without creating an account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? submitted;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/public/inquiries');
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': '1'},
        }),
        201,
      );
    });
    final state = AppState(
      MifApiClient(client: client, baseUrl: 'https://school.test'),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(MifApp(state: state));
    await tester.tap(find.text('Join the foundation'));
    await tester.pumpAndSettle();

    expect(find.text('A new chapter\nstarts here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Parent access'));
    await tester.tap(find.text('Parent access'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Amina Hassan');
    await tester.enterText(find.byType(TextFormField).at(1), '0712345678');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'amina@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'Zainab Hassan');
    await tester.ensureVisible(find.text('Send details'));
    await tester.tap(find.text('Send details'));
    await tester.pumpAndSettle();

    expect(submitted?['inquiryType'], 'PARENT_SUPPORT');
    expect(submitted?['sourcePage'], 'parent-access');
    expect(submitted?['message'], contains('Zainab Hassan'));
    expect(find.text('Your details are in.'), findsOneWidget);
    expect(
      find.textContaining('An account has not been opened yet'),
      findsOneWidget,
    );
  });
}
