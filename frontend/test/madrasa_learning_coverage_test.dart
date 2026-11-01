import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mif_app/src/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_learning_coverage.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
  final report = {'items': <dynamic>[], 'hasMore': true};
  testWidgets(
    'follow-up filter preserves loaded page and excludes empty scopes',
    (tester) async {
      var calls = 0;
      Future<dynamic> load(String _) async {
        calls++;
        return {
          'hasMore': true,
          'items': [
            {
              'id': '1',
              'name': 'Synthetic complete',
              'eligible': 6,
              'recorded': 6,
              'unrecorded': 0,
              'needingSupport': 0,
            },
            {
              'id': '2',
              'name': 'Synthetic missing',
              'eligible': 6,
              'recorded': 2,
              'unrecorded': 4,
              'needingSupport': 0,
            },
            {
              'id': '3',
              'name': 'Synthetic support',
              'eligible': 6,
              'recorded': 6,
              'unrecorded': 0,
              'needingSupport': 1,
            },
            {
              'id': '4',
              'name': 'Synthetic empty',
              'eligible': 0,
              'recorded': 0,
              'unrecorded': 0,
              'needingSupport': 0,
            },
          ],
        };
      }

      Widget view(bool only) => host(
        MadrasaLearningCoverage(
          load: load,
          filters: const {},
          onSessionExpired: () {},
          followupsOnly: only,
        ),
      );
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic complete'), findsOneWidget);
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic complete'), findsNothing);
      expect(find.text('Synthetic empty'), findsNothing);
      expect(find.text('Synthetic missing'), findsOneWidget);
      expect(find.text('Synthetic support'), findsOneWidget);
      expect(
        find.textContaining('2 madrasas to follow up on this page'),
        findsOneWidget,
      );
      expect(calls, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic complete'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final counts in [(0, 0), (0, 6), (2, 6), (6, 6)]) {
    testWidgets(
      'coverage distinguishes empty scope from zero records $counts',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            MadrasaLearningCoverage(
              filters: const {},
              onSessionExpired: () {},
              load: (_) async => {
                'items': [
                  {
                    'id': '1',
                    'name': 'Synthetic Madrasa',
                    'status': 'ACTIVE',
                    'recorded': counts.$1,
                    'eligible': counts.$2,
                    'unrecorded': counts.$2 - counts.$1,
                    'needingSupport': 0,
                  },
                ],
                'hasMore': false,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (counts.$2 == 0) {
          expect(
            find.text('Not applicable: no eligible learners'),
            findsOneWidget,
          );
          expect(find.byType(LinearProgressIndicator), findsNothing);
        } else {
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(progress.value, counts.$1 / counts.$2);
          expect(progress.semanticsValue, '${counts.$1} of ${counts.$2}');
        }
        expect(find.text('Not an attainment ranking'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('refresh hides stale snapshot and retry restores current time', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<dynamic>();
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        MadrasaLearningCoverage(
          filters: const {'quranMonth': '2026-10'},
          onSessionExpired: () {},
          load: (path) {
            paths.add(path);
            calls++;
            if (calls == 2) return pending.future;
            return Future.value({
              ...report,
              'generatedAt': calls == 1
                  ? '2026-10-30T10:00:00Z'
                  : '2026-10-30T11:00:00Z',
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-10-30T10:00:00.000Z'), findsOneWidget);
    await tester.tap(find.text('Refresh madrasas'));
    await tester.pump();
    expect(find.textContaining('2026-10-30T10:00:00.000Z'), findsNothing);
    expect(find.text('Refresh madrasas'), findsNothing);
    pending.completeError(Exception('Synthetic network failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Madrasa snapshot:'), findsNothing);
    await tester.tap(find.text('Retry madrasa coverage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-10-30T11:00:00.000Z'), findsOneWidget);
    expect(paths.toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed later page can retry or return with filters retained', (
    tester,
  ) async {
    final paths = <Uri>[];
    await tester.pumpWidget(
      host(
        MadrasaLearningCoverage(
          filters: const {'madrasa': 'Synthetic', 'quranMonth': '2026-10'},
          onSessionExpired: () {},
          load: (path) async {
            final uri = Uri.parse(path);
            paths.add(uri);
            if (uri.queryParameters['page'] == '2') {
              throw Exception('Private server error');
            }
            return report;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next madrasas'));
    await tester.pumpAndSettle();
    expect(find.text('Private server error'), findsNothing);
    await tester.tap(find.text('Retry madrasa coverage'));
    await tester.pumpAndSettle();
    expect(paths.last.queryParameters['page'], '2');
    await tester.tap(find.text('Back to first madrasa page'));
    await tester.pumpAndSettle();
    expect(paths.last.queryParameters, {
      'madrasa': 'Synthetic',
      'quranMonth': '2026-10',
      'page': '1',
    });
    expect(find.text('Madrasa page 1'), findsOneWidget);
  });

  testWidgets('new filters replace a pending request and ignore its late 401', (
    tester,
  ) async {
    final old = Completer<dynamic>();
    var expired = 0;
    final paths = <Uri>[];
    Future<dynamic> load(String path) {
      paths.add(Uri.parse(path));
      return paths.length == 1 ? old.future : Future.value(report);
    }

    Widget view(String month) => host(
      MadrasaLearningCoverage(
        filters: {'quranMonth': month},
        load: load,
        onSessionExpired: () => expired++,
      ),
    );
    await tester.pumpWidget(view('2026-09'));
    await tester.pump();
    await tester.pumpWidget(view('2026-10'));
    await tester.pumpAndSettle();
    old.completeError(const ApiException('Private failure', 401));
    await tester.pumpAndSettle();
    expect(expired, 0);
    expect(paths.last.queryParameters, {'quranMonth': '2026-10', 'page': '1'});
    expect(find.text('Madrasa page 1'), findsOneWidget);
    expect(find.textContaining('Access to madrasa'), findsNothing);
  });

  for (final status in [401, 403]) {
    testWidgets('current $status hides records and does not offer retry', (
      tester,
    ) async {
      var expired = 0;
      await tester.pumpWidget(
        host(
          MadrasaLearningCoverage(
            filters: const {},
            onSessionExpired: () => expired++,
            load: (_) async => throw ApiException('Private failure', status),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(expired, status == 401 ? 1 : 0);
      expect(find.text('Retry madrasa coverage'), findsNothing);
      expect(find.text('Private failure'), findsNothing);
      expect(find.textContaining('Access to madrasa'), findsOneWidget);
    });
  }
  testWidgets('opens read-only madrasa detail and paginates independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MadrasaLearningCoverage(
              filters: const {'quranMonth': '2026-10', 'subject': 'Arabic'},
              onSessionExpired: () {},
              load: (path) async {
                paths.add(Uri.parse(path));
                return {
                  'hasMore': paths.length == 1,
                  'items': [
                    {
                      'id': '1',
                      'name': 'Synthetic Madrasa',
                      'status': 'ACTIVE',
                      'eligible': 6,
                      'recorded': 2,
                      'unrecorded': 4,
                      'needingSupport': 1,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paths.single.queryParameters, {
      'quranMonth': '2026-10',
      'page': '1',
    });
    await tester.ensureVisible(find.text('View →'));
    await tester.tap(find.text('View →'));
    await tester.pumpAndSettle();
    expect(find.text('Without records'), findsOneWidget);
    expect(find.text('Support observed'), findsOneWidget);
    expect(find.text('Reporting period: 2026-10'), findsOneWidget);
    expect(find.textContaining('Voided records are excluded'), findsNothing);
    await tester.ensureVisible(find.text('How these counts are calculated'));
    await tester.tap(find.text('How these counts are calculated'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voided records are excluded'), findsOneWidget);
    expect(
      find.textContaining('Assessments cannot be changed here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Next madrasas'));
    await tester.tap(find.byTooltip('Next madrasas'));
    await tester.pumpAndSettle();
    expect(paths.last.queryParameters['page'], '2');
    expect(tester.takeException(), isNull);
  });
}
