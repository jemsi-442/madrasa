import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// The caller chooses meaning; this component owns presentation and wrapping.
class AfaqNotice extends StatelessWidget {
  const AfaqNotice(
    this.message, {
    super.key,
    this.icon = Icons.info_outline,
    this.color = AfaqDesign.blue,
    this.liveRegion = false,
  });
  final String message;
  final IconData icon;
  final Color color;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: liveRegion,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        border: Border.all(color: color.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(AfaqDesign.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AfaqDesign.ink,
                fontSize: AfaqDesign.secondarySize,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AfaqActionTile extends StatelessWidget {
  const AfaqActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = AfaqDesign.gold,
    this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: AfaqDesign.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AfaqDesign.panelRadius),
      side: const BorderSide(color: AfaqDesign.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.textScalerOf(context).scale(16) <= 24) ...[
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(AfaqDesign.controlRadius),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AfaqDesign.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AfaqDesign.muted,
                      fontSize: AfaqDesign.secondarySize,
                      height: 1.5,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AfaqDesign.muted,
            ),
          ],
        ),
      ),
    ),
  );
}
