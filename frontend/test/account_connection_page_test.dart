import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/account_connection_page.dart';
import 'package:mif_app/src/design_theme.dart';

void main() {
  Widget screen({
    bool restoring = true,
    bool reducedMotion = false,
    double scale = 1,
    VoidCallback? retry,
    VoidCallback? signOut,
  }) => MaterialApp(
    theme: buildAfaqTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(scale),
      ),
      child: AccountConnectionPage(
        restoring: restoring,
        error: restoring
            ? null
            : 'We could not reconnect to your account. Please try again.',
        onRetry: retry ?? () {},
        onSignOut: signOut ?? () {},
      ),
    ),
  );

  testWidgets(
    'slow connection explains waiting without retrying automatically',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(screen(retry: () => retries++));
      expect(
        find.text('Checking your saved session securely.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      expect(find.textContaining('longer than usual'), findsOneWidget);
      expect(retries, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failure provides deliberate actions and retry resets the slow state',
    (tester) async {
      var retries = 0;
      var signOuts = 0;
      await tester.pumpWidget(screen());
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(
        screen(
          restoring: false,
          retry: () => retries++,
          signOut: () => signOuts++,
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Sign out'));
      expect(retries, 1);
      expect(signOuts, 1);
      await tester.pumpWidget(screen());
      expect(
        find.text('Checking your saved session securely.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'small screens and enlarged text remain scrollable with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen(scale: 2, reducedMotion: true));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(screen(restoring: false, scale: 2));
      await tester.ensureVisible(find.text('Sign out'));
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
