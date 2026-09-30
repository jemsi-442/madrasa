import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/learner_courses_page.dart';
import 'package:mif_app/src/learner_lesson_reader.dart';

class CoursesFixture {
  final paths = <String>[];
  final writes = <Map<String, dynamic>>[];
  int completed = 0;
  bool failLoad = false, failSave = false;
  Completer<dynamic>? pendingSave;
  String deliveryUrl = '/api/learner/assets/30/deliver?token=test';
  DateTime expires = DateTime.now().add(const Duration(minutes: 5));
  String deliveryStatus = 'READY';
  Map<String, dynamic> course(String id, String title, String access) => {
    'id': id,
    'title': title,
    'summary': 'Learn at your own pace.',
    'accessState': access,
    'subject': {'id': id, 'name': id == '1' ? 'Arabic' : 'Fiqh'},
    'primaryInstructor': {'fullName': 'Teacher A'},
    'progress': {
      'totalLessons': 2,
      'completedLessons': completed,
      'progressPercent': completed * 50,
    },
  };
  Map<String, dynamic> row(
    String id,
    String title,
    String access,
    int percent,
  ) => {
    'id': id,
    'title': title,
    'accessState': access,
    'estimatedMinutes': 10,
    'progress': {'progressPercent': percent},
  };
  Map<String, dynamic> asset(
    String id,
    String title,
    String access,
    bool ready,
  ) => {
    'id': id,
    'title': title,
    'accessState': access,
    'sourceReady': ready,
    'assetType': 'PDF',
  };
  Future<dynamic> load(String path) async {
    paths.add(path);
    if (failLoad) throw ApiException('Could not load', 503);
    if (path.endsWith('/assets/30/open')) {
      return {
        'delivery': {
          'status': deliveryStatus,
          'inlineUrl': deliveryUrl,
          'expiresAt': expires.toUtc().toIso8601String(),
        },
      };
    }
    if (path == '/api/learner/courses') {
      return [
        course('1', 'Arabic foundations', 'OPEN'),
        course('2', 'Practical fiqh', 'PAYWALL'),
      ];
    }
    if (path.contains('/courses/')) {
      return {
        'course': {
          ...course('1', 'Arabic foundations', 'PAYWALL'),
          'description': 'A published curriculum.',
          'modules': [
            {
              'id': '10',
              'title': 'First steps',
              'lessons': [
                row('20', 'Alphabet', 'OPEN', 100),
                row('21', 'Paid lesson', 'PAYWALL', 0),
                row('22', 'Reading words', 'PREVIEW', completed == 0 ? 0 : 100),
              ],
            },
          ],
        },
      };
    }
    if (path.contains('/lessons/')) {
      return {
        'lesson': {
          'id': '22',
          'title': 'Reading words',
          'course': {'title': 'Arabic foundations'},
          'contentText': 'Read these words aloud.',
          'progress': {'progressPercent': completed == 0 ? 0 : 100},
          'assets': [
            asset('30', 'Reading notes', 'OPEN', true),
            asset('31', 'Private notes', 'PAYWALL', true),
            asset('32', 'Upcoming worksheet', 'OPEN', false),
          ],
        },
      };
    }
    throw StateError('Unexpected path: $path');
  }

  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add({'path': path, 'body': body});
    if (failSave) throw ApiException('Access has expired', 403);
    if (pendingSave != null) await pendingSave!.future;
    completed = 1;
    return {'progressPercent': 100};
  }

  Widget page({LessonResourceOpener? opener}) => LearnerCoursesPage(
    load: load,
    submit: submit,
    apiBaseUrl: 'https://school.test',
    openResource: opener,
  );
  Widget reader({LessonResourceOpener? opener}) => LearnerLessonReader(
    id: '22',
    load: load,
    submit: submit,
    apiBaseUrl: 'https://school.test',
    openResource: opener,
  );
}

