import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_catalogue.dart';
import 'package:mif_app/src/page_selection.dart';

void main() {
  testWidgets('legacy media demo cards are excluded from catalogue and count', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherCourseCatalogue(
              courses: const [
                {
                  'id': '1',
                  'slug': 'afaq-teacher-media-demo',
                  'title': 'Teacher media practice (Demo)',
                },
                {
                  'id': '2',
                  'slug': 'afaq-shared-video-demo',
                  'title': 'Shared video lesson (Demo)',
                },
                {
                  'id': '3',
                  'slug': 'regular-course',
                  'title': 'Synthetic teaching course',
                },
              ],
              load: (path) async {
                requests.add(path);
                return [];
              },
              refreshToken: 0,
              onOpen: (_) {},
              onModule: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assigned Courses (1)'), findsOneWidget);
    expect(find.text('Teacher media practice (Demo)'), findsNothing);
    expect(find.text('Shared video lesson (Demo)'), findsNothing);
    expect(find.text('Synthetic teaching course'), findsOneWidget);
    expect(
      requests.any((path) => path.contains('/1/') || path.contains('/2/')),
      isFalse,
    );
    await tester.enterText(find.byType(TextField), 'media');
    await tester.pumpAndSettle();
    expect(find.text('No courses match your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive catalogue isolates selection and preserves search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PageSelection(
          child: Scaffold(
            body: SingleChildScrollView(
              child: TeacherCourseCatalogue(
                courses: const [
                  {'id': '1', 'title': 'Synthetic media course'},
                ],
                load: (_) async => [],
                refreshToken: 0,
                onOpen: (_) {},
                onModule: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      SelectionContainer.maybeOf(
        tester.element(find.text('Assigned Courses (1)')),
      ),
      isNull,
    );
    expect(find.text('My Courses'), findsNothing);
    expect(
      find.text(
        'Access your assigned courses, modules, lessons and learning resources.',
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('Synthetic media course')).dy,
      lessThan(240),
    );
    await tester.enterText(find.byType(TextField), 'media');
    for (final width in [900.0, 1440.0, 390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpAndSettle();
      expect(find.text('media'), findsOneWidget);
      expect(find.text('Synthetic media course'), findsOneWidget);
      for (final label in ['Assigned Courses (1)']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('media'), findsNothing);
  });

  testWidgets('search works without duplicate tabs or teacher completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherCourseCatalogue(
              courses: const [
                {'id': '1', 'title': 'Synthetic media course'},
                {'id': '2', 'title': 'Synthetic language course'},
              ],
              load: (_) async => [],
              refreshToken: 0,
              onOpen: (_) {},
              onModule: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  LANGUAGE  ');
    await tester.pumpAndSettle();
    expect(find.text('Synthetic language course'), findsOneWidget);
    expect(find.text('Synthetic media course'), findsNothing);
    for (final label in ['In Progress', 'Completed', 'All My Courses']) {
      expect(find.text(label), findsNothing);
    }
    expect(
      find.textContaining('Personal course completion is not tracked'),
      findsNothing,
    );
    expect(find.text('60%'), findsNothing);
    expect(find.text('Synthetic language course'), findsOneWidget);
    expect(find.text('Synthetic media course'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Not tracked'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic media course'), findsOneWidget);
    expect(find.text('Synthetic language course'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
