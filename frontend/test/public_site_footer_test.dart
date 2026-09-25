import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/office_help_page.dart';
import 'package:mif_app/src/public_information_page.dart';
import 'package:mif_app/src/public_shell.dart';
import 'package:mif_app/src/public_site_footer.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('footer links and divider work at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final launches = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            launches.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(const MifApp());

      expect(find.text('Get in Touch'), findsNothing);
      expect(find.byIcon(Icons.telegram), findsNothing);
      final instagram = tester.widget<IconButton>(
        find.byKey(const ValueKey('footer-instagram')),
      );
      expect(instagram.onPressed, isNull);
      expect(instagram.tooltip, 'Instagram link coming soon');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon &&
              widget.icon == FontAwesomeIcons.instagram.data,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon && widget.icon == FontAwesomeIcons.whatsapp.data,
        ),
        findsNWidgets(2),
      );
      for (final phone in ['+255715735335', '+255683186987']) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == phone,
          ),
          findsOneWidget,
        );
        final contact = find.byKey(ValueKey('footer-whatsapp-$phone'));
        await tester.ensureVisible(contact);
        await tester.tap(contact);
        await tester.pumpAndSettle();
        expect(launches.last.method, 'launch');
        expect(
          launches.last.arguments['url'],
          'https://wa.me/${phone.substring(1)}',
        );
        expect(launches.last.arguments['useWebView'], isFalse);
        expect(launches.last.arguments['useSafariVC'], isFalse);
      }
      expect(launches, hasLength(2));

      final divider = find.byKey(const ValueKey('public-footer-divider'));
      await tester.ensureVisible(divider);
      await tester.pumpAndSettle();
      expect(tester.widget<Divider>(divider).thickness, 1);
      expect(tester.getSize(divider).width, size.width);
      expect(
        tester.getTopLeft(find.textContaining('All rights reserved.')).dy,
        greaterThan(tester.getBottomRight(divider).dy),
      );
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('public-footer')))
            .color,
        publicBrandBlue,
      );
      expect(tester.takeException(), isNull);

      for (final (path, title) in [
        ('/terms', 'Terms & Conditions'),
        ('/privacy', 'Privacy Policy'),
      ]) {
        final link = find.byKey(ValueKey('footer-link-$path'));
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(PublicInformationScreen), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Publication Pending'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
      }

      final support = find.byKey(const ValueKey('footer-link-/contact'));
      await tester.ensureVisible(support);
      await tester.tap(support);
      await tester.pumpAndSettle();
      expect(find.byType(OfficeHelpScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('public-footer-divider')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final throwsError in [false, true]) {
    testWidgets('WhatsApp launch failure has a useful fallback ($throwsError)', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            if (throwsError) {
              throw PlatformException(code: 'unavailable');
            }
            return false;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicSiteFooter(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      final contact = find.byKey(
        const ValueKey('footer-whatsapp-+255715735335'),
      );
      await tester.ensureVisible(contact);
      await tester.tap(contact);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not open WhatsApp. Copy +255715735335 and contact us directly.',
        ),
        findsOneWidget,
      );
      expect(find.text('+255715735335'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
