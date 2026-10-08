import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/login_page.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('one login routes $role at $width and expiry returns to it', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <String>[];
        final client = MockClient((req) async {
          requests.add(req.url.path);
          dynamic data = [];
          if (req.url.path.endsWith('/auth/login')) {
            expect(jsonDecode(req.body), {
              'login': 'user@afaq.test',
              'password': 'password-only',
            });
            data = {
              'scope': 'platform',
              'accessToken': 'company-token',
              'expiresIn': 900,
              'user': {
                'id': 'company',
                'fullName': 'Company User',
                'role': role,
              },
            };
          } else if (req.url.path.startsWith('/api/platform/')) {
            expect(req.headers['Authorization'], 'Bearer company-token');
          }
          return http.Response(jsonEncode({'data': data}), 200);
        });
        final state = AppState(
          MifApiClient(client: client, browserAuth: false),
          companyApiFactory: () => PlatformApi(client: client),
        );
        await tester.pumpWidget(
          MifApp(state: state, layout: AppLayout.mobile),
        );
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/platform');
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Authenticator code'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('login-identifier')),
          'user@afaq.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'password-only',
        );
        await tester.ensureVisible(find.text('Login'));
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        expect(find.byType(PlatformConsole), findsOneWidget);
        expect(state.session, isNull);
        expect(state.companyApi!.user!['role'], role);
        expect(
          find.text('System health'),
          role == 'IT_SECURITY' ? findsOneWidget : findsNothing,
        );
        expect(
          requests.where((path) => path.endsWith('/platform/login')),
          isEmpty,
        );
        state.companyApi!.clear();
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Authenticator code'), findsNothing);
        expect(state.companyApi, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      });
    }
  }
  for (final role in ['ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT', 'LEARNER']) {
    test('school $role remains in school session scope', () async {
      final state = AppState(
        MifApiClient(
          browserAuth: false,
          client: MockClient(
            (req) async => http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'school-token',
                  'refreshToken': 'school-refresh',
                  'user': {'id': 1, 'fullName': 'School User', 'role': role},
                },
              }),
              200,
            ),
          ),
        ),
      );
      expect(await state.signIn('school@afaq.test', 'password-only'), isTrue);
      expect(state.session!.role, role);
      expect(state.companyApi, isNull);
      state.dispose();
    });
  }
}
