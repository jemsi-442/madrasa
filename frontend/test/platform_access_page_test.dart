import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_access_page.dart';

void main() {
  for (final anotherDialog in [false, true]) {
    testWidgets(
      'Leaving access removes only its review overlay=$anotherDialog',
      (tester) async {
        final visible = ValueNotifier(true);
        final navigator = GlobalKey<NavigatorState>();
        addTearDown(visible.dispose);
        var reviews = 0;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, show, _) => show
                    ? PlatformAccessPage(
                        records: const [
                          {
                            'id': 'synthetic',
                            'fullName': 'Synthetic Operator',
                            'role': 'IT_SECURITY',
                            'status': 'ACTIVE',
                          },
                        ],
                        busy: false,
                        error: null,
                        page: 1,
                        role: '',
                        onRole: (_) {},
                        onPage: (_) {},
                        onRefresh: () {},
                        onReview: (_) => reviews++,
                      )
                    : const Text('Sign in again'),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('Review'));
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        expect(find.text('Access history'), findsOneWidget);
        if (anotherDialog) {
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) =>
                const AlertDialog(title: Text('Independent notice')),
          );
          await tester.pumpAndSettle();
        }
        visible.value = false;
        await tester.pumpAndSettle();
        expect(find.text('Access history', skipOffstage: false), findsNothing);
        expect(
          find.text('Synthetic Operator', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Independent notice'),
          anotherDialog ? findsOneWidget : findsNothing,
        );
        expect(reviews, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final busy in [true, false]) {
    testWidgets(
      'Access review closes when data becomes unavailable busy=$busy',
      (tester) async {
        var reviews = 0;
        final rows = List.generate(
          20,
          (i) => <String, dynamic>{
            'id': 'synthetic-$i',
            'fullName': 'Synthetic Operator $i',
            'role': 'IT_SECURITY',
            'status': 'ACTIVE',
          },
        );
        Future<void> render({bool loading = false, String? error}) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PlatformAccessPage(
                  records: rows,
                  busy: loading,
                  error: error,
                  page: 2,
                  role: '',
                  onRole: (_) {},
                  onPage: (_) => fail('Unavailable accounts must not paginate'),
                  onRefresh: () {},
                  onReview: (_) => reviews++,
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await render();
        await tester.enterText(find.byType(TextField), 'synthetic-19');
        await tester.pump();
        await tester.ensureVisible(find.text('Review'));
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await render(loading: busy, error: busy ? null : 'Access denied');
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Synthetic Operator 19'), findsNothing);
        expect(find.text('Access history'), findsNothing);
        for (final label in ['Previous', 'Next']) {
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, label),
                )
                .onPressed,
            isNull,
          );
        }
        expect(reviews, 0);
        await render();
        expect(find.text('Synthetic Operator 19'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'synthetic-19',
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final width in [320.0, 1600.0]) {
    testWidgets('Access layout and local search at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reviewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAccessPage(
              records: [
                {
                  'id': 'synthetic',
                  'fullName': 'Synthetic Operator',
                  'role': 'IT_SECURITY',
                  'status': 'ACTIVE',
                },
              ],
              busy: false,
              error: null,
              page: 1,
              role: '',
              onRole: (_) {},
              onPage: (_) {},
              onRefresh: () {},
              onReview: (_) => reviewed = true,
            ),
          ),
        ),
      );
      expect(find.text('Access & Roles'), findsOneWidget);
      expect(find.text('Synthetic Operator'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Access scope'), findsOneWidget);
      expect(reviewed, isFalse);
      await tester.tap(find.text('Access history'));
      await tester.pumpAndSettle();
      expect(reviewed, isTrue);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('Synthetic Operator'), findsNothing);
      expect(find.text('No accounts match this view.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Synthetic Operator'), findsOneWidget);
      expect(find.text('Disable account'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
