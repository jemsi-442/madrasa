import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/learner_progress_page.dart';
import 'lesson_media_flow_test.dart' show host, tap;

void main() {
  final rows = [
    {
      'progressPercent': 100,
      'completedAt': '2026-01-01T00:00:00Z',
      'course': {'id': '1', 'title': 'Sample course'},
      'lesson': {'id': '11', 'title': 'Finished practice'},
    },
    {
      'progressPercent': 30,
      'course': {'id': '2', 'title': 'Second course'},
      'lesson': {'id': '12', 'title': 'Ongoing practice'},
    },
  ];
  for (final width in [390.0, 1440.0]) {
    testWidgets('tracker filters and rechecks lesson access at $width', (
      t,
    ) async {
      final paths = <String>[];
      final writes = <String>[];
      await host(
        t,
        LearnerProgressPage(
          apiBaseUrl: 'https://school.test',
          onBrowse: () {},
          submit: (path, body) async {
            writes.add(path);
            return {};
          },
          load: (path) async {
            paths.add(path);
            if (path == '/api/learner/progress') return {'items': rows};
            throw Exception('Access removed');
          },
        ),
        width: width,
      );
      expect(find.text('Finished practice'), findsOneWidget);
      expect(find.text('Ongoing practice'), findsOneWidget);
      await tap(t, find.widgetWithText(ChoiceChip, 'In progress  1'));
      expect(find.text('Finished practice'), findsNothing);
      expect(find.text('Ongoing practice'), findsOneWidget);
      await tap(t, find.text('Continue lesson'));
      expect(paths, contains('/api/learner/lessons/12'));
      expect(
        find.text('We could not load this page. Please try again.'),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      Navigator.of(t.element(find.text('Try again'))).pop();
      await t.pumpAndSettle();
      expect(paths.where((path) => path == '/api/learner/progress').length, 2);
      expect(find.text('Finished practice'), findsNothing);
      await t.enterText(find.byType(TextField), 'missing');
      await t.pumpAndSettle();
      expect(find.text('No lessons match these filters.'), findsOneWidget);
      await tap(t, find.text('Clear filters'));
      expect(find.text('Finished practice'), findsOneWidget);
      expect(find.text('Ongoing practice'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Clear filters'), findsNothing);
      expect(writes, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('empty tracker offers courses without inventing progress', (
    t,
  ) async {
    var browsed = false;
    var quranOpened = false;
    var assessmentsOpened = false;
    await host(
      t,
      LearnerProgressPage(
        load: (_) async => {'items': []},
        submit: (_, _) async => throw StateError('Unexpected write'),
        apiBaseUrl: 'https://school.test',
        onBrowse: () => browsed = true,
        onQuran: () => quranOpened = true,
        onAssessments: () => assessmentsOpened = true,
      ),
      width: 390,
      scale: 2,
    );
    expect(find.text('No lesson progress recorded yet.'), findsOneWidget);
    await tap(t, find.text("Qur'an learning"));
    await tap(t, find.text('Teacher assessments'));
    expect(quranOpened, isTrue);
    expect(assessmentsOpened, isTrue);
    await tap(t, find.text('Browse courses'));
    expect(browsed, isTrue);
    expect(t.takeException(), isNull);
  });
  testWidgets('pagination and search reset work on desktop', (t) async {
    await host(
      t,
      LearnerProgressPage(
        load: (_) async => {
          'items': List.generate(
            12,
            (i) => {
              'progressPercent': 20,
              'course': {'id': '1', 'title': 'Synthetic course'},
              'lesson': {'id': '$i', 'title': 'Practice $i'},
            },
          ),
        },
        submit: (_, _) async => throw StateError('Unexpected write'),
        apiBaseUrl: 'https://school.test',
        onBrowse: () {},
      ),
      width: 1440,
    );
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Practice 0'), findsOneWidget);
    expect(find.text('Practice 5'), findsNothing);
    await tap(t, find.text('Next'));
    expect(find.text('Practice 5'), findsOneWidget);
    expect(find.text('Showing 6-10 of 12 lessons'), findsOneWidget);
    await tap(t, find.widgetWithText(OutlinedButton, '3'));
    expect(find.text('Showing 11-12 of 12 lessons'), findsOneWidget);
    expect(find.text('Practice 10'), findsOneWidget);
    await tap(t, find.widgetWithText(OutlinedButton, '1'));
    expect(find.text('Practice 0'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Practice 11');
    await t.pumpAndSettle();
    expect(
      find
          .text('Practice 11', findRichText: false)
          .evaluate()
          .where((element) => element.widget is Text),
      hasLength(1),
    );
    expect(find.text('Showing 1-1 of 1 lessons'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
