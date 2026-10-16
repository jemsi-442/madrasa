import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'foundation_ui.dart';

class FamilyIdentityCard extends StatelessWidget {
  const FamilyIdentityCard({super.key, required this.number});
  final String? number;

  @override
  Widget build(BuildContext context) {
    final value = number?.trim();
    final issued = value != null && value.isNotEmpty;
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family sign-in number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (issued) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy family number'),
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Family number copied')),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not copy. Select the number to copy it manually.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this number with your existing password. It belongs to your family account; each child keeps a separate admission number.',
            ),
          ] else
            const Text(
              'Your family sign-in number has not been issued yet. Contact the school office. Your current sign-in details still work.',
            ),
        ],
      ),
    );
  }
}
