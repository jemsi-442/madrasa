import 'package:flutter/material.dart';

const ink = Color(0xFF011F3D);
const gold = Color(0xFFB78A2F);
const paper = Color(0xFFFBF9F4);
const muted = Color(0xFF66758B);

const forest = Color(0xFF278258);
const blue = Color(0xFF3A70AD);
const lavender = Color(0xFF7168AA);
const line = Color(0xFFE8E7E3);

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

class PatternBackdrop extends StatelessWidget {
  const PatternBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), paper, Color(0xFFF5F0E6)],
              ),
            ),
          ),
        ),
        const Positioned(
          top: -80,
          right: -100,
          child: IgnorePointer(
            child: CustomPaint(size: Size(370, 370), painter: _MotifPainter()),
          ),
        ),
        const Positioned(
          bottom: -150,
          left: -130,
          child: IgnorePointer(
            child: CustomPaint(size: Size(360, 360), painter: _MotifPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _MotifPainter extends CustomPainter {
  const _MotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = gold.withValues(alpha: 0.085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final center = Offset(size.width / 2, size.height / 2);
    for (var ring = 1; ring <= 5; ring++) {
      final radius = ring * 35.0;
      canvas.drawCircle(center, radius, stroke);
      final diamond = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(diamond, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0612263F),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = gold});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.note,
    this.dense = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? note;
  final bool dense;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 245;
      final badge = Container(
        width: compact ? 42 : 54,
        height: compact ? 42 : 54,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.11),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: compact ? 23 : 27),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: compact ? 25 : 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontSize: 13),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ],
      );
      return Container(
        constraints: BoxConstraints(minHeight: dense ? 128 : 0),
        padding: EdgeInsets.all(
          dense
              ? 16
              : compact
              ? 18
              : 22,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.14), Colors.white),
              Color.alphaBlend(accent.withValues(alpha: 0.055), Colors.white),
            ],
          ),
        ),
        child: compact && !dense
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [badge, const SizedBox(height: 16), content],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  SizedBox(width: dense ? 12 : 16),
                  Expanded(child: content),
                ],
              ),
      );
    },
  );
}

class DataBar extends StatelessWidget {
  const DataBar({
    super.key,
    required this.label,
    required this.value,
    required this.maximum,
    required this.color,
    this.displayValue,
  });

  final String label;
  final num value;
  final num maximum;
  final Color color;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    final fraction = maximum <= 0
        ? 0.0
        : (value / maximum).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                displayValue ?? value.toString(),
                style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 9,
              color: color,
              backgroundColor: const Color(0xFFE9EBEC),
            ),
          ),
        ],
      ),
    );
  }
}
