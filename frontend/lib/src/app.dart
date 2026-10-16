import 'package:flutter/material.dart';
import 'design_theme.dart';

import 'api_client.dart';
import 'app_layout.dart';
import 'mobile_welcome_page.dart';
import 'app_state.dart';
import 'public_pages.dart';
import 'office_help_page.dart';
import 'public_information_page.dart';
import 'registration_page.dart';
import 'workspace.dart';
import 'admin_theme.dart';
import 'keyboard_scrolling.dart';
import 'platform_console.dart';
import 'school_invitation_page.dart';
import 'page_selection.dart';
import 'family_registration_page.dart';

class MifApp extends StatefulWidget {
  const MifApp({super.key, this.state, this.layout});

  final AppState? state;
  final AppLayout? layout;

  @override
  State<MifApp> createState() => _MifAppState();
}

class _MifAppState extends State<MifApp> {
  late final AppState appState = widget.state ?? AppState(MifApiClient());
  bool get ownsState => widget.state == null;

  @override
  void initState() {
    super.initState();
    appState.restoreSession();
  }

  @override
  void dispose() {
    if (ownsState) appState.dispose();
    super.dispose();
  }

  Widget routePage(BuildContext context, String path) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (appState.restoring || appState.restorationError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appState.restoring) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text('Reconnecting to your account...'),
                    ] else ...[
                      Text(
                        appState.restorationError!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: appState.restoreSession,
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: appState.signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        final informationPage = path == '/terms' || path == '/privacy';
        if (appState.companyApi != null && !informationPage) {
          return PlatformConsole(
            key: ObjectKey(appState.companyApi),
            api: appState.companyApi,
            onSignedOut: () async {
              await appState.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          );
        }
        if (appState.session != null && !informationPage) {
          final workspace = WorkspaceScreen(
            key: ValueKey(
              '${appState.session!.userId}-${appState.session!.role}',
            ),
            state: appState,
          );
          return ['ADMIN', 'TEACHER', 'PARENT'].contains(appState.session!.role)
              ? Theme(data: adminTheme(Theme.of(context)), child: workspace)
              : workspace;
        }

        void navigate(String nextPath) {
          appState.clearError();
          if (nextPath == '/') {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (ModalRoute.of(context)?.settings.name != nextPath) {
            Navigator.of(context).pushNamed(nextPath);
          }
        }

        return switch (path) {
          '/terms' || '/privacy' => PublicInformationScreen(
            document: path == '/terms'
                ? PublicDocument.terms
                : PublicDocument.privacy,
            onNavigate: navigate,
          ),
          '/login' => LoginScreen(
            state: appState,
            onNavigate: navigate,
            onSignedIn: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          '/register' => RegistrationScreen(
            state: appState,
            onNavigate: navigate,
            onRegistered: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          '/parent-access' => FamilyRegistrationScreen(
            api: appState.api,
            onNavigate: navigate,
          ),
          '/contact' || '/forgot-password' => OfficeHelpScreen(
            api: appState.api,
            onNavigate: navigate,
            path: path,
          ),
          _ =>
            AppLayoutScope.isMobile(context)
                ? MobileWelcomeScreen(onNavigate: navigate)
                : PublicHomeScreen(onNavigate: navigate),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modern Islamic Foundation',
      debugShowCheckedModeBanner: false,
      shortcuts: (widget.layout ?? resolveAppLayout()) == AppLayout.website
          ? pageKeyboardShortcuts
          : null,
      actions: pageKeyboardActions,
      builder: (context, child) => AppLayoutScope(
        layout: widget.layout ?? resolveAppLayout(),
        child: child!,
      ),
      theme: buildAfaqTheme(),
      routes:
          <String, WidgetBuilder>{
            '/platform': (context) => routePage(context, '/login'),
            '/school-invitation': (_) => const SchoolInvitationPage(),
            '/': (context) => routePage(context, '/'),
            '/login': (context) => routePage(context, '/login'),
            '/register': (context) => routePage(context, '/register'),
            '/terms': (context) => routePage(context, '/terms'),
            '/privacy': (context) => routePage(context, '/privacy'),
            '/contact': (context) => routePage(context, '/contact'),
            '/forgot-password': (context) =>
                routePage(context, '/forgot-password'),
            '/parent-access': (context) => routePage(context, '/parent-access'),
          }.map(
            (path, builder) => MapEntry(
              path,
              (context) => PageSelection(child: builder(context)),
            ),
          ),
    );
  }
}
