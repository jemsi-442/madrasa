import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_students_page.dart';

const student = {
  'id': 'synthetic-student',
  'fullName': 'Synthetic Learner',
  'classId': 'synthetic-class',
  'admissionNo': 'TEST-001',
  'currentClass': {'name': 'Synthetic class'},
};

Future<void> openProfile(
  WidgetTester tester, {
  double width = 1200,
  double scale = 1,
  required Future<dynamic> Function(String) load,
  required Future<dynamic> Function(String, Map<String, dynamic>) submit,
  ValueChanged<Map<String, dynamic>?>? onResult,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => TeacherStudentProfile(
                  studentId: 'synthetic-student',
                  load: load,
                  submit: submit,
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open profile'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'failed profile can retry without presenting missing data as empty',
    (tester) async {
      var attempts = 0;
      await openProfile(
        tester,
        load: (_) async {
          if (attempts++ == 0) throw Exception('Synthetic unavailable service');
          return {'student': student};
        },
        submit: (_, _) async {},
      );
      expect(
        find.text('We could not load this page. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('No open follow-ups'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Learner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Quran record details and voided state fit a narrow profile', (
    tester,
  ) async {
    await openProfile(
      tester,
      width: 390,
      scale: 1.5,
      load: (_) async => {
        'student': student,
        'sessions': [
          {
            'surahId': 1,
            'ayahFrom': 1,
            'ayahTo': 7,
            'learnedOn': '2026-01-02',
            'voidedAt': '2026-01-03',
            'note':
                'Synthetic observation with a longer explanation that wraps across several lines.',
          },
        ],
      },
      submit: (_, _) async {},
    );
    await tester.ensureVisible(find.text("Qur'an sessions"));
    await tester.tap(find.text("Qur'an sessions"));
    await tester.pumpAndSettle();
    expect(find.text('Voided'), findsOneWidget);
    expect(find.text('Surah 1 | 1-7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [(390.0, 1.0), (1200.0, 1.0), (390.0, 1.5)]) {
    testWidgets('profile sections and close remain usable at $size', (
      tester,
    ) async {
      await openProfile(
        tester,
        width: size.$1,
        scale: size.$2,
        load: (_) async => {
          'student': student,
          'supportNotes': [
            {
              'id': 'open',
              'note': 'Synthetic support action',
              'createdAt': '2026-01-02',
            },
            {
              'id': 'done',
              'note': 'Synthetic completed action',
              'resolvedAt': '2026-01-03',
              'createdAt': '2026-01-02',
            },
          ],
          'sessions': [],
          'courseProgress': {'linked': false},
        },
        submit: (_, _) async {},
      );
      expect(find.text('Synthetic Learner'), findsOneWidget);
      expect(find.text('Synthetic support action'), findsOneWidget);
      expect(find.text('Synthetic completed action'), findsNothing);
      await tester.ensureVisible(find.text('Completed (1)'));
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic completed action'), findsOneWidget);
      expect(find.text('Synthetic support action'), findsNothing);
      await tester.ensureVisible(find.text("Qur'an sessions"));
      await tester.tap(find.text("Qur'an sessions"));
      await tester.pumpAndSettle();
      expect(find.text('No learning sessions recorded yet.'), findsOneWidget);
      await tester.ensureVisible(find.text('Course activity').first);
      await tester.tap(find.text('Course activity').first);
      await tester.pumpAndSettle();
      expect(
        find.text('No learner login is linked to this student yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close profile'));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherStudentProfile), findsNothing);
    });
  }

  testWidgets('record Quran returns the selected student and class', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await openProfile(
      tester,
      load: (_) async => {'student': student},
      submit: (_, _) async {},
      onResult: (value) => selected = value,
    );
    await tester.tap(find.text("Record Qur'an"));
    await tester.pumpAndSettle();
    expect(selected?['id'], 'synthetic-student');
    expect(selected?['classId'], 'synthetic-class');
  });

  testWidgets('add and complete follow-up refresh the open profile', (
    tester,
  ) async {
    final notes = <Map<String, dynamic>>[];
    final requests = <String>[];
    await openProfile(
      tester,
      load: (_) async => {'student': student, 'supportNotes': notes},
      submit: (path, values) async {
        requests.add(path);
        if (path.endsWith('/resolve')) {
          notes.first['resolvedAt'] = '2026-01-03';
        } else {
          expect(values['studentId'], 'synthetic-student');
          expect(values['classId'], 'synthetic-class');
          expect(values['clientId'], isNotEmpty);
          notes.add({
            'id': 'note-1',
            'note': values['note'],
            'createdAt': '2026-01-02',
          });
        }
      },
    );
    await tester.tap(find.text('Add follow-up'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Synthetic practice follow-up',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherStudentProfile), findsOneWidget);
    expect(find.text('Open (1)'), findsOneWidget);
    await tester.ensureVisible(find.text('Mark completed'));
    await tester.tap(find.text('Mark completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark completed'));
    await tester.pumpAndSettle();
    expect(find.text('Open (0)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic practice follow-up'), findsOneWidget);
    expect(requests, [
      '/api/teacher-workspace/support',
      '/api/teacher-workspace/support/note-1/resolve',
    ]);
    expect(tester.takeException(), isNull);
  });
}
