import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_page.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';

void main() {
  testWidgets('late report cannot replace a newer applied filter', (
    tester,
  ) async {
    final old = Completer<dynamic>();
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurriculumOversightPage(
            onBack: () {},
            onSessionExpired: () {},
            load: (path) async {
              requests++;
              if (requests == 1) return old.future;
              expect(Uri.parse(path).queryParameters, {
                'subject': 'Arabic',
                'page': '1',
              });
              return {'items': [], 'hasMore': false};
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Arabic');
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('Applied filters: Subject: Arabic'), findsOneWidget);
    old.complete({'items': [], 'hasMore': true});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
          .onPressed,
      isNull,
    );
    expect(find.text('Applied filters: Subject: Arabic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('curriculum opens oversight and returns to library', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'synthetic-super',
            onSessionExpired: () {},
            call: (path, {body}) async {
              paths.add(path);
              return {
                'items': [],
                'total': 0,
                'madrasaCount': 0,
                'hasMore': false,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Learning Oversight'));
    await tester.tap(find.text('Learning Oversight'));
    await tester.pumpAndSettle();
    expect(paths.last, '/curriculum/oversight?page=1');
    expect(
      find.text('No assigned frameworks match these filters.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to curriculum'));
    await tester.pumpAndSettle();
    expect(find.text('Shared subject library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('oversight filters, retry and pagination at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (path) async {
                final query = Uri.parse(path).queryParameters;
                queries.add(query);
                if (fail) {
                  fail = false;
                  throw Exception('Unavailable');
                }
                return {
                  'hasMore': query['page'] == '1',
                  'items': [
                    {
                      'madrasa': 'Synthetic Madrasa',
                      'madrasaStatus': 'SUSPENDED',
                      'subject': 'Arabic',
                      'level': 'L1',
                      'version': '2.0',
                      'subjectActive': false,
                      'adoptedClasses': 2,
                      'plannedClassLessons': 6,
                      'taughtClassLessons': 2,
                      'pendingClassLessons': 4,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load learning oversight.'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 / 6 class-lessons recorded as taught'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not evidence of current access'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Not assessment or learner achievement'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Synthetic');
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '1'});
      expect(find.text('Applied filters: Madrasa: Synthetic'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Unapplied Madrasa');
      await tester.pump();
      expect(
        find.textContaining('Filter changes are not applied yet'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '1'});
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '2'});
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(queries.last, {'page': '1'});
      expect(
        find.textContaining('Filter changes are not applied yet'),
        findsNothing,
      );
      expect(
        find.text('Applied filters: All assigned frameworks'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
