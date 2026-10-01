import 'package:flutter/material.dart';

import 'public_entry_visuals.dart';
import 'public_shell.dart';

class MobileWelcomeScreen extends StatelessWidget {
  const MobileWelcomeScreen({super.key, required this.onNavigate});

  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => Theme(
    data: publicTheme(context),
    child: Scaffold(
      key: const ValueKey('mobile-welcome'),
      body: EntryBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.biggest.isEmpty) return const SizedBox.shrink();
              final compact = constraints.maxHeight < 720;
              return SingleChildScrollView(
                primary: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: PublicBrand(compact: true),
                                ),
                                IconButton.outlined(
                                  tooltip: 'Contact office',
                                  onPressed: () => onNavigate('/contact'),
                                  icon: const Icon(
                                    Icons.help_outline_rounded,
                                    size: 20,
                                  ),
                                  style: IconButton.styleFrom(
                                    side: const BorderSide(color: publicBorder),
                                    foregroundColor: publicInk,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 18 : 28),
                            EntryReveal(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const EntryEyebrow(
                                    'ASSALAMU ALAIKUM. WELCOME HOME.',
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Rooted in faith.\nReady for tomorrow.',
                                    style: TextStyle(
                                      fontFamily: 'NotoSerifDisplay',
                                      fontSize: constraints.maxWidth < 360
                                          ? 30
                                          : 36,
                                      fontWeight: FontWeight.w700,
                                      height: 1.16,
                                      letterSpacing: -1,
                                      color: publicInk,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Your classes, lessons and progress.\nA little closer, every day.',
                                    style: TextStyle(
                                      color: publicMuted,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  SizedBox(
                                    height: compact ? 160 : 205,
                                    child: const LearningPortrait(
                                      compact: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            GoldAction(
                              key: const ValueKey('mobile-login'),
                              label: 'Login',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => onNavigate('/login'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const ValueKey('mobile-register'),
                              onPressed: () => onNavigate('/register'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: publicInk,
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFD1C7B5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Create a learner account'),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => onNavigate('/parent-access'),
                              style: TextButton.styleFrom(
                                foregroundColor: publicGold,
                              ),
                              icon: const Icon(
                                Icons.family_restroom_outlined,
                                size: 20,
                              ),
                              label: const Text('Need access as a parent?'),
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                for (final (label, path) in [
                                  ('Help', '/contact'),
                                  ('Privacy', '/privacy'),
                                  ('Terms', '/terms'),
                                ])
                                  TextButton(
                                    onPressed: () => onNavigate(path),
                                    style: TextButton.styleFrom(
                                      foregroundColor: publicMuted,
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
