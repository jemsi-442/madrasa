import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_text_editor.dart';

void main() {
  testWidgets('preview follows edits and can close with empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonTextEditor(
            lessonId: '9',
            submit: (_, _) async => throw StateError('Must not save'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'First title');
    await tester.enterText(find.byType(TextFormField).at(1), 'First notes');
    await tester.ensureVisible(find.text('Preview'));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Updated title');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Updated notes\nSecond paragraph',
    );
    await tester.pump();
    expect(find.text('Updated title'), findsNWidgets(2));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'Updated notes\nSecond paragraph',
    );
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.pump();
    await tester.ensureVisible(find.text('Hide preview'));
    await tester.tap(find.text('Hide preview'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Enter a title.'), findsNothing);
    expect(find.text('Write the lesson text.'), findsNothing);
  });

  for (final useBack in [false, true]) {
    testWidgets('protects text draft when closing with back=$useBack', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<dynamic>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => LessonTextEditor(
                    lessonId: '9',
                    submit: (_, _) async => throw StateError('Must not save'),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Synthetic title',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Unsaved notes');
      if (useBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Close editor'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard this text resource?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Unsaved notes',
      );
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonTextEditor), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);
    });
  }

  testWidgets(
    'validates, previews and saves locked text without losing the draft on failure',
    (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonTextEditor(
              lessonId: '9',
              submit: (path, body) async {
                expect(path, '/api/courses/lessons/9/text-resources');
                submitted = body;
                throw Exception('Synthetic failure');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save resource'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Synthetic notes',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Read this synthetic lesson.',
      );
      await tester.ensureVisible(find.text('Preview'));
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.ensureVisible(find.text('Save resource'));
      await tester.tap(find.text('Save resource'));
      await tester.pumpAndSettle();
      expect(submitted?['visibility'], 'LOCKED');
      expect(submitted?['text'], 'Read this synthetic lesson.');
      expect(find.textContaining('Could not confirm saving'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Read this synthetic lesson.',
      );
    },
  );

  testWidgets('prevents duplicate save while the request is pending', (
    tester,
  ) async {
    final pending = Completer<dynamic>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonTextEditor(
            lessonId: '9',
            submit: (_, _) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Notes');
    await tester.enterText(find.byType(TextFormField).at(1), 'Synthetic text');
    await tester.ensureVisible(find.text('Save resource'));
    await tester.tap(find.text('Save resource'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.completeError(Exception('Synthetic failure'));
    await tester.pumpAndSettle();
  });
}
