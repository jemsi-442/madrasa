import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/page_selection.dart';

void main() {
  testWidgets('deep link selection waits for hidden routes to be laid out', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final updates = ValueNotifier(false);
    addTearDown(updates.dispose);
    Widget page(String name) => PageSelection(
      child: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: updates,
          builder: (_, updated, _) => Column(
            children: [
              Text('$name ${updated ? 'updated' : 'initial'}'),
              const TextField(),
              if (updated) const Text('New selectable content'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        initialRoute: '/login',
        routes: {'/': (_) => page('Home'), '/login': (_) => page('Login')},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    updates.value = true;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Keep my draft'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Home draft');
    navigator.currentState!.pushNamed('/login');
    await tester.pumpAndSettle();
    updates.value = false;
    await tester.pumpAndSettle();
    updates.value = true;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering a page preserves its form draft and field state', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const PageSelection(child: Scaffold(body: TextField())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Unsaved curriculum notes');
    final fieldState = tester.state(find.byType(EditableText));
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(title: Text('Details')),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditableText)), same(fieldState));
    expect(find.text('Unsaved curriculum notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page text supports mouse selection and keyboard copy',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(const MifApp(layout: AppLayout.website));
      await tester.pumpAndSettle();
      // On web, putting the native selection platform view above Navigator
      // intercepts page gestures even though simulated widget gestures pass.
      expect(
        find.ancestor(
          of: find.byType(Navigator).first,
          matching: find.byType(SelectionArea),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('header-login')));
      await tester.pumpAndSettle();
      final heading = find.text('Welcome Back');
      final rect = tester.getRect(heading);
      final mouse = await tester.startGesture(
        Offset(rect.left, rect.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveTo(Offset(rect.right, rect.center.dy));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(copied, contains('Welcome Back'));
      final password = find.byKey(const ValueKey('login-password'));
      await tester.enterText(password, 'private-password');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(copied, isNot(contains('private-password')));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'mobile page text offers a selection menu',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MifApp(layout: AppLayout.mobile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mobile-login')));
      await tester.pumpAndSettle();
      final heading = tester.getRect(find.text('Welcome Back'));
      await tester.longPressAt(Offset(heading.left + 30, heading.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
