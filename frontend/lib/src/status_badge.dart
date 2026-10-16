import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Presentation only: the caller owns the status label and business meaning.
class AfaqStatusBadge extends StatelessWidget {
  const AfaqStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: AfaqDesign.badgePadding,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AfaqDesign.controlRadius),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AfaqDesign.secondarySize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
