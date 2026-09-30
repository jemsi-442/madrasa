import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_media_dialog.dart';

Map<String, dynamic> response({
  String? url,
  String kind = 'VIDEO',
  DateTime? expiry,
  String status = 'READY',
}) => {
  'asset': {'title': 'Practice recording', 'downloadAllowed': false},
  'delivery': {
    'status': status,
    'playerKind': kind,
    'inlineUrl':
        url ?? 'https://school.test/api/learner/assets/3/deliver?token=signed',
    'expiresAt': (expiry ?? DateTime.now().add(const Duration(minutes: 5)))
        .toIso8601String(),
  },
};

LessonMediaDelivery parse(Map<String, dynamic> raw) =>
    LessonMediaDelivery.parse(
      raw,
      apiBaseUrl: 'https://school.test',
      assetId: '3',
    );

Future<void> host(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: adminTheme(ThemeData()),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Widget fakePlayer(
  LessonMediaDelivery delivery,
  VoidCallback ready,
  VoidCallback failed,
) => Wrap(
  children: [
    Text('Native ${delivery.kind} controls'),
    TextButton(onPressed: ready, child: const Text('Simulate ready')),
    TextButton(onPressed: failed, child: const Text('Simulate failure')),
  ],
);

Future<void> tap(WidgetTester tester, String title) async {
  final found = find.text(title);
  await tester.ensureVisible(found);
  await tester.tap(found);
  await tester.pumpAndSettle();
}

void main() {
  test('accepts only matching signed API delivery paths', () {
    expect(parse(response()).kind, 'VIDEO');
    expect(
      parse(
        response(url: '/api/learner/assets/3/deliver?token=signed'),
      ).uri.host,
      'school.test',
    );
    expect(parse(response(kind: 'EMBED')).kind, 'EMBED');
    expect(parse(response(kind: 'AUDIO')).downloadAllowed, isFalse);
  });
  for (final bad in [
    'https://evil.test/api/learner/assets/3/deliver?token=signed',
    'https://school.test:8080/api/learner/assets/3/deliver?token=signed',
    'https://school.test/api/learner/assets/4/deliver?token=signed',
    'https://school.test/api/learner/assets/3/deliver',
    'https://school.test/api/learner/assets/3/deliver?token=',
    'https://school.test/api/learner/assets/3/deliver?token=a&token=b',
    'https://school.test/api/learner/assets/3/deliver?token=a&redirect=evil',
    'https://school.test/api/learner/assets/3/deliver?token=a#fragment',
    'https://user:password@school.test/api/learner/assets/3/deliver?token=a',
    'javascript:alert(1)',
    '',
  ]) {
    test(
      'rejects unsafe inline source $bad',
      () => expect(() => parse(response(url: bad)), throwsFormatException),
    );
  }
  test('rejects expired, unready and unsupported deliveries', () {
    expect(
      () => parse(response(expiry: DateTime(2000))),
      throwsFormatException,
    );
    expect(
      () => parse(response(status: 'PENDING_SOURCE')),
      throwsFormatException,
    );
    expect(() => parse(response(kind: 'EXTERNAL')), throwsFormatException);
    expect(() => parse({}), throwsFormatException);
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('media controls and close action fit width $width', (
      tester,
    ) async {
      final paths = <String>[];
      await host(
        tester,
        LessonMediaDialog(
          assetId: '3',
          apiBaseUrl: 'https://school.test',
          load: (path) async {
            paths.add(path);
            return response();
          },
          surfaceBuilder: fakePlayer,
        ),
        width: width,
      );
      expect(find.text('Practice recording'), findsOneWidget);
      await tap(tester, 'Simulate ready');
      expect(find.textContaining('Use the player controls'), findsOneWidget);
      expect(
        find.textContaining('does not mark the lesson complete'),
        findsOneWidget,
      );
      expect(paths, ['/api/learner/assets/3/open']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'denied requests hide player and external link; retry reauthorizes',
    (tester) async {
      var attempts = 0;
      await host(
        tester,
        LessonMediaDialog(
          assetId: '3',
          apiBaseUrl: 'https://school.test',
          load: (_) async {
            if (++attempts == 1) throw ApiException('Access has expired', 403);
            return response();
          },
          surfaceBuilder: fakePlayer,
        ),
      );
      expect(find.text('Access has expired'), findsOneWidget);
      expect(find.text('Open in browser'), findsNothing);
      expect(find.text('Native VIDEO controls'), findsNothing);
      await tap(tester, 'Reload player');
      await tap(tester, 'Simulate ready');
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('reload removes old player before a new authorization result', (
    tester,
  ) async {
    final pending = Completer<dynamic>();
    var calls = 0;
    await host(
      tester,
      LessonMediaDialog(
        assetId: '3',
        apiBaseUrl: 'https://school.test',
        load: (_) async {
          calls++;
          if (calls == 1) return response();
          return await pending.future;
        },
        surfaceBuilder: fakePlayer,
      ),
    );
    expect(calls, 1);
    await tap(tester, 'Simulate ready');
    expect(calls, 1);
    await tester.tap(find.text('Reload player'));
    await tester.pump();
    expect(find.text('Native VIDEO controls'), findsNothing);
    expect(find.text('Open in browser'), findsNothing);
    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' / '),
    );
    await tester.tap(find.text('Reload player'));
    expect(calls, 2);
    pending.completeError(ApiException('Permission removed', 403));
    await tester.pumpAndSettle();
    expect(find.text('Permission removed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'late authorization response after closing cannot create a player',
    (tester) async {
      final pending = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: LessonMediaDialog(
            assetId: '3',
            apiBaseUrl: 'https://school.test',
            load: (_) => pending.future,
            surfaceBuilder: fakePlayer,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(response());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('playback errors and slow loading offer retry', (tester) async {
    await host(
      tester,
      LessonMediaDialog(
        assetId: '3',
        apiBaseUrl: 'https://school.test',
        load: (_) async => response(),
        surfaceBuilder: fakePlayer,
      ),
    );
    await tester.pump(const Duration(seconds: 16));
    expect(find.textContaining('taking longer to load'), findsOneWidget);
    await tap(tester, 'Simulate ready');
    expect(find.textContaining('taking longer to load'), findsNothing);
    await tap(tester, 'Simulate failure');
    expect(find.textContaining('could not be displayed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final kind in ['PDF', 'IMAGE', 'TEXT', 'AUDIO', 'VIDEO', 'EMBED']) {
    testWidgets(
      '$kind uses the authorized in-app surface with no browser action',
      (tester) async {
        await host(
          tester,
          LessonMediaDialog(
            assetId: '3',
            apiBaseUrl: 'https://school.test',
            load: (_) async => response(kind: kind),
            surfaceBuilder: fakePlayer,
          ),
          width: 320,
        );
        expect(find.text('Native $kind controls'), findsOneWidget);
        await tap(tester, 'Simulate ready');
        expect(find.text('Open in browser'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test(
    'native embeds block top-level navigation outside the signed route and provider player',
    () {
      final signed = parse(response(kind: 'EMBED')).uri;
      for (final allowed in [
        signed.toString(),
        'about:blank',
        'https://www.youtube-nocookie.com/embed/abcdefghijk',
        'https://player.vimeo.com/video/1234?h=secret',
      ]) {
        expect(
          lessonEmbedNavigationAllowed(allowed, signed, isMainFrame: true),
          isTrue,
        );
      }
      for (final blocked in [
        'https://evil.test',
        'https://www.youtube.com/watch?v=abcdefghijk',
        'intent://video',
        'javascript:alert(1)',
        'https://player.vimeo.com.evil.test/video/1234',
        'https://user:secret@player.vimeo.com/video/1234',
        'https://school.test/api/learner/assets/4/deliver?token=signed',
      ]) {
        expect(
          lessonEmbedNavigationAllowed(blocked, signed, isMainFrame: true),
          isFalse,
        );
      }
    },
  );
  testWidgets(
    'unsupported attachments stay inside with an explanation and retry',
    (tester) async {
      await host(
        tester,
        LessonMediaDialog(
          assetId: '3',
          apiBaseUrl: 'https://school.test',
          load: (_) async => response(kind: 'EXTERNAL'),
          surfaceBuilder: fakePlayer,
        ),
      );
      expect(
        find.textContaining('cannot be displayed here yet'),
        findsOneWidget,
      );
      expect(find.text('Open in browser'), findsNothing);
      expect(find.text('Reload player'), findsOneWidget);
      expect(find.textContaining('Native EXTERNAL'), findsNothing);
    },
  );
  testWidgets('expired response never mounts inline media', (tester) async {
    await host(
      tester,
      LessonMediaDialog(
        assetId: '3',
        apiBaseUrl: 'https://school.test',
        load: (_) async => response(expiry: DateTime(2000)),
        surfaceBuilder: fakePlayer,
      ),
    );
    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.text('Native VIDEO controls'), findsNothing);
    expect(find.text('Open in browser'), findsNothing);
  });
}
