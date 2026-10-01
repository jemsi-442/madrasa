import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/registration_page.dart';
import 'package:mif_app/src/office_help_page.dart';

void main() {
  Future<void> fill(
    WidgetTester tester, {
    String confirmation = 'Learning123!',
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('register-name')),
      'Amina Hassan',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'amina@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'Learning123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirmation')),
      confirmation,
    );
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'registration creates a learner session without requesting a role',
    (tester) async {
      Map<String, dynamic>? submitted;
      var completed = false;
      final state = AppState(
        MifApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/auth/register');
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'access',
                  'refreshToken': 'refresh',
                  'user': {
                    'id': '10',
                    'fullName': 'Amina Hassan',
                    'role': 'LEARNER',
                  },
                },
              }),
              201,
            );
          }),
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            state: state,
            onNavigate: (_) {},
            onRegistered: () => completed = true,
          ),
        ),
      );
      await fill(tester);
      expect(submitted?['fullName'], 'Amina Hassan');
      expect(submitted?['confirmPassword'], 'Learning123!');
      expect(submitted?.containsKey('role'), isFalse);
      expect(state.session?.role, 'LEARNER');
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mismatched passwords stay on form without sending a request', (
    tester,
  ) async {
    var requests = 0;
    final state = AppState(
      MifApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(
          state: state,
          onNavigate: (_) {},
          onRegistered: () {},
        ),
      ),
    );
    await fill(tester, confirmation: 'SomethingElse!');
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(requests, 0);
  });

  for (final size in [
    const Size(320, 640),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('registration and parent help fit ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MifApp(layout: AppLayout.website));
      await tester.ensureVisible(find.byKey(const ValueKey('hero-register')));
      await tester.tap(find.byKey(const ValueKey('hero-register')));
      await tester.pumpAndSettle();
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(
          find.byKey(const ValueKey('register-password')),
        ),
        isNotNull,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);

      final parent = find.text("Looking for your child's account?");
      await tester.ensureVisible(parent);
      await tester.tap(parent);
      await tester.pumpAndSettle();
      expect(find.byType(OfficeHelpScreen), findsOneWidget);
      expect(find.text('Stay Close to Their Learning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'parent help submits an inquiry rather than creating an account',
    (tester) async {
      Map<String, dynamic>? submitted;
      final api = MifApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/public/inquiries');
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {'id': '1'},
            }),
            201,
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: OfficeHelpScreen(
            api: api,
            onNavigate: (_) {},
            path: '/parent-access',
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('help-name')),
        'Amina Hassan',
      );
      await tester.enterText(
        find.byKey(const ValueKey('help-phone')),
        '0712345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('help-message')),
        'Zainab Hassan',
      );
      await tester.ensureVisible(find.text('Send Message'));
      await tester.tap(find.text('Send Message'));
      await tester.pumpAndSettle();
      expect(submitted?['inquiryType'], 'PARENT_SUPPORT');
      expect(submitted?['sourcePage'], 'parent-access');
      expect(find.text('We Have Your Message'), findsOneWidget);
    },
  );
}
