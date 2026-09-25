import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/browser_state.dart';
import 'package:mif_app/src/public_pages.dart';
import 'package:mif_app/src/workspace.dart';

class MemoryBrowserState extends BrowserState {
  final values = <String, String>{};
  @override
  String? read(String key, {bool shared = false}) => values['$shared:$key'];
  @override
  void write(String key, String? value, {bool shared = false}) {
    if (value == null) {
      values.remove('$shared:$key');
    } else {
      values['$shared:$key'] = value;
    }
  }
}

http.Response sessionResponse({String user = '17', String role = 'TEACHER'}) =>
    http.Response(
      jsonEncode({
        'data': {
          'accessToken': 'memory-only-access',
          'user': {'id': user, 'fullName': 'Teacher Amina', 'role': role},
        },
      }),
      200,
    );

AppState stateFor(
  Future<http.Response> Function(http.Request) handler, {
  MemoryBrowserState? storage,
}) => AppState(
  MifApiClient(
    client: MockClient(handler),
    baseUrl: 'https://school.test',
    browserAuth: true,
  ),
  browserState: storage ?? MemoryBrowserState(),
);

void main() {
  test(
    'browser loopback API follows the browser host for same-site cookies',
    () {
      expect(
        browserApiBaseUrl('', Uri.parse('http://localhost:8080')),
        'http://localhost:4000',
      );
      expect(
        browserApiBaseUrl(
          'http://127.0.0.1:4000',
          Uri.parse('http://localhost:8080'),
        ),
        'http://localhost:4000',
      );
      expect(
        browserApiBaseUrl('', Uri.parse('https://school.test')),
        'https://school.test',
      );
      expect(
        browserApiBaseUrl(
          'https://api.school.test',
          Uri.parse('https://school.test'),
        ),
        'https://api.school.test',
      );
    },
  );

  test(
    'browser login, registration, refresh and logout use cookies, not stored tokens',
    () async {
      final paths = <String>[];
      final api = MifApiClient(
        browserAuth: true,
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['X-MIF-Browser'], '1');
          expect(
            (jsonDecode(request.body) as Map).containsKey('refreshToken'),
            isFalse,
          );
          return sessionResponse();
        }),
      );
      addTearDown(api.dispose);
      expect((await api.login('user', 'password')).refreshToken, isEmpty);
      await api.register(
        fullName: 'Learner',
        email: 'l@example.test',
        password: 'password',
        confirmPassword: 'password',
      );
      await api.refresh('not-sent');
      await api.logout('not-sent');
      expect(
        paths,
        [
          'login',
          'register',
          'refresh',
          'logout',
        ].map((p) => '/api/auth/browser/$p').toList(),
      );
    },
  );

  testWidgets(
    'reload waits for the server then restores the selected allowed page',
    (tester) async {
      final storage = MemoryBrowserState();
      final first = stateFor((_) async => sessionResponse(), storage: storage);
      await first.signIn('amina', 'password');
      first.rememberSection('/api/teacher-workspace/classes');
      first.dispose();
      final response = Completer<http.Response>();
      final restored = stateFor((request) async {
        if (request.url.path.endsWith('/refresh')) return response.future;
        return http.Response('{"data":[]}', 200);
      }, storage: storage);
      addTearDown(restored.dispose);
      await tester.pumpWidget(MifApp(state: restored));
      await tester.pump();
      expect(find.text('Reconnecting to your account...'), findsOneWidget);
      expect(find.byType(PublicHomeScreen), findsNothing);
      expect(find.byType(WorkspaceScreen), findsNothing);
      response.complete(sessionResponse());
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(find.text('My weekly schedule'), findsOneWidget);
      expect(restored.session?.userId, '17');
      expect(storage.values.values, isNot(contains('memory-only-access')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an unavailable server shows retry, not a silent return to home',
    (tester) async {
      var offline = true;
      final state = stateFor((request) async {
        if (request.url.path.endsWith('/refresh')) {
          if (offline) throw http.ClientException('Offline');
          return sessionResponse();
        }
        return http.Response('{"data":{}}', 200);
      });
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(PublicHomeScreen), findsNothing);
      expect(find.byType(WorkspaceScreen), findsNothing);
      offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(state.restorationError, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expired or revoked sessions never show the workspace', (
    tester,
  ) async {
    final state = stateFor(
      (_) async => http.Response('{"message":"Session expired"}', 401),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state));
    await tester.pumpAndSettle();
    expect(state.session, isNull);
    expect(state.restorationError, isNull);
    expect(find.byType(PublicHomeScreen), findsOneWidget);
    expect(find.byType(WorkspaceScreen), findsNothing);
  });

  test('late restoration cannot resurrect a signed-out account', () async {
    final response = Completer<http.Response>();
    final state = stateFor(
      (request) async => request.url.path.endsWith('/refresh')
          ? response.future
          : http.Response('{}', 200),
    );
    addTearDown(state.dispose);
    final restoring = state.restoreSession();
    await state.signOut();
    response.complete(sessionResponse());
    await restoring;
    expect(state.session, isNull);
    expect(state.restoring, isFalse);
  });

  test(
    'offline logout remains signed out after reload and clears remembered page',
    () async {
      final storage = MemoryBrowserState();
      final first = stateFor((request) async {
        if (request.url.path.endsWith('/logout')) {
          throw http.ClientException('Offline');
        }
        return sessionResponse();
      }, storage: storage);
      await first.signIn('user', 'password');
      first.rememberSection('/api/teacher-workspace/classes');
      await first.signOut();
      first.dispose();
      final paths = <String>[];
      final reloaded = stateFor((request) async {
        paths.add(request.url.path);
        return sessionResponse();
      }, storage: storage);
      addTearDown(reloaded.dispose);
      await reloaded.restoreSession();
      expect(reloaded.session, isNull);
      expect(paths, isNot(contains('/api/auth/browser/refresh')));
      await reloaded.signIn('user', 'password');
      expect(reloaded.rememberedSection, isNull);
      expect(storage.values, isEmpty);
    },
  );

  testWidgets('remembered pages are checked against the current role', (
    tester,
  ) async {
    final storage = MemoryBrowserState();
    storage.write(
      'mif.page:https://school.test:17:TEACHER',
      '/api/admin/overview',
    );
    final state = stateFor(
      (request) async => request.url.path.endsWith('/refresh')
          ? sessionResponse()
          : http.Response('{"data":{}}', 200),
      storage: storage,
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Assalamu alaikum, Teacher Amina'), findsOneWidget);
    expect(find.text('Donations'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'remembered section never transfers to another signed-in user',
    () async {
      final storage = MemoryBrowserState();
      var user = '17';
      final state = stateFor(
        (_) async => sessionResponse(user: user),
        storage: storage,
      );
      addTearDown(state.dispose);
      await state.signIn('first', 'password');
      state.rememberSection('/api/teacher-workspace/students');
      user = '18';
      await state.signIn('second', 'password');
      expect(state.rememberedSection, isNull);
    },
  );
  test(
    'another tab signing out prevents new requests and restoration',
    () async {
      final storage = MemoryBrowserState();
      final paths = <String>[];
      final state = stateFor((request) async {
        paths.add(request.url.path);
        return sessionResponse();
      }, storage: storage);
      addTearDown(state.dispose);
      await state.signIn('user', 'password');
      storage.write('mif.signed-out:https://school.test', '1', shared: true);
      await expectLater(
        state.load('/api/teacher-workspace/classes'),
        throwsA(isA<ApiException>()),
      );
      expect(state.session, isNull);
      expect(paths, ['/api/auth/browser/login']);
      await state.restoreSession();
      expect(paths, ['/api/auth/browser/login']);
    },
  );
}
