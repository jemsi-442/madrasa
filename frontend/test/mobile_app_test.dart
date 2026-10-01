import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/home_page.dart';
import 'package:mif_app/src/mobile_welcome_page.dart';
import 'package:mif_app/src/workspace.dart';

AppState _state({Future<http.Response> Function(http.Request)? handler}) =>
    AppState(
      MifApiClient(
        baseUrl: 'https://school.test',
        browserAuth: false,
        client: MockClient(
          handler ?? (_) async => http.Response('{"data":{}}', 200),
        ),
      ),
    );

http.Response _session(String role) => http.Response(
  jsonEncode({
    'data': {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'user': {'id': '12', 'fullName': 'Amina Hassan', 'role': role},
    },
  }),
  200,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _noWebsiteChrome() {
  expect(find.byKey(const ValueKey('public-header')), findsNothing);
  expect(find.byKey(const ValueKey('public-footer')), findsNothing);
  expect(find.byType(PublicHomeScreen), findsNothing);
  expect(find.textContaining('All rights reserved.'), findsNothing);
}

void main() {
  testWidgets(
    'native welcome survives zero-sized Android startup and rotation',
    (tester) async {
      _viewport(tester, Size.zero);
      final state = _state();
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
      for (final size in [
        Size.zero,
        const Size(390, 844),
        Size.zero,
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
      await _tap(tester, find.byKey(const ValueKey('mobile-login')));
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile entry supports large text on a small phone', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byKey(const ValueKey('mobile-login')));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Register here'));
    await tester.ensureVisible(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final platform in TargetPlatform.values) {
    test('browser on $platform keeps the website', () {
      expect(
        resolveAppLayout(isWeb: true, platform: platform),
        AppLayout.website,
      );
    });
    test('native $platform selects the appropriate entry', () {
      expect(
        resolveAppLayout(isWeb: false, platform: platform),
        [TargetPlatform.android, TargetPlatform.iOS].contains(platform)
            ? AppLayout.mobile
            : AppLayout.website,
      );
    });
  }

  testWidgets(
    'Android and iOS start with native welcome by default',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final state = _state();
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byType(MobileWelcomeScreen), findsOneWidget);
      _noWebsiteChrome();
      await _tap(tester, find.byKey(const ValueKey('mobile-login')));
      expect(find.byKey(const ValueKey('mobile-auth-frame')), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      _noWebsiteChrome();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('native welcome and account routes fit $size', (tester) async {
      _viewport(tester, size);
      final state = _state();
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _noWebsiteChrome();
      await _tap(tester, find.byKey(const ValueKey('mobile-register')));
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      _noWebsiteChrome();
      await _tap(tester, find.text("Looking for your child's account?"));
      expect(find.text('Parent access'), findsOneWidget);
      _noWebsiteChrome();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Create Your Account'), findsOneWidget);
      await _tap(tester, find.text('Login here'));
      expect(find.byType(TextFormField), findsNWidgets(2));
      _noWebsiteChrome();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('native help and privacy return to the prior screen', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final state = _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    for (final label in ['Help', 'Privacy', 'Terms']) {
      await _tap(tester, find.text(label));
      expect(find.byType(AppBar), findsOneWidget);
      _noWebsiteChrome();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MobileWelcomeScreen), findsOneWidget);
    }
    await _tap(tester, find.byKey(const ValueKey('mobile-login')));
    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      'amina@example.test',
    );
    await _tap(tester, find.text('Forgot password?'));
    expect(find.text('Sign-in help'), findsOneWidget);
    _noWebsiteChrome();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('amina@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile auth scrolls above keyboard and respects safe areas', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 640));
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    final state = _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    await _tap(tester, find.byKey(const ValueKey('mobile-register')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(submit).dy, lessThanOrEqualTo(360));
    expect(
      tester.getTopLeft(submit).dy,
      greaterThanOrEqualTo(tester.getBottomRight(find.byType(AppBar)).dy),
    );
    _noWebsiteChrome();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native login validates, handles errors, opens workspace and signs out',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      var attempts = 0;
      final paths = <String>[];
      final state = _state(
        handler: (request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/auth/login') {
            attempts++;
            if (attempts == 1) {
              return http.Response('{"message":"Invalid credentials"}', 401);
            }
            return _session('ACCOUNTANT');
          }
          return http.Response('{"data":{}}', 200);
        },
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
      await _tap(tester, find.byKey(const ValueKey('mobile-login')));
      await _tap(tester, find.widgetWithText(FilledButton, 'Login'));
      expect(attempts, 0);
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('login-identifier')),
        'amina@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Password123!',
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Login'));
      expect(
        find.text('The phone number or email and password do not match.'),
        findsOneWidget,
      );
      expect(state.session, isNull);
      await _tap(tester, find.widgetWithText(FilledButton, 'Login'));
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(state.session?.role, 'ACCOUNTANT');
      _noWebsiteChrome();
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Invoices'),
        ),
      );
      expect(paths, contains('/api/invoices'));
      await _tap(tester, find.byTooltip('Open navigation menu'));
      expect(find.byType(Drawer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      await _tap(tester, find.byTooltip('Account menu'));
      await _tap(tester, find.text('Sign out'));
      expect(find.byType(MobileWelcomeScreen), findsOneWidget);
      expect(find.byType(WorkspaceScreen), findsNothing);
      expect(state.session, isNull);
      expect(paths, contains('/api/auth/logout'));
      expect(
        paths.any((path) => path.startsWith('/api/auth/browser/')),
        isFalse,
      );
      _noWebsiteChrome();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native registration keeps learner-only permissions', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    Map<String, dynamic>? payload;
    final state = _state(
      handler: (request) async {
        if (request.url.path == '/api/auth/register') {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return _session('LEARNER');
        }
        return http.Response('{"data":{}}', 200);
      },
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    await _tap(tester, find.byKey(const ValueKey('mobile-register')));
    for (final (key, value) in [
      ('register-name', 'Amina Hassan'),
      ('register-email', 'amina@example.test'),
      ('register-password', 'Password123!'),
      ('register-confirmation', 'Password123!'),
    ]) {
      await tester.enterText(find.byKey(ValueKey(key)), value);
    }
    await _tap(tester, find.widgetWithText(FilledButton, 'Create Account'));
    expect(payload?['email'], 'amina@example.test');
    expect(payload?.containsKey('role'), isFalse);
    expect(state.session?.role, 'LEARNER');
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    _noWebsiteChrome();
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing session opens native workspace even on a wide tablet', (
    tester,
  ) async {
    _viewport(tester, const Size(1200, 900));
    final state = _state();
    state.session = const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: '12',
      fullName: 'Amina Hassan',
      role: 'ACCOUNTANT',
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    await tester.pumpAndSettle();
    expect(find.byType(MobileWelcomeScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    _noWebsiteChrome();
    expect(tester.takeException(), isNull);
  });
}
