import 'package:flutter/material.dart';

typedef PublicNavigate = void Function(String path);

const publicInk = Color(0xFF092136);
// Dominant navy sampled from assets/mif-logo.png.
const publicBrandBlue = Color(0xFF011F3D);
const publicHeaderAccent = Color(0xFFE5BD67);
const publicGold = Color(0xFFA87722);
const publicCream = Color(0xFFFCFAF6);
const publicMuted = Color(0xFF69778B);
const publicBorder = Color(0xFFDCE2E9);
const publicBrandName = 'Modern Islamic Foundation';

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
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: publicBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: publicBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
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
    height: 48,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.onNavigate,
    required this.child,
    this.registration = false,
  });

  final PublicNavigate onNavigate;
  final Widget child;
  final bool registration;

  @override
  Widget build(BuildContext context) => Theme(
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
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
                          width: (constraints.maxWidth * 0.32).clamp(
                            290.0,
                            430.0,
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
                                          maxWidth: registration ? 690 : 460,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(
                                            wide ? 36 : 24,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE8EBEE),
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
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [publicBrandBlue, Color(0xFF152F45)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: MosqueSilhouette())),
        ),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 60,
                ),
                child: Column(
                  children: [
                    Text(
                      registration
                          ? 'Join a growing community\nbuilding brighter futures.'
                          : 'Learning today\nfor a brighter tomorrow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: registration
                            ? Colors.white
                            : const Color(0xFFE0B354),
                        fontSize: 19,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 44),
                    if (registration) ...[
                      const _StoryFeature(
                        Icons.school_outlined,
                        'For learners',
                        'Discover, learn and grow',
                      ),
                      const _StoryFeature(
                        Icons.people_outline_rounded,
                        'For families',
                        'Stay close to their journey',
                      ),
                      const _StoryFeature(
                        Icons.menu_book_outlined,
                        'For teachers',
                        'Teach and inspire',
                      ),
                      const _StoryFeature(
                        Icons.account_balance_outlined,
                        'For schools',
                        'Build a stronger community',
                      ),
                    ] else ...[
                      SizedBox(height: constraints.maxHeight > 700 ? 105 : 25),
                      const SizedBox(
                        width: 38,
                        child: Divider(color: Color(0xFFD5AA51), thickness: 2),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Knowledge. Character.\nA world of possibility.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSerifDisplay',
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
