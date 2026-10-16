import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';
import 'package:mif_app/src/design_theme.dart';

void main() {
  testWidgets('capture office reference layout', (tester) async {
    tester.view.physicalSize = const Size(1536, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final fonts = FontLoader('Lato')
      ..addFont(rootBundle.load('assets/fonts/Lato-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Lato-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Lato-Semibold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Lato-Bold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAfaqTheme(),
        home: RepaintBoundary(
          key: key,
          child: PlatformWorkspaceShell(
            isAdmin: true,
            name: 'Demo Super Admin',
            page: PlatformPage.home,
            busy: false,
            actions: const [],
            onNavigate: (_) {},
            child: PlatformOverview(
              isAdmin: true,
              name: 'Demo Super Admin',
              snapshot: const {
                'checkedAt': '2026-10-15T12:00:00Z',
                'applications': {'REQUESTED': 0, 'APPROVED': 0, 'REJECTED': 0},
                'awaitingYourReview': 0,
                'onboarding': {'awaitingSetup': 0, 'pendingActivation': 0},
              },
              busy: false,
              error: null,
              onRefresh: () {},
              onNavigate: (_) {},
              onReviewPending: () {},
              onApproved: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_OFFICE')) {
      await tester.runAsync(() async {
        final picture =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/afaq-office-layout.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
}
