import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_lesson_reading.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('lesson reading fits $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(1.5),
              ),
              child: const SingleChildScrollView(
                child: TeacherLessonReading(
                  summary: 'Synthetic lesson summary for a teaching exercise.',
                  text:
                      'First paragraph.\n\nSecond paragraph with teaching notes.',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Lesson notes'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
