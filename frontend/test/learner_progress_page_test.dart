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
      await tap(t, find.widgetWithText(ChoiceChip, 'In progress'));
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
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('empty tracker offers courses without inventing progress', (
    t,
  ) async {
    var browsed = false;
    await host(
      t,
      LearnerProgressPage(
        load: (_) async => {'items': []},
        submit: (_, _) async => throw StateError('Unexpected write'),
        apiBaseUrl: 'https://school.test',
        onBrowse: () => browsed = true,
      ),
      width: 390,
      scale: 2,
    );
    expect(find.text('No lesson progress recorded yet.'), findsOneWidget);
    await tap(t, find.text('Browse courses'));
    expect(browsed, isTrue);
    expect(t.takeException(), isNull);
  });
}
