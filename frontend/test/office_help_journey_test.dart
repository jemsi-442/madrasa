import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/office_help_page.dart';

void main() {
  for (final path in ['/contact', '/parent-access', '/forgot-password']) {
    testWidgets(
      '$path preserves failed inquiry and returns to the correct page',
      (tester) async {
        var attempts = 0;
        String? destination;
        final bodies = <Map<String, dynamic>>[];
        final api = MifApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/public/inquiries');
            expect(request.method, 'POST');
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            attempts++;
            return attempts == 1
                ? http.Response('{"message":"Unavailable"}', 503)
                : http.Response('{"data":{"id":"synthetic-inquiry"}}', 201);
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: OfficeHelpScreen(
              api: api,
              path: path,
              onNavigate: (route) => destination = route,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final back = path == '/contact' ? 'Back to Home' : 'Back to Login';
        await tester.ensureVisible(find.text(back));
        await tester.tap(find.text(back));
        expect(destination, path == '/contact' ? '/' : '/login');
        for (final entry in {
          'help-name': 'Demo Visitor',
          'help-phone': '0712345678',
          'help-email': 'visitor@example.test',
          'help-message': 'Please explain the onboarding process.',
        }.entries) {
          await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
        }
        await tester.ensureVisible(find.text('Send Message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send Message'));
        await tester.pumpAndSettle();
        expect(
          find.text('We could not send your message. Please try again later.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('help-message')))
              .controller!
              .text,
          'Please explain the onboarding process.',
        );
        await tester.ensureVisible(find.text('Send Message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send Message'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(bodies[0], bodies[1]);
        expect(bodies.last['sourcePage'], path.substring(1));
        expect(find.text('We Have Your Message'), findsOneWidget);
        destination = null;
        await tester.ensureVisible(find.text(back));
        await tester.tap(find.text(back));
        expect(destination, path == '/contact' ? '/' : '/login');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
