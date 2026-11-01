import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_page.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';
import 'package:mif_app/src/api_client.dart';

Future<void> openTools(WidgetTester tester) async {
  final tools = find.text('Filters & details');
  if (tools.evaluate().isNotEmpty) {
    await tester.ensureVisible(tools);
    await tester.tap(tools);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> settleWithTools(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await openTools(tester);
}

Future<void> expandFilters(WidgetTester tester) async {
  await openTools(tester);
  final more = find.text('More filters');
  if (more.evaluate().isNotEmpty) {
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets(
    'applied filters remain visible when tools close and can be removed',
    (tester) async {
      final requests = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (path) async {
                requests.add(Uri.parse(path));
                return {'items': [], 'hasMore': false};
              },
            ),
          ),
        ),
      );
      await settleWithTools(tester);
      await tester.enterText(find.byType(TextField).first, 'Synthetic');
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['madrasa'], 'Synthetic');
      await tester.ensureVisible(find.text('Hide filters & details'));
      await tester.tap(find.text('Hide filters & details'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(InputChip), findsOneWidget);
      final remove = find.descendant(
        of: find.byType(InputChip),
        matching: find.byTooltip('Delete'),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters.containsKey('madrasa'), isFalse);
      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final field in [(3, 'assessmentMonth'), (4, 'quranMonth')]) {
    testWidgets('${field.$2} validates, applies and survives refresh', (
      tester,
    ) async {
      final queries = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (path) async {
                queries.add(Uri.parse(path).queryParameters);
                return {'items': [], 'hasMore': false};
              },
            ),
          ),
        ),
      );
      await settleWithTools(tester);
      final month = find.byType(TextField).at(field.$1);
      await expandFilters(tester);
      await tester.enterText(month, '2026-13');
      await settleWithTools(tester);
      await tester.ensureVisible(find.text('Apply filters'));
      await settleWithTools(tester);
      await tester.tap(find.text('Apply filters'));
      await settleWithTools(tester);
      expect(queries.length, 1);
      expect(
        find.text('Use YYYY-MM, or leave blank for all time.'),
        findsOneWidget,
      );
      await tester.enterText(month, '2026-10');
      await settleWithTools(tester);
      await tester.ensureVisible(find.text('Apply filters'));
      await settleWithTools(tester);
      await tester.tap(find.text('Apply filters'));
      await settleWithTools(tester);
      expect(queries.last[field.$2], '2026-10');
      await tester.enterText(month, '2026-11');
      await settleWithTools(tester);
      await tester.ensureVisible(find.text('Refresh'));
      await settleWithTools(tester);
      await tester.tap(find.text('Refresh'));
      await settleWithTools(tester);
      expect(queries.last[field.$2], '2026-10');
      await tester.ensureVisible(find.text('Clear filters'));
      await settleWithTools(tester);
      await tester.tap(find.text('Clear filters'));
      await settleWithTools(tester);
      expect(queries.last, {'page': '1'});
      expect(tester.widget<TextField>(month).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty filtered report offers an explicit filter reset', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurriculumOversightPage(
            onBack: () {},
            onSessionExpired: () {},
            load: (path) async {
              queries.add(Uri.parse(path).queryParameters);
              return {'items': [], 'hasMore': false};
            },
          ),
        ),
      ),
    );
    await settleWithTools(tester);
    expect(find.textContaining('Publish a framework'), findsOneWidget);
    expect(find.text('Show all assignments'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Synthetic unmatched');
    await tester.ensureVisible(find.text('Apply filters'));
    await settleWithTools(tester);
    await tester.tap(find.text('Apply filters'));
    await settleWithTools(tester);
    expect(
      find.textContaining('does not mean the frameworks were deleted'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Show all assignments'));
    await settleWithTools(tester);
    await tester.tap(find.text('Show all assignments'));
    await settleWithTools(tester);
    expect(queries.last, {'page': '1'});
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(find.text('Show all assignments'), findsNothing);
    expect(find.textContaining('Publish a framework'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'summary precedes filters and hides while refreshing or failing',
    (tester) async {
      final refresh = Completer<dynamic>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (_) async {
                if (++calls > 1) return refresh.future;
                return {'items': [], 'hasMore': false};
              },
            ),
          ),
        ),
      );
      await settleWithTools(tester);
      expect(find.text('On this page'), findsNWidgets(4));
      expect(
        tester.getTopLeft(find.text('Framework assignments')).dy,
        lessThan(tester.getTopLeft(find.text('Report filters')).dy),
      );
      await tester.ensureVisible(find.text('Refresh'));
      await settleWithTools(tester);
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(find.text('On this page'), findsNothing);
      expect(find.text('Loading learning oversight'), findsOneWidget);
      refresh.completeError(Exception('Synthetic connection failure'));
      await settleWithTools(tester);
      expect(find.text('On this page'), findsNothing);
      expect(find.text('Could not load learning oversight.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed later page retries and returns using applied filters', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurriculumOversightPage(
            onBack: () {},
            onSessionExpired: () {},
            load: (path) async {
              final query = Uri.parse(path).queryParameters;
              queries.add(query);
              if (query['page'] == '2') throw Exception('Internal detail');
              return {'items': [], 'hasMore': true};
            },
          ),
        ),
      ),
    );
    await settleWithTools(tester);
    await expandFilters(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Arabic');
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await settleWithTools(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Unapplied');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await settleWithTools(tester);
    expect(find.text('Page 2 could not be loaded.'), findsOneWidget);
    expect(find.text('Internal detail'), findsNothing);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await settleWithTools(tester);
    expect(queries.last, {'subject': 'Arabic', 'page': '2'});
    expect(queries.where((query) => query['page'] == '2'), hasLength(2));
    await tester.ensureVisible(find.text('Back to first page'));
    await tester.tap(find.text('Back to first page'));
    await settleWithTools(tester);
    expect(queries.last, {'subject': 'Arabic', 'page': '1'});
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Back to first page'), findsNothing);
    expect(
      find.textContaining('Filter changes are not applied yet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty later page recovers with applied filters intact', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurriculumOversightPage(
            onBack: () {},
            onSessionExpired: () {},
            load: (path) async {
              final query = Uri.parse(path).queryParameters;
              queries.add(query);
              return {
                'hasMore': query['page'] == '1',
                'items': query['page'] == '1'
                    ? [
                        {
                          'madrasa': 'Synthetic Madrasa',
                          'madrasaStatus': 'ACTIVE',
                          'subject': 'Arabic',
                          'level': 'L1',
                          'version': '1.0',
                          'subjectActive': true,
                          'adoptedClasses': 1,
                          'plannedClassLessons': 2,
                          'taughtClassLessons': 1,
                          'pendingClassLessons': 1,
                        },
                      ]
                    : [],
              };
            },
          ),
        ),
      ),
    );
    await settleWithTools(tester);
    await expandFilters(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Arabic');
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await settleWithTools(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Unapplied');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await settleWithTools(tester);
    expect(queries.last, {'subject': 'Arabic', 'page': '2'});
    expect(find.textContaining('No records on this page.'), findsOneWidget);
    expect(
      find.text('No assigned frameworks match these filters.'),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Back to first page'));
    await tester.tap(find.text('Back to first page'));
    await settleWithTools(tester);
    expect(queries.last, {'subject': 'Arabic', 'page': '1'});
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Back to first page'), findsNothing);
    expect(
      find.textContaining('Filter changes are not applied yet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (var index = 0; index < 3; index++) {
    testWidgets('filter $index validates before replacing applied report', (
      tester,
    ) async {
      final limit = [120, 120, 80][index];
      final queries = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () {},
              load: (path) async {
                queries.add(Uri.parse(path).queryParameters);
                return {
                  'items': [],
                  'hasMore': false,
                  'generatedAt': '2026-10-20T12:30:00Z',
                };
              },
            ),
          ),
        ),
      );
      await settleWithTools(tester);
      await expandFilters(tester);
      await tester.enterText(
        find.byType(TextField).at(index),
        'x' * (limit + 1),
      );
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await settleWithTools(tester);
      expect(queries, hasLength(1));
      expect(find.text('Use at most $limit characters.'), findsOneWidget);
      expect(
        find.text('Applied filters: All assigned frameworks'),
        findsOneWidget,
      );
      expect(find.textContaining('Report generated:'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).at(index),
        '  ${'x' * limit}  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleWithTools(tester);
      expect(queries, hasLength(2));
      expect(queries.last[['madrasa', 'subject', 'level'][index]], 'x' * limit);
      expect(find.text('Use at most $limit characters.'), findsNothing);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await settleWithTools(tester);
      expect(queries.last, {'page': '1'});
      expect(tester.takeException(), isNull);
    });
  }
  for (final status in [401, 403]) {
    testWidgets(
      'oversight labels access error $status without server details',
      (tester) async {
        var expired = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CurriculumOversightPage(
                onBack: () {},
                onSessionExpired: () => expired++,
                load: (_) async =>
                    throw ApiException('Internal server detail', status),
              ),
            ),
          ),
        );
        await settleWithTools(tester);
        expect(
          find.text(
            status == 401
                ? 'Your session has expired. Sign in again.'
                : 'Learning Oversight is not available for this account.',
          ),
          findsOneWidget,
        );
        expect(find.text('Internal server detail'), findsNothing);
        expect(find.text('Try again'), findsNothing);
        expect(expired, status == 401 ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final leavePage in [false, true]) {
    testWidgets('late unauthorized response ignored, disposed: $leavePage', (
      tester,
    ) async {
      final old = Completer<dynamic>();
      var requests = 0;
      var expired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumOversightPage(
              onBack: () {},
              onSessionExpired: () => expired++,
              load: (_) async {
                if (++requests == 1) return old.future;
                return {
                  'items': [],
                  'hasMore': false,
                  'generatedAt': '2026-10-20T12:30:00Z',
                };
              },
            ),
          ),
        ),
      );
      await tester.pump();
      if (leavePage) {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      } else {
        await openTools(tester);
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await settleWithTools(tester);
      }
      old.completeError(ApiException('Internal server detail', 401));
      await settleWithTools(tester);
      expect(expired, 0);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsNothing,
      );
      if (!leavePage) {
        expect(find.textContaining('Report generated:'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('refresh failure hides previous snapshot timestamp', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurriculumOversightPage(
            onBack: () {},
            onSessionExpired: () {},
            load: (_) async {
              if (++calls > 1) throw Exception('Unavailable');
              return {
                'items': [],
                'hasMore': false,
                'generatedAt': '2026-10-20T12:30:00Z',
              };
            },
          ),
        ),
      ),
    );
    await settleWithTools(tester);
    expect(find.text('Report generated: 2026-10-20 12:30 UTC'), findsOneWidget);
    final timestamp = find.text('Report generated: 2026-10-20 12:30 UTC');
    final snapshotNote = find.text(
      'Snapshot only, not live monitoring. Refresh to check for updates.',
    );
    expect(
      tester.getTopLeft(timestamp).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.text('Applied filters: All assigned frameworks'),
            )
            .dy,
      ),
    );
    expect(
      tester.getTopLeft(snapshotNote).dy - tester.getBottomLeft(timestamp).dy,
      greaterThanOrEqualTo(6),
    );
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await settleWithTools(tester);
    expect(find.textContaining('Report generated:'), findsNothing);
    expect(find.text('Could not load learning oversight.'), findsOneWidget);
    expect(find.text('Loading learning oversight'), findsNothing);
    expect(
      find.textContaining('this error does not mean the records were deleted'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
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
    await expandFilters(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Arabic');
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await settleWithTools(tester);
    expect(find.text('Applied filters: Subject: Arabic'), findsOneWidget);
    old.complete({'items': [], 'hasMore': true});
    await settleWithTools(tester);
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
    await settleWithTools(tester);
    await tester.ensureVisible(find.text('Learning Oversight'));
    await tester.tap(find.text('Learning Oversight'));
    await settleWithTools(tester);
    expect(paths.last, '/curriculum/oversight?page=1');
    expect(
      find.text('No assigned frameworks match these filters.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to curriculum'));
    await settleWithTools(tester);
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
      await settleWithTools(tester);
      expect(find.text('Could not load learning oversight.'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await settleWithTools(tester);
      expect(find.text('2 / 6 class-lessons recorded as taught'), findsNothing);
      await tester.ensureVisible(find.text('Framework and assessment details'));
      await tester.tap(find.text('Framework and assessment details'));
      await settleWithTools(tester);
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
      await settleWithTools(tester);
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '1'});
      expect(find.text('Applied filters: Madrasa: Synthetic'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Unapplied Madrasa');
      await tester.pump();
      expect(
        find.textContaining('Filter changes are not applied yet'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Refresh'));
      await settleWithTools(tester);
      await tester.tap(find.text('Refresh'));
      await settleWithTools(tester);
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '1'});
      await tester.ensureVisible(find.text('Next'));
      await settleWithTools(tester);
      await tester.tap(find.text('Next'));
      await settleWithTools(tester);
      expect(queries.last, {'madrasa': 'Synthetic', 'page': '2'});
      await tester.ensureVisible(find.text('Clear filters'));
      await settleWithTools(tester);
      await tester.tap(find.text('Clear filters'));
      await settleWithTools(tester);
      expect(queries.last, {'page': '1'});
      expect(
        find.textContaining('Filter changes are not applied yet'),
        findsNothing,
      );
      expect(
        find.text('Applied filters: All assigned frameworks'),
        findsOneWidget,
      );
      await expandFilters(tester);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await settleWithTools(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await settleWithTools(tester);
      await tester.tap(find.text('No current class adoption').last);
      await settleWithTools(tester);
      expect(queries.last, {'page': '1'});
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await settleWithTools(tester);
      expect(queries.last, {'adoption': 'without', 'page': '1'});
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await settleWithTools(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await settleWithTools(tester);
      await tester.tap(find.text('Active').last);
      await settleWithTools(tester);
      expect(queries.last, {'adoption': 'without', 'page': '1'});
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await settleWithTools(tester);
      expect(queries.last, {
        'adoption': 'without',
        'status': 'ACTIVE',
        'page': '1',
      });
      expect(find.text('Madrasa status: Active'), findsOneWidget);
      expect(find.textContaining('not delayed onboarding'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await settleWithTools(tester);
      expect(queries.last, {'page': '1'});
      expect(find.textContaining('not delayed onboarding'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
