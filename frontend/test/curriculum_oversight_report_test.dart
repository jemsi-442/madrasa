import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_report.dart';
import 'package:mif_app/src/dashboard_components.dart' show StatusPill;

void main() {
  for (final scenario in [
    (0, 0, 0, 'Awaiting class adoption.'),
    (1, 0, 0, 'No planned class-lessons.'),
    (1, 4, 0, 'Awaiting teaching records.'),
    (1, 4, 2, 'Teaching records are in progress.'),
    (1, 4, 4, 'All planned class-lessons have teaching records.'),
  ]) {
    testWidgets('follow-up guidance: ${scenario.$4}', (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CurriculumOversightReport(
                showSummary: false,
                rows: [
                  {
                    'madrasa': 'Synthetic Madrasa',
                    'madrasaStatus': 'ACTIVE',
                    'subject': 'Arabic',
                    'version': '1.0',
                    'subjectActive': true,
                    'adoptedClasses': scenario.$1,
                    'plannedClassLessons': scenario.$2,
                    'taughtClassLessons': scenario.$3,
                    'pendingClassLessons': scenario.$2 - scenario.$3,
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(scenario.$4), findsOneWidget);
      if (scenario.$3 == 4) {
        expect(
          find.textContaining('This does not confirm learner achievement.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('pending madrasa and unadopted version do not imply coverage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CurriculumOversightReport(
              rows: [
                {
                  'madrasa': 'Synthetic Pending',
                  'madrasaStatus': 'PENDING_ACTIVATION',
                  'subject': 'Arabic',
                  'level': 'Level 1',
                  'version': '1.0',
                  'subjectActive': false,
                  'adoptedClasses': 0,
                  'taughtClassLessons': 0,
                  'plannedClassLessons': 0,
                  'pendingClassLessons': 0,
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending activation'), findsOneWidget);
    expect(find.text('PENDING_ACTIVATION'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('coverage is not applicable'), findsOneWidget);
    expect(
      find.textContaining('not evidence of current access'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('page-scoped oversight report at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CurriculumOversightReport(
                assessments: const {
                  'publishedAssessments': 3,
                  'classSubjectScopes': 5,
                },
                rows: [
                  {
                    'madrasa': 'Synthetic A',
                    'madrasaStatus': 'ACTIVE',
                    'subject': 'Arabic',
                    'level': 'Level 1',
                    'version': '1.0',
                    'subjectActive': true,
                    'adoptedClasses': 2,
                    'taughtClassLessons': 1,
                    'plannedClassLessons': 4,
                    'pendingClassLessons': 3,
                  },
                  {
                    'madrasa': 'Synthetic B',
                    'madrasaStatus': 'SUSPENDED',
                    'subject': 'Hadith',
                    'level': 'Level 2',
                    'version': '1.0',
                    'subjectActive': false,
                    'adoptedClasses': 3,
                    'taughtClassLessons': 2,
                    'plannedClassLessons': 8,
                    'pendingClassLessons': 6,
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This page only · All-time snapshot'), findsOneWidget);
      expect(find.text('Published classroom assessments'), findsOneWidget);
      expect(
        find.text('3 assessments across 5 class-subject combinations'),
        findsOneWidget,
      );
      expect(find.textContaining('not framework versions'), findsOneWidget);
      expect(find.text('On this page'), findsNWidgets(4));
      expect(find.byType(StatusPill), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Synthetic B · SUSPENDED'), findsNothing);
      for (final total in ['2', '5', '3', '9']) {
        expect(find.text(total), findsOneWidget);
      }
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.text('25%'), findsNWidgets(2));
      for (final progress in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )) {
        expect(progress.value, .25);
      }
      expect(
        find.textContaining('not evidence of current access'),
        findsOneWidget,
      );
      expect(find.textContaining('inactive or not linked'), findsOneWidget);
      expect(
        find.textContaining('Not connected to this report yet.'),
        findsOneWidget,
      );
      expect(find.text('450 / 520'), findsNothing);
      final table = tester.getTopLeft(find.text('Teaching record coverage'));
      final quran = tester.getTopLeft(find.text("Qur'an learning oversight"));
      if (width > 1000) {
        expect(quran.dx, greaterThan(table.dx));
      } else {
        expect(quran.dy, greaterThan(table.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
