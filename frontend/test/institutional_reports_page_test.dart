import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/institutional_reports_page.dart';

void main() {
  testWidgets(
    'updates data automatically, preserves selections and retries after connection failure',
    (tester) async {
      var previews = 0;
      var fail = false;
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstitutionalReportsPage(
              load: (path) async => path.endsWith('/options')
                  ? {'items': []}
                  : {'items': [], 'hasMore': false},
              post: (path, body) async {
                previews++;
                requests.add(body);
                if (fail) throw Exception('offline');
                return {
                  'scope': 'All madrasas',
                  'items': [
                    {
                      'id': '1',
                      'name': 'Synthetic update $previews',
                      'hasData': true,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(previews, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(previews, 2);
      expect(requests.last, requests.first);
      expect(find.text('Synthetic update 2'), findsOneWidget);
      fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic update 2'), findsOneWidget);
      expect(find.textContaining('reconnecting automatically'), findsOneWidget);
      fail = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic update 4'), findsOneWidget);
      expect(find.textContaining('reconnecting automatically'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
      expect(previews, 4);
    },
  );
  for (final width in [390.0, 1024.0, 1600.0]) {
    testWidgets(
      'institution reports fit $width and generate a real draft request',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstitutionalReportsPage(
                load: (path) async => path.endsWith('/options')
                    ? {
                        'items': [
                          {'id': '1', 'name': 'Synthetic madrasa'},
                        ],
                      }
                    : {
                        'items': [
                          {
                            'id': 'saved-report',
                            'month': '2026-10',
                            'scope': 'Synthetic madrasa',
                            'createdAt': '2026-10-31T10:00:00Z',
                          },
                        ],
                        'hasMore': false,
                      },
                post: (path, body) async {
                  if (!path.endsWith('/preview')) {
                    writes.add(body);
                    return {'id': 'synthetic-report'};
                  }
                  return {
                    'scope': 'All madrasas',
                    'items': [
                      {
                        'id': '1',
                        'name': 'Synthetic madrasa',
                        'code': 'TEST',
                        'hasData': true,
                        'attendance': 2,
                        'lessons': 1,
                        'quran': 1,
                        'receipts': [],
                        'followups': 0,
                      },
                    ],
                  };
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Institutional Reports'), findsOneWidget);
        expect(find.text('Submitted'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Preview report'));
        await tester.tap(find.text('Preview report'));
        await tester.pumpAndSettle();
        expect(find.text('Attendance records'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Generate draft'));
        await tester.pumpAndSettle();
        expect(writes.single['sections'], hasLength(4));
        expect(writes.single['requestId'], isNotEmpty);
        expect(find.text('Draft saved'), findsOneWidget);
        await tester.ensureVisible(find.text('Recent reports'));
        expect(
          find.byType(DataTable),
          width >= 1024 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('connection failure displays retry without invented counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstitutionalReportsPage(
            load: (_) async => throw Exception('offline'),
            post: (_, _) async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('0 / 0'), findsNothing);
  });
}
