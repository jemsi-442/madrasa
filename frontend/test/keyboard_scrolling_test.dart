import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/accountant_components.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/keyboard_scrolling.dart';

void desktopTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(
    name,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}

void viewport(WidgetTester tester, {double height = 700}) {
  tester.view.physicalSize = Size(1440, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder get primaryView => find.byWidgetPredicate(
  (widget) =>
      (widget is ScrollView && widget.primary == true) ||
      (widget is SingleChildScrollView && widget.primary == true),
);

ScrollPosition position(WidgetTester tester, Finder view) => tester
    .state<ScrollableState>(
      find.descendant(of: view, matching: find.byType(Scrollable)).first,
    )
    .position;

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Widget harness(Widget child, {bool reducedMotion = false}) => MaterialApp(
  shortcuts: pageKeyboardShortcuts,
  actions: pageKeyboardActions,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  desktopTest('arrow steps respond quickly and page distance stays unchanged', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      harness(
        const SingleChildScrollView(
          primary: true,
          child: SizedBox(height: 4000),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = position(tester, primaryView);
    final context = tester.element(find.byType(Scaffold));
    Actions.invoke(context, const ScrollIntent(direction: AxisDirection.down));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scroll.pixels, greaterThan(70));
    await tester.pump(const Duration(milliseconds: 40));
    expect(scroll.pixels, closeTo(100, 0.1));
    await tester.pumpAndSettle();
    Actions.invoke(
      context,
      const ScrollIntent(
        direction: AxisDirection.down,
        type: ScrollIncrementType.page,
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.pixels, closeTo(100 + scroll.viewportDimension * 0.8, 0.1));
  });

  desktopTest('held arrows keep moving and reverse without a slow restart', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      harness(
        const SingleChildScrollView(
          primary: true,
          child: SizedBox(height: 4000),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = position(tester, primaryView);
    final context = tester.element(find.byType(Scaffold));
    for (var i = 0; i < 12; i++) {
      if (kIsWeb) {
        if (i == 0) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        } else {
          await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        }
      } else {
        Actions.invoke(
          context,
          const ScrollIntent(direction: AxisDirection.down),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
    }
    if (kIsWeb) await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    expect(scroll.pixels, greaterThan(700));
    final beforeReverse = scroll.pixels;
    Actions.invoke(context, const ScrollIntent(direction: AxisDirection.up));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 33));
    expect(scroll.pixels, lessThan(beforeReverse - 70));
    await tester.pumpAndSettle();
    final settled = scroll.pixels;
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroll.pixels, settled);
  });

  desktopTest('fast arrow steps respect reduced motion and both boundaries', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      harness(
        const SingleChildScrollView(
          primary: true,
          child: SizedBox(height: 4000),
        ),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    final scroll = position(tester, primaryView);
    final context = tester.element(find.byType(Scaffold));
    Actions.invoke(context, const ScrollIntent(direction: AxisDirection.down));
    expect(scroll.pixels, 100);
    scroll.jumpTo(scroll.maxScrollExtent - 20);
    Actions.invoke(context, const ScrollIntent(direction: AxisDirection.down));
    expect(scroll.pixels, scroll.maxScrollExtent);
    scroll.jumpTo(20);
    Actions.invoke(context, const ScrollIntent(direction: AxisDirection.up));
    expect(scroll.pixels, 0);
    await tester.pumpAndSettle();
  });

  desktopTest('dropdown keys stay in the menu and do not scroll the page', (
    tester,
  ) async {
    viewport(tester);
    String value = 'One';
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (context, update) => SingleChildScrollView(
            primary: true,
            child: Column(
              children: [
                DropdownButton<String>(
                  value: value,
                  items: ['One', 'Two', 'Three']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (next) => update(() => value = next!),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final background = position(tester, primaryView);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    expect(value, 'Two');
    expect(background.pixels, 0);
  });

  desktopTest('narrow website drawer scrolls independently of the page', (
    tester,
  ) async {
    viewport(tester, height: 440);
    tester.view.physicalSize = const Size(700, 440);
    final state =
        AppState(
            MifApiClient(
              browserAuth: false,
              client: MockClient(
                (_) async => http.Response(
                  jsonEncode({'data': <String, dynamic>{}}),
                  200,
                ),
              ),
            ),
          )
          ..session = const AuthSession(
            accessToken: 'test',
            refreshToken: 'test',
            userId: '1',
            fullName: 'Finance User',
            role: 'ACCOUNTANT',
          );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.website));
    await tester.pumpAndSettle();
    final background = position(tester, primaryView);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final drawer = position(
      tester,
      find.descendant(of: find.byType(Drawer), matching: find.byType(ListView)),
    );
    expect(drawer.maxScrollExtent, greaterThan(0));
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(drawer.pixels, greaterThan(0));
    expect(background.pixels, 0);
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(background.pixels, greaterThan(0));
  });

  desktopTest(
    'public home scrolls immediately with arrows, pages, space and boundaries',
    (tester) async {
      viewport(tester);
      final state = AppState(
        MifApiClient(
          browserAuth: false,
          client: MockClient((_) async => http.Response('{}', 404)),
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.website));
      await tester.pumpAndSettle();
      final scroll = position(tester, primaryView);
      expect(scroll.pixels, 0);
      if (kIsWeb) {
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(scroll.pixels, greaterThan(0));
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(scroll.pixels, 0);
      }
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(scroll.pixels, greaterThan(100));
      await press(tester, LogicalKeyboardKey.pageUp);
      expect(scroll.pixels, 0);
      await press(tester, LogicalKeyboardKey.space);
      expect(scroll.pixels, greaterThan(100));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await press(tester, LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(scroll.pixels, 0);
      await press(tester, LogicalKeyboardKey.end);
      expect(scroll.pixels, scroll.maxScrollExtent);
      await press(tester, LogicalKeyboardKey.home);
      expect(scroll.pixels, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await press(tester, LogicalKeyboardKey.end);
      expect(scroll.pixels, scroll.maxScrollExtent);
      await press(tester, LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(scroll.pixels, 0);
    },
  );

  for (final route in [
    '/login',
    '/register',
    '/contact',
    '/privacy',
    '/terms',
  ]) {
    desktopTest('$route has a single main keyboard scroll target', (
      tester,
    ) async {
      viewport(tester, height: 440);
      final state = AppState(
        MifApiClient(
          browserAuth: false,
          client: MockClient((_) async => http.Response('{}', 404)),
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.website));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
      await tester.pumpAndSettle();
      expect(primaryView, findsOneWidget);
      final scroll = position(tester, primaryView);
      expect(scroll.maxScrollExtent, greaterThan(0));
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(scroll.pixels, greaterThan(0));
      await press(tester, LogicalKeyboardKey.home);
      expect(scroll.pixels, 0);
      final controller = PrimaryScrollController.of(
        tester.element(primaryView),
      );
      expect(controller.positions.length, 1);
    });
  }

  for (final role in ['ADMIN', 'ACCOUNTANT', 'TEACHER', 'PARENT', 'LEARNER']) {
    desktopTest('$role workspace scrolls without first focusing its content', (
      tester,
    ) async {
      viewport(tester, height: 380);
      final state =
          AppState(
              MifApiClient(
                browserAuth: false,
                client: MockClient(
                  (_) async => http.Response(
                    jsonEncode({'message': 'Test error state'}),
                    500,
                  ),
                ),
              ),
            )
            ..session = AuthSession(
              accessToken: 'test',
              refreshToken: 'test',
              userId: '1',
              fullName: 'Test User',
              role: role,
            );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.website));
      await tester.pumpAndSettle();
      final scroll = position(tester, primaryView);
      expect(
        PrimaryScrollController.of(
          tester.element(primaryView),
        ).positions.length,
        1,
      );
      expect(scroll.maxScrollExtent, greaterThan(0));
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(scroll.pixels, greaterThan(0));
      await press(tester, LogicalKeyboardKey.home);
      expect(scroll.pixels, 0);
    });
  }

  desktopTest(
    'sidebar page change returns keyboard scrolling to main content',
    (tester) async {
      viewport(tester, height: 440);
      final state =
          AppState(
              MifApiClient(
                browserAuth: false,
                client: MockClient(
                  (_) async => http.Response(
                    jsonEncode({'data': <String, dynamic>{}}),
                    200,
                  ),
                ),
              ),
            )
            ..session = const AuthSession(
              accessToken: 'test',
              refreshToken: 'test',
              userId: '1',
              fullName: 'Finance User',
              role: 'ACCOUNTANT',
            );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.website));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      final main = position(tester, primaryView);
      final sidebar = position(tester, find.byType(ListView).first);
      final sidebarOffset = sidebar.pixels;
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(main.pixels, greaterThan(0));
      expect(sidebar.pixels, sidebarOffset);
    },
  );

  desktopTest('focused horizontal content preserves both scroll axes', (
    tester,
  ) async {
    viewport(tester);
    final focus = FocusNode();
    final horizontal = ScrollController();
    addTearDown(focus.dispose);
    addTearDown(horizontal.dispose);
    await tester.pumpWidget(
      harness(
        SingleChildScrollView(
          primary: true,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 2500,
                  height: 150,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      focusNode: focus,
                      onPressed: () {},
                      child: const Text('Table action'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();
    if (kIsWeb) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    } else {
      // Native desktop arrows navigate focus; web arrows scroll.
      Actions.invoke(
        focus.context!,
        const ScrollIntent(direction: AxisDirection.right),
      );
      await tester.pumpAndSettle();
    }
    expect(horizontal.offset, greaterThan(0));
    final x = horizontal.offset;
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(position(tester, primaryView).pixels, greaterThan(0));
    expect(horizontal.offset, x);
  });

  desktopTest('text editing and button activation keep their own keys', (
    tester,
  ) async {
    viewport(tester);
    final text = TextEditingController(text: 'Example text');
    final button = FocusNode();
    addTearDown(text.dispose);
    addTearDown(button.dispose);
    var clicks = 0;
    await tester.pumpWidget(
      harness(
        SingleChildScrollView(
          primary: true,
          child: Column(
            children: [
              TextField(controller: text),
              TextButton(
                focusNode: button,
                onPressed: () => clicks++,
                child: const Text('Activate'),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.home);
    expect(text.selection.baseOffset, 0);
    await press(tester, LogicalKeyboardKey.end);
    expect(text.selection.baseOffset, text.text.length);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    // On web, the DOM input handles arrow movement, not synthetic Flutter keys.
    if (!kIsWeb) expect(text.selection.baseOffset, text.text.length - 1);
    await press(tester, LogicalKeyboardKey.space);
    expect(position(tester, primaryView).pixels, 0);
    await press(tester, LogicalKeyboardKey.tab);
    expect(button.hasFocus, isTrue);
    await press(tester, LogicalKeyboardKey.space);
    expect(clicks, 1);
    expect(position(tester, primaryView).pixels, 0);
  });

  desktopTest('dialog keys scroll the dialog and not the page behind it', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => SingleChildScrollView(
            key: const ValueKey('background-scroll'),
            primary: true,
            child: Column(
              children: [
                TextButton(
                  onPressed: () => showFinanceDetail(
                    context,
                    title: 'Details',
                    child: const SizedBox(
                      height: 1600,
                      child: Text('Long detail'),
                    ),
                  ),
                  child: const Text('Open detail'),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final background = position(tester, primaryView);
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    final dialogView = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(SingleChildScrollView),
    );
    final dialog = position(tester, dialogView);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(dialog.pixels, greaterThan(0));
    expect(background.pixels, 0);
    await press(tester, LogicalKeyboardKey.end);
    expect(dialog.pixels, dialog.maxScrollExtent);
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(background.pixels, greaterThan(0));
  });

  desktopTest(
    'keyboard motion respects reduced motion and clamps at boundaries',
    (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        harness(
          const SingleChildScrollView(
            primary: true,
            child: SizedBox(height: 2000),
          ),
          reducedMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      final scroll = position(tester, primaryView);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(scroll.pixels, scroll.maxScrollExtent);
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(scroll.pixels, scroll.maxScrollExtent);
      await press(tester, LogicalKeyboardKey.home);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(scroll.pixels, 0);
    },
  );
}
