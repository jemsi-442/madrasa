import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_layout.dart';
import 'mobile_welcome_page.dart';
import 'app_state.dart';
import 'foundation_ui.dart';
import 'public_pages.dart';
import 'office_help_page.dart';
import 'public_information_page.dart';
import 'registration_page.dart';
import 'workspace.dart';
import 'admin_theme.dart';

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
          '/contact' ||
          '/forgot-password' ||
          '/parent-access' => OfficeHelpScreen(
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
      builder: (context, child) => AppLayoutScope(
        layout: widget.layout ?? resolveAppLayout(),
        child: child!,
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSansDisplay',
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          primary: ink,
          secondary: gold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'NotoSerifDisplay',
            fontSize: 49,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.12,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'NotoSerifDisplay',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.16,
          ),
          titleLarge: TextStyle(
            fontFamily: 'NotoSansDisplay',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: gold, width: 1.7),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: line),
          ),
        ),
      ),
      routes: {
        '/': (context) => routePage(context, '/'),
        '/login': (context) => routePage(context, '/login'),
        '/register': (context) => routePage(context, '/register'),
        '/terms': (context) => routePage(context, '/terms'),
        '/privacy': (context) => routePage(context, '/privacy'),
        '/contact': (context) => routePage(context, '/contact'),
        '/forgot-password': (context) => routePage(context, '/forgot-password'),
        '/parent-access': (context) => routePage(context, '/parent-access'),
      },
    );
  }
}
