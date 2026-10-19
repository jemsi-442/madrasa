import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_delivery_history_dialog.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('teaching history pages and retries at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var failed = false;
      final pages = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumDeliveryHistoryDialog(
              adoptionId: 'adoption-1',
              className: 'Class A',
              load: (path) async {
                final query = Uri.parse(path).queryParameters;
                expect(query['classCurriculumId'], 'adoption-1');
                final page = query['page']!;
                pages.add(page);
                if (page == '2' && !failed) {
                  failed = true;
                  throw Exception('Unavailable');
                }
                return {
                  'page': int.parse(page),
                  'hasMore': page == '1',
                  'items': [
                    {
                      'lesson': {'title': 'Reading page $page'},
                      'teacher': {'fullName': 'Synthetic Teacher'},
                      'taughtAt': '2026-10-20T10:00:00Z',
                      'assignment': {
                        'version': {
                          'subject': 'Arabic',
                          'level': 'Level 1',
                          'version': '1.0',
                        },
                      },
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not attendance'), findsOneWidget);
      expect(find.textContaining('v1.0'), findsOneWidget);
      expect(find.text('Reading page 1'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load teaching history.'), findsOneWidget);
      expect(find.text('Reading page 1'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Reading page 2'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(pages, ['1', '2', '2', '1']);
      expect(tester.takeException(), isNull);
    });
  }
}
