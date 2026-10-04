import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/learner_lesson_reader.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'learner_courses_test.dart' show CoursesFixture;
import 'lesson_media_test.dart' show response;

class RouteLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

class MediaFixture extends CoursesFixture {
  final events = <String>[];
  @override
  Future<dynamic> load(String path) async {
    if (path == '/api/learner/assets/33/open') {
      paths.add(path);
      return response(
        url: '/api/learner/assets/33/deliver?token=signed',
        kind: 'AUDIO',
      );
    }
    final result = await super.load(path);
    if (path == '/api/learner/lessons/22') {
      result['lesson']['assets'].add({
        ...asset('33', 'Listen and practise', 'OPEN', true),
        'assetType': 'AUDIO',
      });
    }
    return result;
  }

  Widget surface(
    LessonMediaDelivery source,
    VoidCallback ready,
    VoidCallback failed,
  ) => TrackedSurface(source: source, ready: ready, events: events);
}

class TrackedSurface extends StatefulWidget {
  const TrackedSurface({
    super.key,
    required this.source,
    required this.ready,
    required this.events,
  });
  final LessonMediaDelivery source;
  final VoidCallback ready;
  final List<String> events;
  @override
  State<TrackedSurface> createState() => _TrackedSurfaceState();
}

class _TrackedSurfaceState extends State<TrackedSurface> {
  @override
  void initState() {
    super.initState();
    widget.events.add('mount ${widget.source.kind}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.ready();
    });
  }

  @override
  void dispose() {
    widget.events.add('dispose ${widget.source.kind}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Test ${widget.source.kind} surface'));
}

Future<void> host(
  WidgetTester t,
  Widget child, {
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
      theme: adminTheme(ThemeData(fontFamily: 'NotoSansDisplay')),
      navigatorObservers: [if (observer != null) observer],
      home: child is LearnerLessonReader
          ? child
          : Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  testWidgets(
    'course and lesson use full pages, media opens inline without another route',
    (t) async {
      final f = MediaFixture(), routes = RouteLog();
      await host(t, f.page(builder: f.surface), observer: routes);
      await tap(t, find.text('View lessons').first);
      expect(find.byType(Dialog), findsNothing);
      await tap(t, find.text('Continue learning'));
      expect(find.byType(Dialog), findsNothing);
      expect(t.getSize(find.byType(Scaffold).last), const Size(1440, 900));
      final before = routes.pushed.length;
      await tap(t, find.byKey(const ValueKey('open-resource-30')));
      expect(routes.pushed.length, before);
      expect(routes.pushed.whereType<PopupRoute<dynamic>>(), isEmpty);
      expect(find.byType(LearnerLessonReader), findsOneWidget);
      expect(find.text('Test PDF surface'), findsOneWidget);
      expect(find.text('Lesson notes'), findsOneWidget);
      expect(f.writes, isEmpty);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Course curriculum'), findsOneWidget);
      expect(f.events.last, 'dispose PDF');
      await tap(t, find.byTooltip('Back to courses'));
      expect(find.text('View lessons'), findsWidgets);
    },
  );

  testWidgets(
    'changing resources disposes old playback; returning to text stops it',
    (t) async {
      final f = MediaFixture();
      await host(t, f.reader(builder: f.surface));
      await tap(t, find.byKey(const ValueKey('open-resource-30')));
      await tap(t, find.byKey(const ValueKey('open-resource-33')));
      expect(f.events, ['mount PDF', 'dispose PDF', 'mount AUDIO']);
      expect(find.byType(TrackedSurface), findsOneWidget);
      expect(find.text('Selected resource'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('return-to-lesson-text')));
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(f.events.last, 'dispose AUDIO');
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'desktop to phone reflow retains active surface and authorization',
    (t) async {
      final f = MediaFixture();
      await host(t, f.reader(builder: f.surface));
      await tap(t, find.byKey(const ValueKey('open-resource-33')));
      t.view.physicalSize = const Size(320, 740);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(f.events, ['mount AUDIO']);
      expect(f.paths.where((p) => p.endsWith('/33/open')).length, 1);
      t.view.physicalSize = const Size(1440, 900);
      await t.pumpAndSettle();
      expect(f.events, ['mount AUDIO']);
      expect(f.writes, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final kind in ['VIDEO', 'AUDIO', 'IMAGE', 'PDF', 'TEXT', 'EMBED']) {
    testWidgets('$kind inline lesson fits 320px and enlarged text', (t) async {
      final f = MediaFixture()..kind = kind;
      await host(t, f.reader(builder: f.surface), width: 320, scale: 2);
      await tap(t, find.byKey(const ValueKey('open-resource-30')));
      expect(find.text('Test $kind surface'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(t.takeException(), isNull);
      await tap(t, find.byKey(const ValueKey('return-to-lesson-text')));
      expect(f.events.last, 'dispose $kind');
      expect(f.writes, isEmpty);
    });
  }

  testWidgets(
    'late source authorization cannot replace a newly selected asset',
    (t) async {
      final pending = Completer<dynamic>();
      Future<dynamic> load(String path) => path.contains('/3/open')
          ? pending.future
          : Future.value(
              response(
                url: '/api/learner/assets/4/deliver?token=signed',
                kind: 'AUDIO',
              ),
            );
      Widget viewer(String id) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonMediaViewer(
              assetId: id,
              load: load,
              apiBaseUrl: 'https://school.test',
              surfaceBuilder: (source, ready, failed) =>
                  Text('Active ${source.kind}'),
            ),
          ),
        ),
      );
      await t.pumpWidget(viewer('3'));
      await t.pump();
      await t.pumpWidget(viewer('4'));
      await t.pumpAndSettle();
      expect(find.text('Active AUDIO'), findsOneWidget);
      pending.complete(response());
      await t.pumpAndSettle();
      expect(find.text('Active VIDEO'), findsNothing);
      expect(find.text('Active AUDIO'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'callbacks from disposed surface cannot change replacement status',
    (t) async {
      final callbacks = <(VoidCallback, VoidCallback)>[];
      await host(
        t,
        LessonMediaViewer(
          assetId: '3',
          load: (_) async => response(),
          apiBaseUrl: 'https://school.test',
          surfaceBuilder: (_, ready, failed) {
            callbacks.add((ready, failed));
            return const Text('Active player');
          },
        ),
      );
      final old = callbacks.first;
      await tap(t, find.text('Reload player'));
      callbacks.last.$1();
      await t.pumpAndSettle();
      old.$2();
      await t.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(find.textContaining('could not be displayed'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
