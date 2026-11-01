import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Directory status is not proof that invitation or activation checks passed.
class MadrasaProfileHandoff extends StatelessWidget {
  const MadrasaProfileHandoff({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (message, owner, icon, color) = switch (status) {
      'REQUESTED' => (
        'Awaiting independent approval.',
        'Superadmin',
        Icons.fact_check_outlined,
        AfaqDesign.gold,
      ),
      'APPROVED' => (
        'Approved. Continue registration in Madrasas.',
        'Superadmin',
        Icons.build_outlined,
        AfaqDesign.gold,
      ),
      'PENDING_ACTIVATION' => (
        'Setup is in progress. Check invitation acceptance and activation readiness.',
        'Check onboarding progress',
        Icons.schedule_outlined,
        AfaqDesign.gold,
      ),
      'ACTIVE' => (
        'Madrasa is active.',
        'Madrasa administrator',
        Icons.check_circle_outline,
        AfaqDesign.green,
      ),
      'TRIAL' => (
        'Madrasa is on trial.',
        'Madrasa administrator',
        Icons.schedule_outlined,
        AfaqDesign.gold,
      ),
      'SUSPENDED' => (
        'Access is suspended. Onboarding must not be used to restore access.',
        'Office access review',
        Icons.block_outlined,
        const Color(0xffa53e42),
      ),
      'REJECTED' => (
        'Registration request was declined.',
        'See decision below',
        Icons.info_outline,
        const Color(0xffa53e42),
      ),
      _ => (
        'Check the current onboarding status.',
        'Office review',
        Icons.info_outline,
        AfaqDesign.muted,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AfaqDesign.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(owner, style: const TextStyle(color: AfaqDesign.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
