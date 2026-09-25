import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/attendance_register_editor.dart';
import 'package:mif_app/src/attendance_register_page.dart';

Map<String, dynamic> registerData() => {
  'class': {
    'id': '8',
    'name': 'Form One',
    'teacher': {'fullName': 'Teacher Amina'},
  },
  'date': attendanceDay(schoolToday()),
  'summary': {
    'present': 1,
    'absent': 0,
    'late': 0,
    'excused': 0,
    'total': 1,
    'unmarked': 1,
  },
  'items': [
    {
      'id': '1',
      'fullName': 'Amina Student',
      'admissionNo': 'MIF001',
      'current': true,
      'editable': true,
      'attendance': null,
    },
    {
      'id': '2',
      'fullName': 'Bilal Student',
      'admissionNo': 'MIF002',
      'current': true,
      'editable': true,
      'attendance': {
        'status': 'PRESENT',
        'version': 3,
        'checkInTime': '07:45',
        'reason': null,
        'markedBy': {'fullName': 'Teacher Amina'},
      },
    },
  ],
  'timeline': [
    {'date': '2026-09-24', 'present': 0, 'total': 0},
    {'date': '2026-09-25', 'present': 1, 'total': 1},
  ],
};

Future<dynamic> load(String path) async {
  if (path == '/api/classes') {
    return [
      {'id': '8', 'name': 'Form One', 'academicYear': '2026'},
    ];
  }
  if (path.contains('/history')) return [];
  return registerData();
}

Widget host(Widget child) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> openEditor(
  WidgetTester tester,
  PageSubmitter submit, {
  Future<dynamic> Function()? reload,
}) async {
  await tester.pumpWidget(
    host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AttendanceRegisterEditor(
              data: registerData(),
              submit: submit,
              reload: reload ?? () async => registerData(),
            ),
          ),
          child: const Text('Open editor'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> markFirstLate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('status-1-null')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Late').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('time-1')), '08:15');
  await tester.pump();
}

void main() {
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('register and editor fit $width', (tester) async {
      screen(tester, width);
      await tester.pumpWidget(
        host(AttendanceRegisterPage(load: load, submit: (_, _) async => {})),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a class to open its daily register.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('register-class-')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Form One - 2026').last);
      await tester.pumpAndSettle();
      expect(find.text('Student attendance'), findsOneWidget);
      expect(find.text('Not marked'), findsWidgets);
      expect(find.text('Attendance trend'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await openEditor(tester, (_, _) async => {});
      expect(find.text('Daily register'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sends changed students only, without marking untouched rows', (
    tester,
  ) async {
    screen(tester, 1100);
    Map<String, dynamic>? saved;
    await openEditor(tester, (path, body) async {
      expect(path, '/api/attendance/register');
      saved = body;
      return {'saved': 1};
    });
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-attendance')))
          .onPressed,
      isNull,
    );
    await markFirstLate(tester);
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();
    expect(saved?['records'], [
      {
        'studentId': '1',
        'version': 0,
        'status': 'LATE',
        'checkInTime': '08:15',
        'reason': null,
      },
    ]);
    expect(saved?.containsKey('correctionReason'), isFalse);
    expect(find.text('Daily register'), findsNothing);
  });

  testWidgets(
    'bulk changes clear absent check-in and require correction explanation',
    (tester) async {
      screen(tester, 1100);
      Map<String, dynamic>? saved;
      await openEditor(tester, (_, body) async {
        saved = body;
        return {};
      });
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('Mark selected (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Absent').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(
        find.text('Add a short reason for correcting saved attendance.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for correction'),
        'Checked with the class teacher',
      );
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();
      expect((saved!['records'] as List).length, 2);
      expect((saved!['records'] as List).last, {
        'studentId': '2',
        'version': 3,
        'status': 'ABSENT',
        'checkInTime': null,
        'reason': null,
      });
    },
  );

  testWidgets('a failed save keeps the draft and permits retry', (
    tester,
  ) async {
    screen(tester, 1100);
    var attempts = 0;
    await openEditor(tester, (_, _) async {
      if (++attempts == 1) throw const ApiException('Disconnected', 0);
      return {};
    });
    await markFirstLate(tester);
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your changes are still here'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('time-1')))
          .controller!
          .text,
      '08:15',
    );
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Daily register'), findsNothing);
  });

  testWidgets('stale writes cannot retry until explicitly reloaded', (
    tester,
  ) async {
    screen(tester, 1100);
    var reloads = 0;
    await openEditor(
      tester,
      (_, _) async => throw const ApiException('Changed', 409),
      reload: () async {
        reloads++;
        return registerData();
      },
    );
    await markFirstLate(tester);
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-attendance')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Reload register'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(reloads, 1);
    expect(find.text('0 unsaved changes'), findsOneWidget);
  });

  testWidgets('closing a dirty register asks before discarding changes', (
    tester,
  ) async {
    screen(tester, 1100);
    await openEditor(tester, (_, _) async => {});
    await markFirstLate(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Daily register'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Daily register'), findsNothing);
  });

  testWidgets('loading failure has a working retry and empty class state', (
    tester,
  ) async {
    screen(tester, 1100);
    var calls = 0;
    await tester.pumpWidget(
      host(
        AttendanceRegisterPage(
          load: (_) async {
            if (++calls == 1) throw const ApiException('Disconnected', 0);
            return [];
          },
          submit: (_, _) async => {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Create a class before taking attendance.'),
      findsOneWidget,
    );
    expect(calls, 2);
  });
}
