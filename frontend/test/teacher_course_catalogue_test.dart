import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_catalogue.dart';
import 'package:mif_app/src/page_selection.dart';

void main() {
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
      SelectionContainer.maybeOf(tester.element(find.text('My Courses'))),
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'media');
    for (final width in [900.0, 1440.0, 390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpAndSettle();
      expect(find.text('media'), findsOneWidget);
      expect(find.text('Synthetic media course'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('media'), findsNothing);
  });

  testWidgets('search and tabs do not invent teacher completion', (
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
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Personal course completion is not tracked'),
      findsOneWidget,
    );
    expect(find.text('60%'), findsNothing);
    await tester.tap(find.text('View assigned courses'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic language course'), findsOneWidget);
    expect(find.text('Synthetic media course'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Not tracked'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic media course'), findsOneWidget);
    expect(find.text('Synthetic language course'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
