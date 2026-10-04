import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/learner_courses_page.dart';
import 'package:mif_app/src/lesson_document_surface.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'package:mif_app/src/media_player_preview.dart';
import 'package:mif_app/src/media_player_samples.dart';
import 'lesson_media_flow_test.dart' show MediaFixture, RouteLog, tap;
import 'lesson_media_test.dart' show response;
import 'workspace_flow_test.dart' show roles, showWorkspace;

Future<void> previewHost(
  WidgetTester t, {
  LessonMediaBuilder? builder,
  double width = 1440,
  double scale = 1,
  RouteLog? observer,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    MaterialApp(
      theme: adminTheme(ThemeData()),
      navigatorObservers: [if (observer != null) observer],
      home: Scaffold(body: MediaPlayerPreviewButton(surfaceBuilder: builder)),
    ),
  );
  await tap(t, find.text('Try media player'));
}

void main() {
  // Direct asset I/O hangs in the Chrome widget-test harness. Verify real
  // browser asset loading against the release preview instead.
  testWidgets(
    'all sample assets exist and are local, not signed school media',
    (t) async {
      for (final sample in MediaPlayerSample.values) {
        final bytes = await rootBundle.load(sample.assetPath);
        expect(bytes.lengthInBytes, greaterThan(0));
        expect(sample.delivery.assetPath, sample.assetPath);
        expect(sample.delivery.uri.scheme, 'asset');
        expect(sample.delivery.expiresAt, isNull);
        expect(sample.delivery.downloadAllowed, isFalse);
      }
    },
    skip: kIsWeb,
  );

  test('API parser cannot opt into bundled assets or bypass expiry', () {
    final raw = response();
    (raw['delivery'] as Map)['assetPath'] = MediaPlayerSample.video.assetPath;
    (raw['asset'] as Map)['assetPath'] = MediaPlayerSample.video.assetPath;
    final delivery = LessonMediaDelivery.parse(
      raw,
      apiBaseUrl: 'https://school.test',
      assetId: '3',
    );
    expect(delivery.assetPath, isNull);
    for (final uri in [
      'asset:assets/media-preview/video.mp4',
      '/assets/assets/media-preview/video.mp4',
    ]) {
      expect(
        () => LessonMediaDelivery.parse(
          response(url: uri),
          apiBaseUrl: 'https://school.test',
          assetId: '3',
        ),
        throwsFormatException,
      );
    }
    expect(
      () => LessonMediaDelivery.parse(
        response(expiry: DateTime(2000)),
        apiBaseUrl: 'https://school.test',
        assetId: '3',
      ),
      throwsFormatException,
    );
  });

  for (final width in [320.0, 1440.0]) {
    testWidgets('all sample choices fit width $width and large text', (
      t,
    ) async {
      final f = MediaFixture();
      final observer = RouteLog();
      await previewHost(
        t,
        builder: f.surface,
        width: width,
        scale: 2,
        observer: observer,
      );
      expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final routes = observer.pushed.length;
      for (final sample in MediaPlayerSample.values) {
        await tap(t, find.byKey(ValueKey('preview-${sample.name}')));
        expect(find.text('Test ${sample.kind} surface'), findsOneWidget);
        expect(find.text('Sample ${sample.index + 1} of 5'), findsOneWidget);
        expect(find.text('Mark complete'), findsNothing);
        expect(find.byType(LessonMediaViewer), findsOneWidget);
      }
      expect(observer.pushed.length, routes);
      expect(f.paths, isEmpty);
      expect(f.writes, isEmpty);
      expect(f.events.where((event) => event.startsWith('dispose')).length, 4);
      await tap(t, find.byTooltip('Back to workspace'));
      expect(find.text('Try media player'), findsOneWidget);
      expect(f.events.last, 'dispose TEXT');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('sample sequencing, reloading and focus reuse the real viewer', (
    t,
  ) async {
    final f = MediaFixture();
    await previewHost(t, builder: f.surface);
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('previous-resource')),
          )
          .onPressed,
      isNull,
    );
    await tap(t, find.byKey(const ValueKey('media-focus-view')));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
    expect(f.events, ['mount VIDEO']);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(f.events, ['mount VIDEO']);
    await tap(t, find.text('Reload player'));
    expect(f.events.where((e) => e == 'mount VIDEO').length, 2);
    expect(f.events.where((e) => e == 'dispose VIDEO').length, 1);
    for (var i = 0; i < 4; i++) {
      await tap(t, find.byKey(const ValueKey('next-resource')));
    }
    expect(find.text('Sample 5 of 5'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(find.byKey(const ValueKey('next-resource')))
          .onPressed,
      isNull,
    );
    await tap(t, find.byKey(const ValueKey('previous-resource')));
    expect(find.text('Sample 4 of 5'), findsOneWidget);
    expect(f.paths, isEmpty);
    expect(f.writes, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('native Back exits focus first, then closes the sample page', (
    t,
  ) async {
    final f = MediaFixture();
    await previewHost(t, builder: f.surface, width: 390);
    await tap(t, find.byKey(const ValueKey('media-focus-view')));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(MediaPlayerPreviewPage), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(f.events, ['mount VIDEO']);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(MediaPlayerPreviewPage), findsNothing);
    expect(f.events.last, 'dispose VIDEO');
  });

  testWidgets(
    'a failed sample can be reloaded or replaced without a school request',
    (t) async {
      final f = MediaFixture();
      var fail = true;
      await previewHost(
        t,
        builder: (source, ready, failed) =>
            f.surface(source, fail ? failed : ready, failed),
      );
      expect(
        find.textContaining('This sample could not be displayed'),
        findsOneWidget,
      );
      fail = false;
      await tap(t, find.text('Reload player'));
      expect(find.text('Ready'), findsOneWidget);
      expect(
        find.textContaining('This sample could not be displayed'),
        findsNothing,
      );
      await tap(t, find.byKey(const ValueKey('preview-text')));
      expect(find.text('Sample 5 of 5'), findsOneWidget);
      expect(f.paths, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('text sample uses the bundled document surface without HTTP', (
    t,
  ) async {
    var ready = false, failed = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonDocumentSurface(
            delivery: MediaPlayerSample.text.delivery,
            onReady: () => ready = true,
            onError: () => failed = true,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('PLAYER PREVIEW'), findsOneWidget);
    expect(ready, isTrue);
    expect(failed, isFalse);
  }, skip: kIsWeb);

  for (final fail in [false, true]) {
    testWidgets(
      'catalogue preview remains accessible without courses, failed=$fail',
      (t) async {
        final f = MediaFixture();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LearnerCoursesPage(
                  load: (_) async {
                    if (fail) throw StateError('School offline');
                    return [];
                  },
                  submit: f.submit,
                  apiBaseUrl: 'https://school.test',
                  surfaceBuilder: f.surface,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await tap(t, find.text('Try media player'));
        expect(find.text('Test VIDEO surface'), findsOneWidget);
        expect(f.paths, isEmpty);
        expect(f.writes, isEmpty);
        await tap(t, find.byTooltip('Back to workspace'));
        expect(find.byType(LearnerCoursesPage), findsOneWidget);
      },
    );
  }

  for (final role in roles) {
    for (final mobile in [false, true]) {
      testWidgets(
        '$role account menu opens preview without signing out, mobile=$mobile',
        (t) async {
          final state = await showWorkspace(
            t,
            role,
            mobile: mobile,
            width: mobile ? 390 : 1440,
          );
          await tap(t, find.byTooltip('Account menu'));
          expect(find.text('Sign out'), findsOneWidget);
          await tap(t, find.text('Try media player'));
          expect(find.byType(MediaPlayerPreviewPage), findsOneWidget);
          expect(state.session?.role, role);
          await tap(t, find.byTooltip('Back to workspace'));
          expect(find.byType(MediaPlayerPreviewPage), findsNothing);
          expect(state.session?.role, role);
          await t.pumpWidget(const SizedBox());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
    }
  }
}