Future<void> host(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: adminTheme(ThemeData()),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('resource URLs reject scripts, credentials and missing links', () {
    expect(
      lessonResourceUri('/assets/1?token=a', 'https://school.test').host,
      'school.test',
    );
    for (final value in [
      '',
      'javascript:alert(1)',
      'file:///tmp/a',
      'https://user:pass@school.test/a',
    ]) {
      expect(
        () => lessonResourceUri(value, 'https://school.test'),
        throwsFormatException,
      );
    }
  });

  testWidgets('search, subject and access filters work in grid and list', (
    tester,
  ) async {
    final data = CoursesFixture();
    await host(tester, data.page());
    expect(find.text('Arabic foundations'), findsOneWidget);
    expect(find.text('Practical fiqh'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'arabic');
    await tester.pumpAndSettle();
    expect(find.text('Practical fiqh'), findsNothing);
    await tap(tester, 'List');
    expect(find.byType(DataTable), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unknown');
    await tester.pumpAndSettle();
    expect(find.text('No courses match these filters.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tap(tester, 'All subjects');
    await tap(tester, 'Fiqh');
    expect(find.text('Arabic foundations'), findsNothing);
    expect(find.text('Practical fiqh'), findsOneWidget);
    await tap(tester, 'All courses');
    await tap(tester, 'Available / preview');
    expect(find.text('No courses match these filters.'), findsOneWidget);
    expect(data.writes, isEmpty);
  });

  testWidgets('course load retries without replacing errors with empty data', (
    tester,
  ) async {
    final data = CoursesFixture()..failLoad = true;
    await host(tester, data.page());
    expect(find.text('Try again'), findsOneWidget);
    data.failLoad = false;
    await tap(tester, 'Try again');
    expect(find.text('Arabic foundations'), findsOneWidget);
  });

  testWidgets('empty catalogue shows honest empty state', (tester) async {
    await host(
      tester,
      LearnerCoursesPage(
        load: (_) async => [],
        submit: (_, _) async => null,
        apiBaseUrl: 'https://school.test',
      ),
    );
    expect(
      find.text('No courses have been published for your programme yet.'),
      findsOneWidget,
    );
    expect(find.text('View lessons'), findsNothing);
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('curriculum and completion refresh at width $width', (
      tester,
    ) async {
      final data = CoursesFixture();
      await host(tester, data.page(), width: width);
      await tap(tester, 'View lessons');
      final locked = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Locked'),
      );
      expect(locked.onPressed, isNull);
      await tap(tester, 'Continue learning');
      expect(data.paths.last, '/api/learner/lessons/22');
      expect(find.text('Read these words aloud.'), findsOneWidget);
      await tap(tester, 'Mark complete');
      expect(data.writes.single, {
        'path': '/api/learner/lessons/22/progress',
        'body': {'progressPercent': 100, 'markCompleted': true},
      });
      expect(find.text('Lesson completed'), findsOneWidget);
      await tester.tap(find.byTooltip('Close lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Continue learning'), findsNothing);
      await tester.tap(find.byTooltip('Close course'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2 lessons complete'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completion prevents duplicate writes, failure permits retry', (
    tester,
  ) async {
    final data = CoursesFixture()..failSave = true;
    await host(tester, data.reader());
    await tap(tester, 'Mark complete');
    expect(find.text('Access has expired'), findsOneWidget);
    expect(find.text('0% recorded'), findsOneWidget);
    data.failSave = false;
    data.pendingSave = Completer<dynamic>();
    await tester.tap(find.text('Mark complete'));
    await tester.pump();
    await tester.tap(find.text('Saving...'));
    await tester.pump();
    expect(data.writes.length, 2);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Close lesson',
            ),
          )
          .onPressed,
      isNull,
    );
    data.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Lesson completed'), findsOneWidget);
  });

  testWidgets('lesson loading errors can be retried', (tester) async {
    final data = CoursesFixture()..failLoad = true;
    await host(tester, data.reader());
    data.failLoad = false;
    await tap(tester, 'Try again');
    expect(find.text('Read these words aloud.'), findsOneWidget);
  });

  testWidgets(
    'resources require fresh authorization and a user launch gesture',
    (tester) async {
      final data = CoursesFixture();
      final opened = <Uri>[];
      await host(
        tester,
        data.reader(
          opener: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      for (final label in ['Access required', 'Not connected']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
      await tap(tester, 'Open resource');
      expect(data.paths.last, '/api/learner/assets/30/open');
      expect(opened, isEmpty);
      await tap(tester, 'Open in browser');
      expect(
        opened.single.toString(),
        'https://school.test/api/learner/assets/30/deliver?token=test',
      );
      expect(data.writes, isEmpty);
    },
  );

  testWidgets('blocked resource launches allow retry', (tester) async {
    final data = CoursesFixture();
    var attempts = 0;
    await host(tester, data.reader(opener: (_) async => ++attempts > 1));
    await tap(tester, 'Open resource');
    await tap(tester, 'Open in browser');
    expect(find.text('Open in browser'), findsOneWidget);
    await tap(tester, 'Open in browser');
    expect(attempts, 2);
    expect(find.text('Open in browser'), findsNothing);
  });

  testWidgets('expired resource links cannot launch', (tester) async {
    final data = CoursesFixture()..expires = DateTime(2000);
    var attempts = 0;
    await host(
      tester,
      data.reader(
        opener: (_) async {
          attempts++;
          return true;
        },
      ),
    );
    await tap(tester, 'Open resource');
    await tap(tester, 'Open in browser');
    expect(attempts, 0);
    expect(find.textContaining('expired'), findsOneWidget);
  });

  testWidgets(
    'unsafe delivery links are rejected and pending sources stay unavailable',
    (tester) async {
      final data = CoursesFixture()..deliveryUrl = 'javascript:alert(1)';
      var attempts = 0;
      await host(
        tester,
        data.reader(
          opener: (_) async {
            attempts++;
            return true;
          },
        ),
      );
      await tap(tester, 'Open resource');
      expect(
        find.text('The resource could not be prepared. Please try again.'),
        findsOneWidget,
      );
      data.deliveryStatus = 'PENDING_SOURCE';
      await tap(tester, 'Open resource');
      expect(
        find.text(
          'This resource is not connected yet. Please contact your teacher.',
        ),
        findsOneWidget,
      );
      expect(attempts, 0);
      expect(data.writes, isEmpty);
    },
  );
}
