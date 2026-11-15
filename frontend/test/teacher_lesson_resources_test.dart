import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'package:mif_app/src/teacher_lesson_resources.dart';

void main() {
  testWidgets('late assets cannot replace the newly selected lesson', (
    tester,
  ) async {
    final first = Completer<dynamic>();
    final second = Completer<dynamic>();
    Widget page(String lesson) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeacherLessonResources(
            lessonId: lesson,
            apiBaseUrl: 'https://school.test',
            load: (path) =>
                path.contains('/first/') ? first.future : second.future,
          ),
        ),
      ),
    );
    await tester.pumpWidget(page('first'));
    await tester.pumpWidget(page('second'));
    second.complete([
      {'id': 'new', 'title': 'Current lesson PDF', 'assetType': 'PDF'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Current lesson PDF'), findsOneWidget);
    first.complete([
      {'id': 'old', 'title': 'Previous lesson text', 'assetType': 'TEXT'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Current lesson PDF'), findsOneWidget);
    expect(find.text('Previous lesson text'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing resources during loading safely ignores late assets', (
    tester,
  ) async {
    final assets = Completer<dynamic>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonResources(
            lessonId: 'synthetic',
            apiBaseUrl: 'https://school.test',
            openFirst: true,
            load: (_) => assets.future,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Course catalogue'))),
    );
    assets.complete([
      {'id': 'old', 'title': 'Delayed PDF', 'assetType': 'PDF'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Course catalogue'), findsOneWidget);
    expect(find.byType(LessonMediaViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long resource names fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title =
        'Synthetic classroom practice checklist and supporting lesson notes';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: TeacherLessonResources(
                lessonId: 'synthetic',
                apiBaseUrl: 'https://school.test',
                load: (_) async => [
                  {'id': 't', 'title': title, 'assetType': 'TEXT'},
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = find.text(title);
    final action = find.text('Read text');
    expect(tester.getBottomRight(name).dx, lessThanOrEqualTo(320));
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getBottomRight(name).dy),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('two document cards share the full desktop row', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherLessonResources(
              lessonId: 'synthetic',
              apiBaseUrl: 'https://school.test',
              load: (_) async => [
                {'id': 'p', 'title': 'Practice PDF', 'assetType': 'PDF'},
                {'id': 't', 'title': 'Practice text', 'assetType': 'TEXT'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pdf = find.byKey(const ValueKey('resource-card-p'));
    final text = find.byKey(const ValueKey('resource-card-t'));
    expect(tester.getSize(pdf).width, 712);
    expect(tester.getTopLeft(pdf).dy, tester.getTopLeft(text).dy);
    expect(tester.getBottomRight(text).dx, 1440);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'delayed inline media is revealed once without stealing later scroll',
    (tester) async {
      final assets = Completer<dynamic>();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 900),
                  TeacherLessonResources(
                    lessonId: 'synthetic',
                    apiBaseUrl: 'https://school.test',
                    openFirst: true,
                    load: (path) async {
                      if (path.endsWith('/assets')) return assets.future;
                      throw StateError('Synthetic unavailable video');
                    },
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(scroll.offset, 0);
      assets.complete([
        {'id': 'v', 'title': 'Synthetic video', 'assetType': 'VIDEO'},
      ]);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(800));
      expect(
        tester.getTopLeft(find.byType(LessonMediaViewer)).dy,
        lessThan(150),
      );
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(scroll.offset, 200);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('documents and images use open actions instead of play', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherLessonResources(
              lessonId: 'synthetic',
              apiBaseUrl: 'https://school.test',
              load: (_) async => [
                {'id': 'p', 'title': 'Practice PDF', 'assetType': 'PDF'},
                {
                  'id': 'i',
                  'title': 'Practice image',
                  'assetType': 'ATTACHMENT',
                  'mimeType': 'image/png',
                },
                {'id': 't', 'title': 'Practice text', 'assetType': 'TEXT'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open PDF'), findsOneWidget);
    expect(find.text('View image'), findsOneWidget);
    expect(find.text('Read text'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    await tester.tap(find.text('PDF (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Practice PDF'), findsOneWidget);
    expect(find.text('Practice image'), findsNothing);
    expect(find.text('Practice text'), findsNothing);
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Practice image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('resource sequence stays in the lesson at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherLessonResources(
                lessonId: '33',
                apiBaseUrl: 'https://school.test',
                load: (path) async {
                  if (path.endsWith('/assets')) {
                    return [
                      {
                        'id': '9',
                        'title': 'First resource',
                        'assetType': 'VIDEO',
                      },
                      {
                        'id': '10',
                        'title': 'Second resource',
                        'assetType': 'AUDIO',
                      },
                    ];
                  }
                  opened.add(path);
                  throw StateError('Synthetic unavailable resource');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Watch video'), findsOneWidget);
      expect(find.text('Play audio'), findsOneWidget);
      final firstCard = tester.getRect(
        find.byKey(const ValueKey('resource-card-9')),
      );
      final secondCard = tester.getRect(
        find.byKey(const ValueKey('resource-card-10')),
      );
      if (width >= 720) {
        expect(secondCard.top, firstCard.top);
        expect(secondCard.left, greaterThan(firstCard.right));
      } else {
        expect(secondCard.top, greaterThan(firstCard.bottom));
        expect(secondCard.left, firstCard.left);
      }
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();
      expect(find.text('Resource 1 of 2 available'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(LessonMediaViewer)).dy,
        lessThan(tester.getTopLeft(find.text('Lesson resources')).dy),
      );
      expect(find.textContaining('Watch video - Selected'), findsOneWidget);
      await tester.ensureVisible(find.text('Audio (1)'));
      await tester.tap(find.text('Audio (1)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('teacher-resource-9')), findsOneWidget);
      expect(opened, ['/api/courses/assets/9/open']);
      expect(
        tester
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .onPrevious,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('next-resource')));
      await tester.tap(find.byKey(const ValueKey('next-resource')));
      await tester.pumpAndSettle();
      expect(find.text('Resource 2 of 2 available'), findsOneWidget);
      expect(find.byKey(const ValueKey('teacher-resource-9')), findsNothing);
      expect(
        tester.widget<LessonMediaViewer>(find.byType(LessonMediaViewer)).onNext,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('previous-resource')),
      );
      await tester.tap(find.byKey(const ValueKey('previous-resource')));
      await tester.pumpAndSettle();
      expect(find.text('Resource 1 of 2 available'), findsOneWidget);
      expect(opened, [
        '/api/courses/assets/9/open',
        '/api/courses/assets/10/open',
        '/api/courses/assets/9/open',
      ]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('opening and closing media reveal the relevant section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 700),
                TeacherLessonResources(
                  lessonId: '33',
                  apiBaseUrl: 'https://school.test',
                  load: (path) async {
                    if (path.endsWith('/assets')) {
                      return [
                        {
                          'id': '9',
                          'title': 'Synthetic audio',
                          'assetType': 'AUDIO',
                        },
                      ];
                    }
                    throw StateError('Unavailable test media');
                  },
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Synthetic audio'));
    await tester.tap(find.text('Synthetic audio'));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byType(LessonMediaViewer)).dy;
    expect(top, inInclusiveRange(0, 100));
    await tester.ensureVisible(find.text('Back to lesson text'));
    await tester.tap(find.text('Back to lesson text'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonMediaViewer), findsNothing);
    expect(
      tester.getTopLeft(find.text('Lesson resources')).dy,
      inInclusiveRange(0, 100),
    );
    expect(tester.takeException(), isNull);
  });
  test('teacher delivery accepts only its signed same-origin route', () {
    Map<String, dynamic> response(String path) => {
      'asset': {'title': 'Synthetic audio'},
      'delivery': {
        'status': 'READY',
        'playerKind': 'AUDIO',
        'inlineUrl': path,
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      },
    };
    LessonMediaDelivery parse(String path, {bool teacher = true}) =>
        LessonMediaDelivery.parse(
          response(path),
          apiBaseUrl: 'https://school.test',
          assetId: '9',
          teacherResource: teacher,
        );
    expect(
      parse('/api/courses/assets/9/deliver?token=synthetic').kind,
      'AUDIO',
    );
    for (final path in [
      '/api/learner/assets/9/deliver?token=synthetic',
      '/api/courses/assets/10/deliver?token=synthetic',
      'https://other.test/api/courses/assets/9/deliver?token=synthetic',
    ]) {
      expect(() => parse(path), throwsFormatException);
    }
    expect(
      () => parse(
        '/api/courses/assets/9/deliver?token=synthetic',
        teacher: false,
      ),
      throwsFormatException,
    );
  });

  testWidgets(
    'resources use teacher authorization and clear player on lesson change',
    (tester) async {
      final requests = <String>[];
      Future<dynamic> load(String path) async {
        requests.add(path);
        if (path.endsWith('/open')) throw StateError('private backend detail');
        return path.contains('/33/')
            ? [
                {'id': '9', 'title': 'Synthetic audio', 'assetType': 'AUDIO'},
              ]
            : [];
      }

      Future<void> render(String lesson) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherLessonResources(
                  lessonId: lesson,
                  load: load,
                  apiBaseUrl: 'https://school.test',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render('33');
      await tester.tap(find.text('Synthetic audio'));
      await tester.pumpAndSettle();
      expect(requests.last, '/api/courses/assets/9/open');
      expect(find.text('private backend detail'), findsNothing);
      expect(
        find.text('The media could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .teacherResource,
        isTrue,
      );
      await render('34');
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(find.textContaining('No media resources'), findsOneWidget);
      expect(requests.any((path) => path.contains('/learner/')), isFalse);
    },
  );
}
