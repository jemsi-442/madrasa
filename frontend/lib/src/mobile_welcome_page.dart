import 'package:flutter/material.dart';

import 'public_shell.dart';

class MobileWelcomeScreen extends StatelessWidget {
  const MobileWelcomeScreen({super.key, required this.onNavigate});

  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => Theme(
    data: publicTheme(context),
    child: Scaffold(
      key: const ValueKey('mobile-welcome'),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [publicBrandBlue, Color(0xFF214C60)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.biggest.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: PublicBrand(
                                    light: true,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF355B6A),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFF648089),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.auto_stories_rounded,
                                      color: publicHeaderAccent,
                                      size: 42,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Assalamu alaikum',
                                  style: TextStyle(
                                    color: publicHeaderAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Your learning.\nAlways with you.',
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Classes, lessons and progress, together in your school app.',
                                  style: TextStyle(
                                    color: Color(0xFFDBE5EA),
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),
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
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    side: const BorderSide(
                                      color: Color(0xFF93A6BA),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Create a learner account'),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => onNavigate('/parent-access'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: publicHeaderAccent,
                                  ),
                                  icon: const Icon(
                                    Icons.family_restroom_outlined,
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
                                          foregroundColor: const Color(
                                            0xFFDBE5EA,
                                          ),
                                        ),
                                        child: Text(label),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
