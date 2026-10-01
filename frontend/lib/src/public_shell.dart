import 'package:flutter/material.dart';

import 'app_layout.dart';
import 'public_entry_visuals.dart';
import 'public_palette.dart';

export 'public_palette.dart';

typedef PublicNavigate = void Function(String path);

ThemeData publicTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: publicCream,
  textTheme: Theme.of(context).textTheme.copyWith(
    headlineLarge: const TextStyle(
      fontFamily: 'NotoSansDisplay',
      color: publicInk,
      fontSize: 48,
      height: 1.12,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'NotoSansDisplay',
      color: publicInk,
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A97A9)),
    prefixIconColor: publicInk,
    suffixIconColor: publicMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: publicBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: publicBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: publicGold, width: 1.5),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: publicInk),
  ),
);

class PublicBrand extends StatelessWidget {
  const PublicBrand({
    super.key,
    this.light = false,
    this.stacked = false,
    this.compact = false,
  });

  final bool light;
  final bool stacked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(
        stacked
            ? 82
            : compact
            ? 38
            : 48,
      ),
      painter: _BrandPainter(light: light),
    );
    final name = Text(
      'Modern Islamic\nFoundation',
      textAlign: stacked ? TextAlign.center : TextAlign.left,
      style: TextStyle(
        color: light ? Colors.white : publicInk,
        fontFamily: 'NotoSansDisplay',
        fontWeight: FontWeight.w700,
        fontSize: stacked
            ? 28
            : compact
            ? 13
            : 17,
        height: 1.12,
        letterSpacing: -0.5,
      ),
    );
    return Semantics(
      label: publicBrandName,
      excludeSemantics: true,
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [mark, const SizedBox(height: 14), name],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                SizedBox(width: compact ? 9 : 13),
                Flexible(child: name),
              ],
            ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter({this.light = false});
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..color = const Color(0xFFC39743);
    canvas.drawPath(
      Path()
        ..moveTo(50, 2)
        ..lineTo(73, 26)
        ..lineTo(50, 49)
        ..lineTo(27, 26)
        ..close(),
      paint,
    );
    paint.color = light ? Colors.white : publicBrandBlue;
    canvas.drawPath(
      Path()
        ..moveTo(25, 29)
        ..cubicTo(10, 43, 3, 58, 5, 83)
        ..lineTo(29, 91)
        ..cubicTo(28, 73, 35, 63, 47, 53)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(75, 29)
        ..cubicTo(90, 43, 97, 58, 95, 83)
        ..lineTo(71, 91)
        ..cubicTo(72, 73, 65, 63, 53, 53)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.light != light;
}

class PublicHeaderBar extends StatelessWidget {
  const PublicHeaderBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return RepaintBoundary(
      child: Material(
        key: const ValueKey('public-header'),
        color: publicBrandBlue,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 36,
              vertical: 12,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1320,
                  minHeight: compact ? 52 : 64,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key, this.showDivider = false});

  final bool showDivider;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Material(
      key: const ValueKey('public-footer'),
      color: publicBrandBlue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider)
            const Divider(
              key: ValueKey('public-footer-divider'),
              height: 1,
              thickness: 1,
              color: Color(0xFF46617B),
            ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Text(
                '\u00a9 ${DateTime.now().year} $publicBrandName. All rights reserved.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE3EAF2),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GoldAction extends StatelessWidget {
  const GoldAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: fullWidth ? double.infinity : null,
    height: 52,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: publicGold,
        foregroundColor: Colors.white,
        disabledBackgroundColor: publicGold.withValues(alpha: 0.65),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansDisplay',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                if (icon != null) ...[
                  const SizedBox(width: 14),
                  Icon(icon, size: 20),
                ],
              ],
            ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: publicInk,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Semantics(label: label, child: child),
    ],
  );
}

class FormNotice extends StatelessWidget {
  const FormNotice(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF9B3528),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9B3528),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MobileBackButton extends StatelessWidget {
  const MobileBackButton({super.key, required this.onNavigate});

  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.maybePop();
      } else {
        onNavigate('/');
      }
    },
  );
}

class MobilePublicFrame extends StatelessWidget {
  const MobilePublicFrame({
    super.key,
    required this.onNavigate,
    required this.title,
    required this.child,
  });

