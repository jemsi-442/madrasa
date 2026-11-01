import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'package:mif_app/src/teacher_lesson_resources.dart';

void main() {
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
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();
      expect(find.text('Resource 1 of 2 available'), findsOneWidget);
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
