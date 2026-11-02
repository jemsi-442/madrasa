@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_audit_page.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:web/web.dart' as web;

void main() {
  for (final outcome in ['success', 'denied', 'expired']) {
    testWidgets('Audit download browser flow: $outcome', (tester) async {
      final response = Completer<http.Response>();
      var exports = 0;
      final downloads = <String>[];
      final listener = ((web.Event event) {
        final target = event.target;
        if (target != null && target.isA<web.HTMLAnchorElement>()) {
          final anchor = target as web.HTMLAnchorElement;
          if (anchor.download.isNotEmpty) {
            // Observe the real Blob/download handoff without saving test files.
            event.preventDefault();
            expect(anchor.href, startsWith('blob:'));
            downloads.add(anchor.download);
          }
        }
      }).toJS;
      web.document.addEventListener('click', listener);
      addTearDown(() => web.document.removeEventListener('click', listener));
      final api = PlatformApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'synthetic-token',
                  'expiresIn': 900,
                  'user': {'id': 'synthetic-it', 'role': 'IT_SECURITY'},
                },
              }),
              200,
            );
          }
          exports++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/platform/audit-events/pdf');
          expect(jsonDecode(request.body), {
            'ids': ['second'],
          });
          return response.future;
        }),
      );
      addTearDown(api.close);
      await api.login('it@example.test', 'synthetic', '123456');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAuditPage(
              records: [
                {'id': 'first', 'action': 'first.action'},
                {'id': 'second', 'action': 'second.action'},
              ],
              busy: false,
              error: null,
              filters: const SizedBox(),
              page: 1,
              onPage: (_) {},
              onRefresh: () {},
              onDetails: (_) {},
              exportPdf: (ids) =>
                  api.call('/audit-events/pdf', body: {'ids': ids}),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump();
      await tester.ensureVisible(find.text('Download PDF'));
      await tester.tap(find.text('Download PDF'));
      await tester.pump();
      expect(find.text('Preparing PDF...'), findsOneWidget);
      await tester.tap(find.text('Preparing PDF...'));
      await tester.pump();
      expect(exports, 1);
      if (outcome == 'expired') {
        api.expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
      }
      response.complete(
        outcome == 'denied'
            ? http.Response(jsonEncode({'message': 'Forbidden'}), 403)
            : http.Response(
                jsonEncode({
                  'data': {
                    'fileName': 'afaq-audit-synthetic.pdf',
                    'base64': base64Encode(utf8.encode('%PDF-1.4\n%%EOF')),
                  },
                }),
                200,
              ),
      );
      await tester.pumpAndSettle();
      expect(
        downloads,
        outcome == 'success' ? ['afaq-audit-synthetic.pdf'] : isEmpty,
      );
      expect(
        find.text(
          'PDF unavailable. Refresh and check your access before trying again.',
        ),
        outcome == 'success' ? findsNothing : findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'second',
      );
      expect(tester.takeException(), isNull);
      // Complete the browser Blob URL cleanup timer.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
