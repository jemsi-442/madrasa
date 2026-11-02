import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_page.dart';
import 'package:mif_app/src/home_story_sections.dart';

const _featureTitles = [
  "Qur'an Tracking",
  'Student Management',
  'Progress Reports',
  'Community Support',
];

Widget _featuresAtWidth(double width) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: const SingleChildScrollView(child: PublicHomeFeatures()),
      ),
    ),
  ),
);

void main() {
  testWidgets('tablet hero stacks matching readable columns', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();
    final photo = tester.getRect(find.byKey(const ValueKey('home-hero-photo')));
    final headline = tester.getRect(
      find.text('Knowledge that\nshapes brighter\ntomorrows.'),
    );
    final actions = tester.getRect(find.byKey(const ValueKey('hero-register')));
    expect(photo.width, 680);
    expect(photo.left, headline.left);
    expect(photo.top, greaterThan(actions.bottom));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'desktop hero gives the headline and original photo a larger stage',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('home-hero-primary'))).height,
        greaterThanOrEqualTo(840),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('home-hero-photo'))).width,
        greaterThanOrEqualTo(740),
      );
      expect(
        tester
            .widget<Text>(
              find.text('Knowledge that\nshapes brighter\ntomorrows.'),
            )
            .style!
            .fontSize,
        72,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop navigation exposes the selected section and heading structure',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
      );
      await tester.pumpAndSettle();
      Semantics nav(String label) =>
          tester.widget<Semantics>(find.byKey(ValueKey('home-nav-$label')));
      expect(nav('Home').properties.selected, isTrue);
      expect(nav('About').properties.selected, isFalse);
      final heroHeadings = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.text('Knowledge that\nshapes brighter\ntomorrows.'),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        heroHeadings.any((node) => node.properties.header == true),
        isTrue,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('home-nav-About')),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(nav('About').properties.selected, isTrue);
      expect(nav('Home').properties.selected, isFalse);
      final teamHeadings = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.text('The people behind Afaq.'),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        teamHeadings.any((node) => node.properties.header == true),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('phone hero actions have matching full-width touch targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destinations = <String>[];
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: destinations.add)),
    );
    await tester.pumpAndSettle();
    final register = find.byKey(const ValueKey('hero-register'));
    final explore = find.byKey(const ValueKey('hero-explore'));
    expect(tester.getSize(register), const Size(342, 58));
    expect(tester.getSize(explore), const Size(342, 58));
    await tester.ensureVisible(register);
    await tester.tap(register);
    expect(destinations, ['/register']);
    await tester.ensureVisible(explore);
    await tester.tap(explore);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-back-to-top')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('feature descriptions align when headings wrap on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_featuresAtWidth(960));
    await tester.pumpAndSettle();
    final tops = [
      'Follow memorization and recitation',
      'Organize and support every learner',
      'See growth and celebrate progress',
      'Connect families and teachers',
    ].map((text) => tester.getTopLeft(find.text(text)).dy).toList();
    expect(tops.every((top) => (top - tops.first).abs() < 1), isTrue);
    final colors = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byType(PublicHomeFeatures),
            matching: find.byType(Icon),
          ),
        )
        .map((icon) => icon.color)
        .toSet();
    expect(colors.length, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets('homepage feature icons and copy use larger readable sizes', (
    tester,
  ) async {
    await tester.pumpWidget(_featuresAtWidth(700));
    await tester.pumpAndSettle();
    for (final title in _featureTitles) {
      expect(tester.widget<Text>(find.text(title)).style!.fontSize, 22);
    }
    expect(
      tester
          .widget<Text>(find.text('Follow memorization and recitation'))
          .style!
          .fontSize,
      18,
    );
    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(PublicHomeFeatures),
        matching: find.byType(Icon),
      ),
    );
    expect(icons.length, 4);
    expect(icons.every((icon) => icon.size == 48), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('homepage restores scroll position and shows desktop scrollbar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bucket = PageStorageBucket();
    Widget page(bool showHome) => MaterialApp(
      home: PageStorage(
        bucket: bucket,
        child: showHome
            ? PublicHomeScreen(onNavigate: (_) {})
            : const SizedBox(),
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    final scroll = find.byKey(const PageStorageKey('public-home-scroll'));
    final controller = tester.widget<SingleChildScrollView>(scroll).controller!;
    final bar = find
        .ancestor(of: scroll, matching: find.byType(Scrollbar))
        .first;
    expect(tester.widget<Scrollbar>(bar).thumbVisibility, isTrue);
    await Scrollable.ensureVisible(
      tester.element(find.byType(HomeTeamSection)),
    );
    await tester.pumpAndSettle();
    final offset = controller.offset;
    expect(offset, greaterThan(700));
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    final restored = tester.widget<SingleChildScrollView>(scroll).controller!;
    expect(restored.offset, closeTo(offset, 1));
    expect(find.byKey(const ValueKey('home-back-to-top')), findsOneWidget);
    await tester.tap(find.byTooltip('More homepage sections'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<String>>(
            find.widgetWithText(CheckedPopupMenuItem<String>, 'Our team'),
          )
          .checked,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu follows scrolling without a navigation click', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byType(HomeSchoolSection)),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final item = find.widgetWithText(
      CheckedPopupMenuItem<String>,
      'For Schools',
    );
    expect(tester.widget<CheckedPopupMenuItem<String>>(item).checked, isTrue);
    final home = find.widgetWithText(CheckedPopupMenuItem<String>, 'Home');
    expect(tester.widget<CheckedPopupMenuItem<String>>(home).checked, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final width in [700.0, 900.0, 1440.0]) {
    testWidgets('school cards have comfortable columns at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeSchoolSection(onNavigate: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Rect card(String title) => tester.getRect(
        find
            .ancestor(of: find.text(title), matching: find.byType(Container))
            .first,
      );
      final plan = card('Give lessons a clear direction');
      final teach = card('Keep records with context');
      final support = card('Turn records into follow-up');
      expect(plan.top, teach.top);
      expect(plan.height, teach.height);
      expect(plan.width, greaterThan(300));
      if (width < 1100) {
        expect(support.top, greaterThan(plan.bottom));
      } else {
        expect(support.top, plan.top);
        expect(support.height, plan.height);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1440.0]) {
    testWidgets('expanded homepage content and actions at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = <String>[];
      await tester.pumpWidget(
        MaterialApp(home: PublicHomeScreen(onNavigate: routes.add)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeStorySections), findsOneWidget);
      expect(find.byKey(const ValueKey('home-back-to-top')), findsNothing);
      final photo = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('home-hero-photo')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (photo.image as AssetImage).assetName,
        'assets/home/shared-learning.jpg',
      );
      expect(photo.fit, BoxFit.contain);
      expect(find.text('OUR STORY'), findsOneWidget);
      expect(find.text('PARTNER WITH AFAQ'), findsOneWidget);
      if (width >= 1150) {
        await tester.tap(find.text('For Schools').first);
        await tester.pumpAndSettle();
        final schoolTop = tester
            .getTopLeft(find.text('FOR SCHOOLS & MADRASAS'))
            .dy;
        expect(schoolTop, greaterThanOrEqualTo(0));
        expect(schoolTop, lessThan(400));
        await tester.tap(find.byTooltip('More homepage sections'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, 'Partners'),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('PARTNER WITH AFAQ')).dy,
          inInclusiveRange(0, 400),
        );
      }
      await tester.ensureVisible(find.text('Discuss your madrasa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discuss your madrasa'));
      expect(routes, ['/contact']);
      await tester.ensureVisible(find.text('What is Afaq?'));
      await tester.tap(find.text('What is Afaq?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The digital platform supports this wider'),
        findsOneWidget,
      );
      for (final (key, route) in [
        ('home-contact-next-step', '/contact'),
        ('home-sign-in-next-step', '/login'),
      ]) {
        final action = find.byKey(ValueKey(key));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        expect(routes.last, route);
      }
      await tester.tap(find.byTooltip('Back to top'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-back-to-top')), findsNothing);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      expect(scroll.controller!.offset, closeTo(0, 1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('homepage shortcuts reach their sections on a phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();
    for (final (label, heading) in [
      ('Our story', 'OUR STORY'),
      ('Learning in practice', 'LEARNING IN PRACTICE'),
      ('Partners', 'PARTNER WITH AFAQ'),
      ('FAQs', 'QUESTIONS & ANSWERS'),
    ]) {
      final shortcut = find.widgetWithText(OutlinedButton, label);
      await tester.ensureVisible(shortcut);
      await tester.pumpAndSettle();
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text(heading)).dy;
      expect(top, inInclusiveRange(0, 400), reason: label);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final schoolMenu = find.widgetWithText(
      CheckedPopupMenuItem<String>,
      'For Schools',
    );
    await tester.ensureVisible(schoolMenu);
    await tester.pumpAndSettle();
    await tester.tap(schoolMenu);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('FOR SCHOOLS & MADRASAS')).dy,
      inInclusiveRange(0, 400),
    );
  });

  testWidgets('expanded content supports large text on a narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const HomeStorySections(),
                HomeSchoolSection(onNavigate: (_) {}),
                HomePartnershipSection(onNavigate: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('What is Afaq?'));
    await tester.tap(find.text('What is Afaq?'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final width in [0.0, 1.0, 10.0, 19.0, 20.0, 54.0, 120.0]) {
    testWidgets('home features tolerate a transient width of $width', (
      tester,
    ) async {
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.getSize(find.byType(PublicHomeFeatures)).width, width);
    });
  }

  for (final (width, columns) in [
    (240.0, 1),
    (260.0, 1),
    (272.0, 1),
    (342.0, 1),
    (479.0, 1),
    (480.0, 2),
    (599.0, 2),
    (600.0, 2),
    (790.0, 2),
    (959.0, 2),
    (960.0, 4),
  ]) {
    testWidgets('home features use $columns columns at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull);
      final tops = _featureTitles
          .map((title) => tester.getTopLeft(find.text(title)))
          .toList();
      for (var i = 0; i < tops.length; i++) {
        expect(tops[i].dy, tops[(i ~/ columns) * columns].dy);
        if (i % columns == 0 && i > 0) {
          expect(tops[i].dy, greaterThan(tops[i - 1].dy));
        }
        final rect = tester.getRect(find.text(_featureTitles[i]));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
    });
  }

  testWidgets('home features recover after their width collapses to zero', (
    tester,
  ) async {
    for (final width in [342.0, 0.0, 10.0, 342.0, 790.0, 0.0, 272.0]) {
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull, reason: 'width: $width');
      expect(find.byType(ErrorWidget), findsNothing);
      if (width >= 272) {
        for (final title in _featureTitles) {
          expect(find.text(title), findsOneWidget);
        }
      }
    }
  });

  testWidgets('feature columns respond to accessibility text size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (scale, columns) in [(1.0, 4), (2.0, 2), (3.0, 1)]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: PublicHomeFeatures()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text(_featureTitles.first)).dy;
      for (var i = 1; i < _featureTitles.length; i++) {
        final top = tester.getTopLeft(find.text(_featureTitles[i])).dy;
        expect(top, i < columns ? equals(first) : greaterThan(first));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('phone menu links directly to FAQ and marks selected section', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final faq = find.widgetWithText(CheckedPopupMenuItem<String>, 'FAQs');
    await tester.ensureVisible(faq);
    await tester.pumpAndSettle();
    await tester.tap(faq);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('QUESTIONS & ANSWERS')).dy,
      inInclusiveRange(0, 400),
    );
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckedPopupMenuItem<String>>(faq).checked, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home remains usable through phone and desktop resizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final navigation = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: navigation.add)),
    );

    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(320, 640),
      const Size(768, 1024),
      const Size(1440, 900),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      for (final title in _featureTitles) {
        expect(find.text(title), findsOneWidget);
      }
    }

    await tester.ensureVisible(find.text("Qur'an Tracking"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('header-login')));
    expect(navigation, ['/login']);
    expect(tester.takeException(), isNull);
  });
}
