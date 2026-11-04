import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_contents.dart';

void main() {
  for (final multiple in [false, true]) {
    testWidgets('lesson groups preserve access, multiple=$multiple', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              child: LessonContents(
                currentId: '1',
                progress: const {
                  '1': {'progressPercent': 0},
                },
                lessons: [
                  for (var i = 1; i <= 3; i++)
                    {
                      'id': '$i',
                      'title': 'Lesson $i',
                      'moduleId': multiple && i == 3 ? 'b' : 'a',
                      'moduleTitle': multiple && i == 3
                          ? 'Second module'
                          : 'First module',
                      'accessState': i == 3 ? 'LOCKED' : 'OPEN',
                    },
                ],
                onSelect: (lesson) => selected = lesson['id'] as String,
              ),
            ),
          ),
        ),
      );
      expect(
        find.byType(ExpansionTile),
        multiple ? findsNWidgets(2) : findsNothing,
      );
      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('outline-lesson-2')));
      expect(selected, '2');
      if (multiple) {
        await tester.tap(find.text('Second module'));
        await tester.pumpAndSettle();
      }
      final locked = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('outline-lesson-3')),
      );
      expect(locked.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