  final PublicNavigate onNavigate;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: publicTheme(context),
    child: Scaffold(
      key: const ValueKey('mobile-auth-frame'),
      backgroundColor: publicCream,
      appBar: AppBar(
        backgroundColor: publicCream,
        leading: MobileBackButton(onNavigate: onNavigate),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: EntryBackdrop(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('auth-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: const EntryBackdrop(
                        dark: true,
                        child: Padding(
                          padding: EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PublicBrand(light: true, compact: true),
                              SizedBox(height: 18),
                              Text(
                                'Faith. Knowledge. Possibility.',
                                style: TextStyle(
                                  color: publicHeaderAccent,
                                  fontFamily: 'NotoSerifDisplay',
                                  fontSize: 19,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: publicBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x07092136),
                            blurRadius: 28,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.onNavigate,
    required this.child,
    this.registration = false,
    this.mobileTitle = 'Your account',
  });

  final PublicNavigate onNavigate;
  final Widget child;
  final bool registration;
  final String mobileTitle;

  @override
  Widget build(BuildContext context) => AppLayoutScope.isMobile(context)
      ? MobilePublicFrame(
          onNavigate: onNavigate,
          title: mobileTitle,
          child: child,
        )
      : Theme(
          data: publicTheme(context),
          child: Scaffold(
            backgroundColor: publicCream,
            body: Column(
              children: [
                PublicHeaderBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: () => onNavigate('/'),
                            borderRadius: BorderRadius.circular(8),
                            child: PublicBrand(
                              light: true,
                              compact: MediaQuery.sizeOf(context).width < 600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () => onNavigate('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Home'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        return Row(
                          children: [
                            if (wide)
                              SizedBox(
                                width: (constraints.maxWidth * 0.42).clamp(
                                  340.0,
                                  560.0,
                                ),
                                child: _AuthStory(registration: registration),
                              ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, contentSize) =>
                                    SingleChildScrollView(
                                      key: const ValueKey('auth-scroll'),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: contentSize.maxHeight,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: wide ? 36 : 16,
                                            vertical: wide ? 32 : 24,
                                          ),
                                          child: Center(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: registration
                                                    ? 690
                                                    : 460,
                                              ),
                                              child: Container(
                                                width: double.infinity,
                                                padding: EdgeInsets.all(
                                                  wide ? 36 : 24,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE8EBEE,
                                                    ),
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x08092136),
                                                      blurRadius: 35,
                                                      offset: Offset(0, 12),
                                                    ),
                                                  ],
                                                ),
                                                child: child,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const PublicFooter(),
              ],
            ),
          ),
        );
}

class _AuthStory extends StatelessWidget {
  const _AuthStory({required this.registration});
  final bool registration;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: EntryBackdrop(
        dark: true,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EntryEyebrow('LEARN WITH PURPOSE', light: true),
                  const SizedBox(height: 18),
                  Text(
                    registration
                        ? 'A new chapter.\nA world of possibility.'
                        : 'A place to learn.\nA community to grow.',
                    style: const TextStyle(
                      fontFamily: 'NotoSerifDisplay',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rooted in Islamic values. Connected through learning.',
                    style: TextStyle(
                      color: Color(0xFFCFDDE4),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: (constraints.maxWidth * 0.65).clamp(180.0, 280.0),
                    child: const LearningPortrait(compact: true),
                  ),
                  const SizedBox(height: 30),
                  const _StoryFeature(
                    Icons.auto_stories_outlined,
                    'Keep learning',
                    'Your classes and lessons, together',
                  ),
                  const _StoryFeature(
                    Icons.insights_rounded,
                    'See your progress',
                    'Make every small step count',
                  ),
                  if (registration)
                    const _StoryFeature(
                      Icons.people_outline_rounded,
                      'Grow together',
                      'A connected learning community',
                    ),
                  const Divider(color: Color(0xFF46617B), height: 1),
                  const SizedBox(height: 20),
                  const Text(
                    'KNOWLEDGE  /  CHARACTER  /  BRIGHTER LIVES',
                    style: TextStyle(
                      color: publicHeaderAccent,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      height: 1.6,
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

class _StoryFeature extends StatelessWidget {
  const _StoryFeature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 27),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 27),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFB9C8D4),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MosqueSilhouette extends CustomPainter {
  const MosqueSilhouette();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9AA8B6).withValues(alpha: 0.09);
    final base = size.height * 0.95;
    final dome = Path()
      ..moveTo(size.width * 0.22, base)
      ..lineTo(size.width * 0.22, base - 95)
      ..cubicTo(
        size.width * 0.22,
        base - 145,
        size.width * 0.43,
        base - 150,
        size.width * 0.5,
        base - 210,
      )
      ..cubicTo(
        size.width * 0.57,
        base - 150,
        size.width * 0.78,
        base - 145,
        size.width * 0.78,
        base - 95,
      )
      ..lineTo(size.width * 0.78, base)
      ..close();
    canvas.drawPath(dome, paint);
    canvas.drawRect(Rect.fromLTRB(0, base, size.width, size.height), paint);
    for (final fraction in [0.10, 0.88]) {
      final x = size.width * fraction;
      canvas.drawRect(Rect.fromLTWH(x - 10, base - 165, 20, 165), paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 15, base - 178, 30, 28),
          const Radius.circular(15),
        ),
        paint,
      );
      canvas.drawRect(Rect.fromLTWH(x - 2, base - 195, 4, 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
