import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_audit_page.dart';
import 'package:mif_app/src/report_preview.dart';

void main() {
  testWidgets(
    'PDF selection follows search and is disabled for unavailable data',
    (tester) async {
      List<String>? exported;
      Future<void> render({bool busy = false, String? error}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformAuditPage(
                records: [
                  {'id': 'first', 'action': 'first.action'},
                  {'id': 'second', 'action': 'second.action'},
                ],
                busy: busy,
                error: error,
                filters: const SizedBox(),
                page: 1,
                onPage: (_) {},
                onRefresh: () {},
                onDetails: (_) {},
                exportPdf: (ids) async {
                  exported = ids;
                  return {};
                },
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await render();
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump();
      var button = tester.widget<ReportPdfButton>(find.byType(ReportPdfButton));
      expect(button.enabled, isTrue);
      await button.load(button.path);
      expect(exported, ['second']);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(
        tester.widget<ReportPdfButton>(find.byType(ReportPdfButton)).enabled,
        isFalse,
      );
      await render(busy: true);
      expect(
        tester.widget<ReportPdfButton>(find.byType(ReportPdfButton)).enabled,
        isFalse,
      );
      await render(error: 'Access unavailable');
      expect(
        tester.widget<ReportPdfButton>(find.byType(ReportPdfButton)).enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 1440.0]) {
    testWidgets('Audit records hidden during loading and errors at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var refreshes = 0;
      final records = List.generate(
        20,
        (i) => <String, dynamic>{
          'id': 'synthetic-$i',
          'action': 'synthetic.audit.action',
          'createdAt': '2026-11-02T00:00:00Z',
        },
      );
      Future<void> render({bool busy = false, String? error}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformAuditPage(
                records: records,
                busy: busy,
                error: error,
                filters: const SizedBox(),
                page: 2,
                onPage: (_) => fail('Unavailable records must not paginate'),
                onRefresh: () => refreshes++,
                onDetails: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await render();
      await tester.enterText(find.byType(TextField), 'synthetic-19');
      await tester.pump();
      expect(find.text('synthetic.audit.action'), findsOneWidget);
      for (final busy in [true, false]) {
        await render(
          busy: busy,
          error: busy ? null : 'Access could not be verified',
        );
        expect(find.text('synthetic.audit.action'), findsNothing);
        expect(find.text('Details'), findsNothing);
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
      }
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      expect(refreshes, 1);
      await render();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'synthetic-19',
      );
      expect(find.text('synthetic.audit.action'), findsOneWidget);
      expect(find.text('Showing 1 of 20 events on page 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final width in [320.0, 1440.0]) {
    testWidgets('Audit events searchable and read-only at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAuditPage(
              records: [
                {
                  'id': 'synthetic-event',
                  'action': 'platform.login.failed',
                  'actorRole': 'IT_SECURITY',
                  'createdAt': '2026-11-01T08:00:00Z',
                },
              ],
              busy: false,
              error: null,
              filters: const Text('Filters'),
              page: 1,
              onPage: (_) {},
              onRefresh: () {},
              onDetails: (_) => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(find.text('Failed login'), findsOneWidget);
      expect(find.text('IT / Security'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Failed login');
      await tester.pump();
      expect(find.text('Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      expect(opened, isTrue);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('No audit events match this view.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Failed login'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
