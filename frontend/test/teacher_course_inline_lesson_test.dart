import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_card.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('cover opens authorized lesson inline in one click at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      var navigation = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherCourseCard(
                course: const {'id': 'c', 'title': 'Synthetic course'},
                refreshToken: 0,
                apiBaseUrl: 'https://school.test',
                onOpen: () => navigation++,
                onModule: (_) => navigation++,
                load: (path) async {
                  requests.add(path);
                  switch (path) {
                    case '/api/courses/c/modules':
                      return [
                        {'id': 'empty', 'title': 'Empty module'},
                        {'id': 'm', 'title': 'Practice module'},
                      ];
                    case '/api/courses/modules/empty/lessons':
                      return [];
                    case '/api/courses/modules/m/lessons':
                      return [
                        {
                          'id': 'l',
                          'title': 'Practice lesson',
                          'contentText': 'Synthetic lesson notes',
                        },
                      ];
                    case '/api/courses/lessons/l/assets':
                      return [
                        {
                          'id': 'p',
                          'title': 'Practice PDF',
                          'assetType': 'PDF',
                        },
                        {
                          'id': 'v',
                          'title': 'Practice video',
                          'assetType': 'VIDEO',
                        },
                      ];
                    case '/api/courses/assets/v/open':
                      throw StateError('Synthetic unavailable video');
                    default:
                      throw StateError('Unexpected request $path');
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, ['/api/courses/c/modules']);
      await tester.tap(find.byTooltip('Play lesson'));
      await tester.pumpAndSettle();
      expect(navigation, 0);
      expect(find.byType(LessonMediaViewer), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inline-lesson-selectors-row')),
        width >= 640 ? findsOneWidget : findsNothing,
      );
      expect(
        tester
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .assetId,
        'v',
      );
      expect(find.text('Synthetic lesson notes'), findsOneWidget);
      expect(requests.last, '/api/courses/assets/v/open');
      expect(requests.where((p) => p.endsWith('/open')).length, 1);
      await tester.ensureVisible(find.byTooltip('Close lesson'));
      await tester.tap(find.byTooltip('Close lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(navigation, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
