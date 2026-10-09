import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';

void main() {
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
