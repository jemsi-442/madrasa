import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_courses_page.dart';
import 'package:mif_app/src/teacher_course_modules.dart';
import 'package:mif_app/src/teacher_course_card.dart';

void main() {
  for (final count in [1, 2, 3, 4]) {
    testWidgets('module cards fill the row with $count modules', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherCourseModules(
                course: const {},
                modules: List.generate(
                  count,
                  (i) => {
                    'id': 'layout-$i',
                    'title': 'Synthetic module ${i + 1}',
                  },
                ),
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final columns = count.clamp(1, 3);
      final first = tester.getRect(
        find.byKey(const ValueKey('teacher-course-item-layout-0')),
      );
      final last = tester.getRect(
        find.byKey(ValueKey('teacher-course-item-layout-${columns - 1}')),
      );
      expect(first.width, closeTo((1440 - (columns - 1) * 16) / columns, .1));
      expect(last.right, closeTo(1440, .1));
      expect(last.top, first.top);
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('course cover reflows for text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherCourseCard(
                course: const {
                  'id': 'layout',
                  'title': 'Synthetic accessible course',
                },
                load: (_) async => [],
                onOpen: () => opened = true,
                onModule: (_) {},
                refreshToken: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = tester.getRect(
        find.byKey(const ValueKey('teacher-course-cover-layout')),
      );
      final title = tester.getRect(find.text('Synthetic accessible course'));
      if (scale == 1) {
        expect(title.left, greaterThan(cover.right));
      } else {
        expect(title.top, greaterThan(cover.bottom));
      }
      await tester.ensureVisible(find.text('Open course'));
      await tester.tap(find.text('Open course'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'module summary uses returned counts and opens module at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? selected;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCourseModules(
                  course: const {'summary': 'Synthetic course summary'},
                  modules: const [
                    {
                      'id': 'm1',
                      'title': 'Video practice',
                      'stats': {
                        'lessons': 3,
                        'resources': 4,
                        'estimatedMinutes': 40,
                      },
                    },
                    {
                      'id': 'm2',
                      'title': 'Audio practice',
                      'stats': {
                        'lessons': 2,
                        'resources': 3,
                        'estimatedMinutes': 25,
                      },
                    },
                  ],
                  onOpen: (module) => selected = module,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 modules'), findsOneWidget);
        expect(tester.widget<Text>(find.text('2 modules')).style?.fontSize, 21);
        expect(
          tester.widget<Text>(find.text('Video practice')).style?.fontSize,
          20,
        );
        expect(find.text('5 lessons'), findsOneWidget);
        expect(find.text('7 resources'), findsOneWidget);
        expect(find.text('1h 5m'), findsOneWidget);
        expect(find.text('4 resources'), findsOneWidget);
        expect(find.text('3 resources'), findsOneWidget);
        expect(find.text('40 min estimated'), findsOneWidget);
        expect(find.text('25 min estimated'), findsOneWidget);
        final card = find.byKey(const ValueKey('teacher-course-item-m1'));
        final title = find.text('Video practice');
        expect(tester.getTopLeft(title).dx - tester.getTopLeft(card).dx, 22);
        expect(tester.getSize(title).width, greaterThan(150));
        await tester.ensureVisible(find.text('Audio practice'));
        await tester.tap(find.text('Audio practice'));
        expect(selected?['id'], 'm2');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 800.0, 1050.0, 1440.0]) {
    testWidgets('course catalogue fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherCoursesPage(
                load: (path) async => path.endsWith('/lessons')
                    ? [
                        {
                          'id': 'lesson',
                          'title': 'Synthetic lesson',
                          'summary':
                              'Practice reading and discussing lesson materials.',
                          'estimatedMinutes': 15,
                        },
                        {
                          'id': 'lesson-2',
                          'title': 'Second synthetic lesson',
                          'contentText': 'Second lesson reading content.',
                        },
                      ]
                    : path.endsWith('/modules')
                    ? [
                        {
                          'id': 'module',
                          'title': 'Synthetic module',
                          'stats': {'lessons': 1},
                        },
                      ]
                    : [
                        {
                          'id': 'synthetic',
                          'title': 'Synthetic teacher media practice course',
                        },
                      ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Courses'), findsNothing);
      expect(
        find.text('Synthetic teacher media practice course'),
        findsOneWidget,
      );
      expect(find.text('Course Modules'), findsOneWidget);
      expect(find.text('Synthetic module'), findsOneWidget);
      await tester.ensureVisible(find.text('Synthetic module'));
      await tester.tap(find.text('Synthetic module'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic lesson'), findsOneWidget);
      expect(find.text('Course Modules'), findsNothing);
      expect(find.byTooltip('Close lesson'), findsOneWidget);
      expect(find.text('Lesson 1 of 2 in this module'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Next lesson'));
      await tester.tap(find.text('Next lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Second lesson reading content.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'record actions preserve lesson location and returning rechecks access',
    (tester) async {
      final location = TeacherCourseLocation(
        course: {'id': 'c', 'title': 'Synthetic course'},
        module: {'id': 'm', 'title': 'Synthetic module'},
        lessonId: 'l',
      );
      final destinations = <TeacherLearningDestination>[];
      TeacherCourseLocation? saved;
      var deny = false;
      final requests = <String>[];
      Future<dynamic> load(String path) async {
        requests.add(path);
        if (deny) throw StateError('Access revoked');
        if (path.endsWith('/assets')) return [];
        return [
          {
            'id': 'l',
            'title': 'Synthetic lesson',
            'contentText': 'Practice only.',
          },
        ];
      }

      Future<void> render(TeacherCourseLocation initial) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCoursesPage(
                  load: load,
                  initialLocation: initial,
                  onRecordLearning: (current, target) {
                    saved = current;
                    destinations.add(target);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(location);
      expect(find.textContaining('No class selected'), findsOneWidget);
      for (final label in [
        'Cancel',
        "Qur'an practice",
        'Other subject results',
      ]) {
        await tester.ensureVisible(find.text('Record lesson results'));
        await tester.tap(find.text('Record lesson results'));
        await tester.pumpAndSettle();
        if (label == 'Cancel') expect(destinations, isEmpty);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        if (label == 'Cancel') expect(destinations, isEmpty);
      }
      expect(destinations, TeacherLearningDestination.values);
      expect(saved!.lessonId, 'l');
      expect(saved!.course['id'], 'c');
      expect(saved!.module['id'], 'm');
      expect(requests, [
        '/api/courses/modules/m/lessons',
        '/api/courses/lessons/l/assets',
      ]);
      await tester.pumpWidget(const SizedBox());
      await render(saved!);
      expect(find.text('Synthetic lesson'), findsOneWidget);
      expect(requests.where((path) => path.endsWith('/lessons')).length, 2);
      await tester.pumpWidget(const SizedBox());
      deny = true;
      await render(saved!);
      expect(find.text('Practice only.'), findsNothing);
      expect(find.text('Record lesson results'), findsNothing);
    },
  );

  testWidgets(
    'course card exposes an accessible open action without a duplicate banner',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCoursesPage(
                  load: (path) async => path.endsWith('/modules')
                      ? []
                      : [
                          {'id': 'c', 'title': 'Synthetic course'},
                        ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('My Courses'), findsNothing);
        expect(find.text('Synthetic course'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Open course')),
          containsSemantics(
            isButton: true,
            hasTapAction: true,
            label: 'Open course',
          ),
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets('restored lesson reveals its heading at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController(initialScrollOffset: 1000);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: TeacherCoursesPage(
                initialLocation: TeacherCourseLocation(
                  course: {'id': 'c'},
                  module: {'id': 'm'},
                  lessonId: 'l',
                ),
                load: (path) async => path.endsWith('/assets')
                    ? []
                    : [
                        {
                          'id': 'l',
                          'title': 'Restored synthetic lesson',
                          'contentText': List.filled(
                            80,
                            'Practice only.',
                          ).join('\n'),
                        },
                      ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.getRect(find.text('Restored synthetic lesson'));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThan(900));
      expect(scroll.offset, lessThan(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('class context and results chooser fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var revision = 0;
      var choices = 0;
      Future<dynamic> load(String path) async {
        if (path == '/api/teacher-workspace/classes') {
          return revision == 0
              ? [
                  {'id': 'class-1', 'name': 'Synthetic class'},
                ]
              : [];
        }
        if (path.endsWith('/assets')) return [];
        return [
          {'id': 'l', 'title': 'Synthetic lesson', 'contentText': 'Practice.'},
        ];
      }

      Future<void> render() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCoursesPage(
                  load: load,
                  classId: 'class-1',
                  refreshToken: revision,
                  initialLocation: TeacherCourseLocation(
                    course: {'id': 'c'},
                    module: {'id': 'm'},
                    lessonId: 'l',
                  ),
                  onRecordLearning: (_, _) => choices++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render();
      expect(find.text('Selected class: Synthetic class'), findsOneWidget);
      expect(find.text("Qur'an practice"), findsNothing);
      await tester.ensureVisible(find.text('Record lesson results'));
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Record lesson results'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('teacher-next-lesson')))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Record lesson results'));
      await tester.pumpAndSettle();
      expect(find.text("Qur'an practice"), findsOneWidget);
      expect(find.text('Other subject results'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(choices, 0);
      revision++;
      await render();
      expect(find.text('Selected class: Synthetic class'), findsNothing);
      expect(
        find.textContaining('Selected class is unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long lesson navigation reveals the next heading at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final requests = <String>[];
      Future<dynamic> load(String path) async {
        requests.add(path);
        return switch (path) {
          '/api/teaching/courses' => [
            {'id': 'c', 'title': 'Synthetic course'},
          ],
          '/api/courses/c/modules' => [
            {'id': 'm', 'title': 'Synthetic module'},
          ],
          '/api/courses/modules/m/lessons' => [
            for (final id in ['1', '2'])
              {
                'id': id,
                'title': 'Long lesson $id',
                'contentText': List.filled(
                  80,
                  'Synthetic teaching material.',
                ).join('\n'),
              },
          ],
          '/api/courses/lessons/1/assets' ||
          '/api/courses/lessons/2/assets' => [],
          _ => throw StateError('Unexpected request'),
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: TeacherCoursesPage(load: load),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Open course', 'View lessons', 'Long lesson 1']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      for (final step in [
        ('Next lesson', 'Long lesson 2'),
        ('Previous lesson', 'Long lesson 1'),
      ]) {
        await tester.ensureVisible(find.text(step.$1));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(900));
        await tester.tap(find.text(step.$1));
        await tester.pumpAndSettle();
        final heading = tester.getRect(find.text(step.$2));
        expect(heading.top, greaterThanOrEqualTo(0));
        expect(heading.bottom, lessThan(900));
        expect(tester.takeException(), isNull);
      }
      expect(requests.where((path) => path.contains('quran')), isEmpty);
    });

    testWidgets(
      'lesson navigation and refresh retain context at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var revision = 0;
        final requests = <String>[];
        Future<dynamic> load(String path) async {
          requests.add(path);
          if (path.endsWith('/assets')) return [];
          if (path == '/api/teaching/courses') {
            return [
              {'id': '11', 'title': 'Synthetic course'},
            ];
          }
          if (path == '/api/courses/11/modules') {
            return [
              {'id': '22', 'title': 'Module A'},
            ];
          }
          if (path == '/api/courses/modules/22/lessons') {
            return [
              {
                'id': '33',
                'title': 'Lesson one',
                'contentText': 'First synthetic text',
              },
              {
                'id': '34',
                'title': 'Lesson two',
                'contentText': 'Second synthetic text $revision',
              },
            ];
          }
          throw StateError('Unexpected endpoint');
        }

        Future<void> render() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TeacherCoursesPage(load: load, refreshToken: revision),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> tapText(String label) async {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await render();
        await tapText('Open course');
        await tapText('View lessons');
        await tester.tap(find.byKey(const ValueKey('teacher-course-item-33')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Previous lesson'),
              )
              .onPressed,
          isNull,
        );
        await tapText('Next lesson');
        expect(find.text('Lesson 2 of 2'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('teacher-next-lesson')),
              )
              .onPressed,
          isNull,
        );
        revision++;
        await render();
        expect(find.text('Second synthetic text 1'), findsOneWidget);
        expect(find.text('Lesson 2 of 2'), findsOneWidget);
        await tapText('Previous lesson');
        expect(find.text('First synthetic text'), findsOneWidget);
        expect(requests, [
          '/api/teaching/courses',
          '/api/courses/11/modules',
          '/api/courses/11/modules',
          '/api/courses/modules/22/lessons',
          '/api/courses/lessons/33/assets',
          '/api/courses/lessons/34/assets',
          '/api/courses/modules/22/lessons',
          '/api/courses/lessons/34/assets',
          '/api/courses/lessons/33/assets',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed refresh hides stale text and retry does not open another lesson',
    (tester) async {
      var revision = 0;
      var fail = false;
      var removed = false;
      Future<dynamic> load(String path) async {
        if (path.endsWith('/assets')) return [];
        if (path == '/api/teaching/courses') {
          return [
            {'id': '11', 'title': 'Synthetic course'},
          ];
        }
        if (path == '/api/courses/11/modules') {
          return [
            {'id': '22', 'title': 'Module A'},
          ];
        }
        if (fail) throw StateError('Private failure details');
        return removed
            ? [
                {
                  'id': '34',
                  'title': 'Other lesson',
                  'contentText': 'Must not open automatically',
                },
              ]
            : [
                {
                  'id': '33',
                  'title': 'Lesson one',
                  'contentText': 'Previously visible text',
                },
              ];
      }

      Future<void> render() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCoursesPage(load: load, refreshToken: revision),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render();
      for (final label in ['Open course', 'View lessons', 'Read lesson']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(find.text('Previously visible text'), findsOneWidget);
      fail = true;
      revision++;
      await render();
      expect(find.text('Previously visible text'), findsNothing);
      expect(find.text('Private failure details'), findsNothing);
      fail = false;
      removed = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.text('Must not open automatically'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('teacher-module-breadcrumb')));
      await tester.pumpAndSettle();
      expect(find.text('Other lesson'), findsOneWidget);
    },
  );

  testWidgets(
    'course continues to its own modules and lessons, with local return links',
    (tester) async {
      final requests = <String>[];
      Future<dynamic> load(String path) async {
        requests.add(path);
        return switch (path) {
          '/api/teaching/courses' => [
            {'id': '11', 'title': 'Synthetic Arabic course'},
          ],
          '/api/courses/11/modules' => [
            {'id': '22', 'title': 'Reading module'},
          ],
          '/api/courses/modules/22/lessons' => [
            {
              'id': '33',
              'title': 'Practice lesson',
              'contentText': 'Synthetic lesson content.',
            },
          ],
          '/api/courses/lessons/33/assets' => [],
          _ => throw StateError('Unexpected endpoint'),
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TeacherCoursesPage(load: load)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open course'));
      await tester.tap(find.text('Open course'));
      await tester.pumpAndSettle();
      expect(find.text('Reading module'), findsOneWidget);
      expect(find.text('0 lessons'), findsNothing);
      await tester.ensureVisible(find.text('View lessons'));
      await tester.tap(find.text('View lessons'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic lesson content.'), findsOneWidget);
      expect(find.text('COURSE'), findsNothing);
      expect(find.text('MODULE'), findsNothing);
      expect(find.text('Synthetic Arabic course'), findsOneWidget);
      expect(find.text('Reading module'), findsOneWidget);
      expect(find.text('Lesson 1 of 1'), findsOneWidget);
      expect(find.text('Lesson content'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('teacher-module-breadcrumb')),
      );
      await tester.tap(find.byKey(const ValueKey('teacher-module-breadcrumb')));
      await tester.pumpAndSettle();
      expect(find.text('Read lesson'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('teacher-course-breadcrumb')));
      await tester.pumpAndSettle();
      expect(find.text('View lessons'), findsOneWidget);
      await tester.tap(find.text('All my courses'));
      await tester.pumpAndSettle();
      expect(find.text('Open course'), findsOneWidget);
      expect(requests.every((path) => !path.contains('quran')), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unassigned teacher sees an explanation instead of unrelated continue buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TeacherCoursesPage(load: (_) async => [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No courses are assigned'), findsOneWidget);
      expect(find.text('Open course'), findsNothing);
    },
  );
}
