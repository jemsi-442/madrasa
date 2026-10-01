import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'public_palette.dart';

/// A quiet geometric pattern, painted behind content without intercepting taps.
class EntryBackdrop extends StatelessWidget {
  const EntryBackdrop({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [publicBrandBlue, const Color(0xFF204D55)]
            : [publicCream, const Color(0xFFF3EEE3), Colors.white],
      ),
    ),
    child: CustomPaint(
      painter: _LatticePainter(dark: dark),
      child: child,
    ),
  );
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = (dark ? publicHeaderAccent : publicGold).withValues(
        alpha: dark ? 0.12 : 0.08,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 4; column++) {
        final center = Offset(size.width - column * 64, row * 64.0 - 12);
        for (final angle in [0.0, math.pi / 4]) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(angle);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 44, height: 44),
            paint,
          );
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LatticePainter oldDelegate) => dark != oldDelegate.dark;
}

class EntryReveal extends StatelessWidget {
  const EntryReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class LearningPortrait extends StatelessWidget {
  const LearningPortrait({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(220),
        bottom: Radius.circular(24),
      ),
      border: Border.all(color: publicHeaderAccent.withValues(alpha: 0.6)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18092136),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(214),
          bottom: Radius.circular(19),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/learning-hero.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.45, -0.3),
              semanticLabel:
                  'Illustration of a young learner studying in a madrasa library',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE092136)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: compact ? 16 : 28,
              right: compact ? 16 : 28,
              bottom: compact ? 16 : 28,
              child: Text(
                'Small steps.\nLifelong possibilities.',
                style: TextStyle(
                  fontFamily: 'NotoSerifDisplay',
                  fontSize: compact ? 17 : 25,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EntryEyebrow extends StatelessWidget {
  const EntryEyebrow(this.label, {super.key, this.light = false});
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: light ? publicHeaderAccent : publicGold,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
      height: 1.5,
    ),
  );
}
