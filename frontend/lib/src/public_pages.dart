import 'package:flutter/material.dart';

import 'app_state.dart';
import 'foundation_ui.dart';

typedef PublicNavigate = void Function(String path);

class PublicFrame extends StatelessWidget {
  const PublicFrame({
    super.key,
    required this.path,
    required this.onNavigate,
    required this.child,
  });

  final String path;
  final PublicNavigate onNavigate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      backgroundColor: paper,
      body: Column(
        children: [
          Container(
            height: narrow ? 70 : 86,
            color: ink,
            padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 42),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Row(
                  children: [
                    Expanded(child: BrandMark(compact: narrow, light: true)),
                    if (!narrow) ...[
                      _HeaderLink(
                        label: 'Home',
                        selected: path == '/',
                        onTap: () => onNavigate('/'),
                      ),
                      const SizedBox(width: 14),
                      _HeaderLink(
                        label: 'Sign in',
                        selected: path == '/login',
                        onTap: () => onNavigate('/login'),
                      ),
                      const SizedBox(width: 18),
                    ],
                    if (narrow && path == '/')
                      TextButton(
                        onPressed: () => onNavigate('/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Sign in'),
                      )
                    else if (narrow)
                      TextButton.icon(
                        onPressed: () => onNavigate('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Home'),
                      )
                    else if (path != '/register')
                      OutlinedButton(
                        onPressed: () => onNavigate('/register'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x99D7BB76)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Join us'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: PatternBackdrop(child: child)),
          const _PublicFooter(),
        ],
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? const Color(0xFFEACF94) : Colors.white70,
      ),
      child: Text(label),
    );
  }
}

class _PublicFooter extends StatelessWidget {
  const _PublicFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ink,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Text(
        '© ${DateTime.now().year} Modern Islamic Foundation. All rights reserved.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key, required this.onNavigate});

  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return PublicFrame(
      path: '/',
      onNavigate: onNavigate,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 42 : 20,
                    wide ? 62 : 25,
                    wide ? 42 : 20,
                    62,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wide)
                        Row(
                          children: [
                            Expanded(
                              flex: 10,
                              child: _HomeMessage(
                                onJoin: () => onNavigate('/register'),
                              ),
                            ),
                            const SizedBox(width: 50),
                            const Expanded(flex: 9, child: _HomeArtwork()),
                          ],
                        )
                      else ...[
                        _HomeMessage(onJoin: () => onNavigate('/register')),
                        const SizedBox(height: 34),
                        const _HomeArtwork(),
                      ],
                      const SizedBox(height: 70),
                      const SectionLabel('Learning at every stage'),
                      const SizedBox(height: 11),
                      Text(
                        'A place to learn and belong.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 25),
                      const _HomeAreas(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Faith. Learning. Possibility.'),
        const SizedBox(height: 20),
        Text(
          'Grow in knowledge.\nGrounded in faith.',
          style: TextStyle(
            fontFamily: 'NotoSerifDisplay',
            fontSize: narrow ? 39 : 62,
            height: 1.12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 23),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: const Text(
            'From a child’s first lesson to lifelong study, learning has a home here.',
            style: TextStyle(color: muted, fontSize: 17, height: 1.55),
          ),
        ),
        const SizedBox(height: 31),
        FilledButton.icon(
          onPressed: onJoin,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          label: const Text('Join the foundation'),
        ),
      ],
    );
  }
}

class _HomeArtwork extends StatelessWidget {
  const _HomeArtwork();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Container(
      height: compact ? 310 : 510,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF6), Color(0xFFF4EAD8)],
        ),
        border: Border.all(color: const Color(0xFFE7D9BC)),
        borderRadius: BorderRadius.circular(compact ? 27 : 36),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _HeritagePainter()),
          ),
          Positioned(
            top: compact ? 18 : 32,
            left: compact ? 20 : 34,
            child: const SectionLabel('Modern Islamic Foundation'),
          ),
          Center(
            child: Container(
              width: compact ? 177 : 270,
              height: compact ? 177 : 270,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2412263F),
                    blurRadius: 34,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(9),
              child: ClipOval(child: Image.asset('assets/mif-logo.png')),
            ),
          ),
          Positioned(
            bottom: compact ? 20 : 34,
            right: compact ? 20 : 34,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.87),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE9DDC5)),
              ),
              child: const Text(
                'Where innovation meets faith',
                style: TextStyle(color: ink, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAreas extends StatelessWidget {
  const _HomeAreas();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: width,
              child: const _AreaCard(
                icon: Icons.menu_book_rounded,
                title: 'Madrasa',
                description: 'A thoughtful start for young learners.',
                accent: forest,
              ),
            ),
            SizedBox(
              width: width,
              child: const _AreaCard(
                icon: Icons.family_restroom_rounded,
                title: 'Families',
                description: 'Stay close to each child’s journey.',
                accent: gold,
              ),
            ),
            SizedBox(
              width: width,
              child: const _AreaCard(
                icon: Icons.play_lesson_outlined,
                title: 'Online courses',
                description: 'Keep learning wherever life takes you.',
                accent: blue,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.state,
    required this.onNavigate,
    required this.onSignedIn,
  });

  final AppState state;
  final PublicNavigate onNavigate;
  final VoidCallback onSignedIn;

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
    final signedIn = await widget.state.signIn(
      loginController.text,
      passwordController.text,
    );
    if (signedIn && mounted) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return PublicFrame(
      path: '/login',
      onNavigate: widget.onNavigate,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 36 : 18,
            vertical: wide ? 48 : 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SurfacePanel(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Row(
                  children: [
                    if (wide) const Expanded(flex: 9, child: _LoginStory()),
                    Expanded(
                      flex: 11,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 56 : 24,
                          vertical: wide ? 58 : 35,
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionLabel('Your account'),
                              const SizedBox(height: 14),
                              Text(
                                'Welcome back.',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 9),
                              const Text(
                                'Sign in to continue your journey.',
                                style: TextStyle(color: muted, fontSize: 15),
                              ),
                              const SizedBox(height: 34),
                              TextFormField(
                                controller: loginController,
                                autofillHints: const [AutofillHints.username],
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number or email',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (value) =>
                                    value?.trim().isEmpty ?? true
                                    ? 'Enter your phone number or email.'
                                    : null,
                              ),
                              const SizedBox(height: 17),
                              TextFormField(
                                controller: passwordController,
                                autofillHints: const [AutofillHints.password],
                                obscureText: !revealPassword,
                                textInputAction: TextInputAction.done,
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
                                validator: (value) => value?.isEmpty ?? true
                                    ? 'Enter your password.'
                                    : null,
                              ),
                              if (widget.state.error != null) ...[
                                const SizedBox(height: 17),
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1EE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.state.error!,
                                      style: const TextStyle(
                                        color: Color(0xFF9B3528),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 27),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: widget.state.busy ? null : submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: ink,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 19,
                                    ),
                                  ),
                                  iconAlignment: IconAlignment.end,
                                  icon: widget.state.busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('Sign in'),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Center(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'New here?',
                                      style: TextStyle(color: muted),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          widget.onNavigate('/register'),
                                      child: const Text('Start registration'),
                                    ),
                                  ],
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
    );
  }
}

class _LoginStory extends StatelessWidget {
  const _LoginStory();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 592,
      decoration: const BoxDecoration(color: ink),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _HeritagePainter(dark: true)),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/mif-logo.png',
                    width: 94,
                    height: 94,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                const SectionLabel(
                  'Modern Islamic Foundation',
                  color: Color(0xFFE7C880),
                ),
                const SizedBox(height: 19),
                const Text(
                  'A familiar place\nto continue.',
                  style: TextStyle(
                    fontFamily: 'NotoSerifDisplay',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 42,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Your learning, your family, your next step.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeritagePainter extends CustomPainter {
  const _HeritagePainter({this.dark = false});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = dark ? const Color(0x30D9B76D) : const Color(0x80CDAE70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width * 0.55, size.height * 0.48);
    for (var i = 0; i < 5; i++) {
      final radius = 80.0 + i * 46;
      final arch = Path()
        ..moveTo(center.dx - radius, size.height)
        ..lineTo(center.dx - radius, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy - radius * 1.45,
          center.dx + radius,
          center.dy,
        )
        ..lineTo(center.dx + radius, size.height);
      canvas.drawPath(arch, stroke);
    }

    final skyline = Paint()
      ..color = dark ? const Color(0x1425A0A0) : const Color(0x88E9D9BC);
    final base = size.height * 0.89;
    canvas.drawRect(Rect.fromLTRB(0, base, size.width, size.height), skyline);
    for (final point in [0.13, 0.32, 0.73, 0.91]) {
      final x = size.width * point;
      canvas.drawRect(Rect.fromLTWH(x - 3, base - 62, 6, 62), skyline);
      final peak = Path()
        ..moveTo(x - 7, base - 62)
        ..lineTo(x, base - 80)
        ..lineTo(x + 7, base - 62)
        ..close();
      canvas.drawPath(peak, skyline);
    }
    final dome = Path()
      ..moveTo(size.width * 0.37, base)
      ..lineTo(size.width * 0.37, base - 34)
      ..quadraticBezierTo(
        size.width * 0.5,
        base - 112,
        size.width * 0.63,
        base - 34,
      )
      ..lineTo(size.width * 0.63, base)
      ..close();
    canvas.drawPath(dome, skyline);
  }

  @override
  bool shouldRepaint(covariant _HeritagePainter oldDelegate) =>
      oldDelegate.dark != dark;
}
