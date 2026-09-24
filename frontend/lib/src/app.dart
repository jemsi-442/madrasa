import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'foundation_ui.dart';
import 'workspace.dart';

const mifNavy = ink;
const mifGold = gold;
const mifCream = paper;

class MifApp extends StatefulWidget {
  const MifApp({super.key, this.state});

  final AppState? state;

  @override
  State<MifApp> createState() => _MifAppState();
}

class _MifAppState extends State<MifApp> {
  late final AppState appState = widget.state ?? AppState(MifApiClient());
  bool get ownsState => widget.state == null;
  bool showLogin = false;

  @override
  void dispose() {
    if (ownsState) appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modern Islamic Foundation',
      debugShowCheckedModeBanner: false,
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
      home: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.session != null) return WorkspaceScreen(state: appState);
          return showLogin
              ? LoginScreen(
                  state: appState,
                  onBack: () => setState(() => showLogin = false),
                )
              : PublicHomeScreen(
                  onSignIn: () => setState(() => showLogin = true),
                );
        },
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/mif-logo.png',
            width: compact ? 43 : 54,
            height: compact ? 43 : 54,
            fit: BoxFit.cover,
            semanticLabel: 'Modern Islamic Foundation logo',
          ),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            'MODERN ISLAMIC\nFOUNDATION',
            style: TextStyle(
              color: light ? Colors.white : ink,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
              height: 1.17,
            ),
          ),
        ),
      ],
    );
  }
}

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: ink,
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 20 : 48,
              vertical: 13,
            ),
            child: Row(
              children: [
                const Expanded(child: BrandMark(compact: true, light: true)),
                TextButton(
                  onPressed: onSignIn,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PatternBackdrop(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1190),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 22 : 56,
                        narrow ? 48 : 70,
                        narrow ? 22 : 56,
                        48,
                      ),
                      child: Column(
                        children: [
                          if (narrow)
                            _MobileWelcome(onSignIn: onSignIn)
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _WelcomeCopy(onSignIn: onSignIn),
                                ),
                                const SizedBox(width: 62),
                                const Expanded(
                                  flex: 5,
                                  child: _BrandShowcase(),
                                ),
                              ],
                            ),
                          const SizedBox(height: 56),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 18,
                            runSpacing: 16,
                            children: const [
                              _HomeArea(Icons.school_outlined, 'School'),
                              _HomeArea(
                                Icons.auto_stories_outlined,
                                'Learning',
                              ),
                              _HomeArea(
                                Icons.family_restroom_rounded,
                                'Families',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _FoundationFooter(),
        ],
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Modern Islamic Foundation'),
        const SizedBox(height: 24),
        Text(
          'Knowledge today.\nBrighter tomorrows.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        const Text(
          'One place for school, family and online learning.',
          style: TextStyle(color: muted, fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onSignIn,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 19),
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Open your account'),
        ),
      ],
    );
  }
}

class _MobileWelcome extends StatelessWidget {
  const _MobileWelcome({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/mif-logo.png',
          width: 155,
          height: 155,
          semanticLabel: 'Modern Islamic Foundation logo',
        ),
        const SizedBox(height: 24),
        const SectionLabel('Faith • Learning • Future'),
        const SizedBox(height: 20),
        Text(
          'Knowledge today.\nBrighter tomorrows.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 15),
        const Text(
          'School, family and online learning in one place.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Open your account'),
          ),
        ),
      ],
    );
  }
}

class _BrandShowcase extends StatelessWidget {
  const _BrandShowcase();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 460,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1612263F),
            blurRadius: 48,
            offset: Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: PatternBackdrop(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/mif-logo.png',
              width: 160,
              height: 160,
              semanticLabel: 'Modern Islamic Foundation logo',
            ),
            const SizedBox(height: 24),
            const Text(
              'Where innovation meets faith',
              style: TextStyle(
                color: ink,
                fontFamily: 'NotoSerifDisplay',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(width: 45, height: 2, color: gold),
            const SizedBox(height: 16),
            const Text(
              'Learn. Grow. Belong.',
              style: TextStyle(color: muted, letterSpacing: 2.4, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeArea extends StatelessWidget {
  const _HomeArea(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: gold, size: 23),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FoundationFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ink,
      padding: const EdgeInsets.all(13),
      child: Text(
        '© ${DateTime.now().year} MODERN ISLAMIC FOUNDATION. All rights reserved.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state, required this.onBack});

  final AppState state;
  final VoidCallback onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  bool revealPassword = false;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.state.busy || !formKey.currentState!.validate()) return;
    await widget.state.signIn(loginController.text, passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        title: const BrandMark(compact: true, light: true),
        leading: IconButton(
          tooltip: 'Back to home',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: PatternBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SurfacePanel(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    children: [
                      if (wide)
                        Expanded(
                          child: Container(
                            height: 565,
                            color: ink,
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/mif-logo.png',
                                  width: 106,
                                  height: 106,
                                ),
                                const SizedBox(height: 36),
                                const SectionLabel(
                                  'Your learning space',
                                  color: Color(0xFFE4C67F),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Welcome back.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'NotoSerifDisplay',
                                    fontSize: 39,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Pick up where you left off.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: wide ? 48 : 25,
                            vertical: wide ? 42 : 38,
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SectionLabel('Sign in'),
                                const SizedBox(height: 12),
                                Text(
                                  'Welcome back',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 9),
                                const Text(
                                  'Use the details shared with you.',
                                  style: TextStyle(color: muted),
                                ),
                                const SizedBox(height: 32),
                                TextFormField(
                                  controller: loginController,
                                  autofillHints: const [AutofillHints.username],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone number or email',
                                    prefixIcon: Icon(
                                      Icons.alternate_email_rounded,
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().isEmpty ?? true)
                                      ? 'Enter your phone number or email.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  obscureText: !revealPassword,
                                  onFieldSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: revealPassword
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: () => setState(
                                        () => revealPassword = !revealPassword,
                                      ),
                                      icon: Icon(
                                        revealPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) => (value?.isEmpty ?? true)
                                      ? 'Enter your password.'
                                      : null,
                                ),
                                if (widget.state.error != null) ...[
                                  const SizedBox(height: 17),
                                  Semantics(
                                    liveRegion: true,
                                    child: SurfacePanel(
                                      color: const Color(0xFFFFF3F0),
                                      padding: const EdgeInsets.all(13),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Color(0xFFA43728),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.state.error!,
                                              style: const TextStyle(
                                                color: Color(0xFFA43728),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 25),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: widget.state.busy
                                        ? null
                                        : submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: ink,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 19,
                                      ),
                                    ),
                                    child: widget.state.busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _FoundationFooter(),
    );
  }
}
