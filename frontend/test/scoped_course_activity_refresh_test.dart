import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/live_data.dart';
import 'package:mif_app/src/parent_portal_page.dart';
import 'package:mif_app/src/teacher_students_page.dart';

const student = {
  'id': '1',
  'fullName': 'Synthetic learner',
  'admissionNo': 'TEST-001',
  'classId': '8',
  'status': 'ACTIVE',
  'currentClass': {'id': '8', 'name': 'Synthetic class'},
};

void main() {
  for (final role in ['teacher', 'parent']) {
    testWidgets('$role profile clears course activity after scope is removed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var profileReads = 0;
      var linked = true;
      final profilePath = role == 'teacher'
          ? '/api/teacher-workspace/students/1'
          : '/api/parent-portal/workspace/children/1/profile';
      Future<dynamic> load(String path) => liveRead(() async {
        if (path == '/api/parent-portal/workspace/overview') {
          return {
            'children': [student],
            'guardian': {'fullName': 'Synthetic guardian'},
          };
        }
        expect(path, profilePath);
        profileReads++;
        if (!linked) throw const ApiException('Not found', 404);
        return {
          'student': student,
          'courseProgress': {
            'linked': true,
            'trackedLessons': 2,
            'completedLessons': 1,
            'recent': [
              {
                'course': {'title': 'Synthetic course'},
                'lesson': {'title': 'Synthetic tracked lesson'},
                'progressPercent': 100,
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            ],
          },
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: adminTheme(ThemeData()),
          home: Scaffold(
            body: role == 'teacher'
                ? TeacherStudentProfile(
                    studentId: '1',
                    load: load,
                    submit: (_, _) async =>
                        fail('Read-only check must not write'),
                  )
                : SingleChildScrollView(
                    child: ParentPortalPage(
                      page: 1,
                      childId: '1',
                      load: load,
                      onChildSelected: (_) {},
                      onOpen: (_, {childId}) {},
                    ),
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (role == 'parent') {
        await tester.tap(find.text('View profile'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Synthetic tracked lesson'), findsOneWidget);
      linked = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic tracked lesson'), findsNothing);
      expect(find.text('Course activity'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('No course activity recorded'), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      expect(profileReads, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
