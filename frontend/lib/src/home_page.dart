import 'package:flutter/material.dart';

import 'public_shell.dart';
import 'public_entry_visuals.dart';
import 'public_site_footer.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key, required this.onNavigate});
  final PublicNavigate onNavigate;

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  final topKey = GlobalKey();
  final aboutKey = GlobalKey();
  final featuresKey = GlobalKey();
  final schoolsKey = GlobalKey();
  String selected = 'Home';

  void openSection(String label) {
    if (label == 'Contact') {
      widget.onNavigate('/contact');
      return;
    }
    final key = switch (label) {
      'About' => aboutKey,
      'Features' => featuresKey,
      'For Schools' => schoolsKey,
      _ => topKey,
    };
    setState(() => selected = label);
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: publicTheme(context),
    child: Scaffold(
      backgroundColor: publicCream,
      body: Column(
        children: [
          _HomeHeader(
            selected: selected,
            onSection: openSection,
            onNavigate: widget.onNavigate,
          ),
          Expanded(
            child: SingleChildScrollView(
              primary: true,
              child: Column(
                children: [
                  _HomeHero(
                    key: topKey,
                    featuresKey: featuresKey,
                    onJoin: () => widget.onNavigate('/register'),
                    onExplore: () => openSection('About'),
                  ),
                  _AboutSection(
                    key: aboutKey,
                    onJoin: () => widget.onNavigate('/register'),
                  ),
                  PublicSiteFooter(
                    key: schoolsKey,
                    onNavigate: widget.onNavigate,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.selected,
    required this.onSection,
    required this.onNavigate,
  });
  final String selected;
  final ValueChanged<String> onSection;
  final PublicNavigate onNavigate;
  static const sections = [
    'Home',
    'About',
    'Features',
    'For Schools',
    'Contact',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1150 &&
          MediaQuery.textScalerOf(context).scale(16) < 25;
      final compact = constraints.maxWidth < 600;
      return PublicHeaderBar(
        child: Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () => onSection('Home'),
                borderRadius: BorderRadius.circular(8),
                child: PublicBrand(light: true, compact: compact),
              ),
            ),
            const Spacer(),
            if (wide) ...[
              for (final label in sections)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextButton(
                    onPressed: () => onSection(label),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: selected == label
                                ? publicHeaderAccent
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: 28,
                          height: 2,
                          decoration: BoxDecoration(
                            color: selected == label
                                ? publicHeaderAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 24),
            ],
            OutlinedButton(
              key: const ValueKey('header-login'),
              onPressed: () => onNavigate('/login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF93A6BA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 23,
                  vertical: 17,
                ),
                minimumSize: const Size(0, 44),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 14),
              GoldAction(
                label: 'Get Started',
                fullWidth: false,
                onPressed: () => onNavigate('/register'),
              ),
            ] else ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onSelected: (value) => value == 'Get Started'
                    ? onNavigate('/register')
                    : onSection(value),
                itemBuilder: (_) => [...sections, 'Get Started']
                    .map(
                      (label) =>
                          PopupMenuItem(value: label, child: Text(label)),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    super.key,
    required this.featuresKey,
    required this.onJoin,
    required this.onExplore,
  });
  final GlobalKey featuresKey;
  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => EntryBackdrop(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1384),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth == 0) return const SizedBox.shrink();
              final wide =
                  constraints.maxWidth >= 850 &&
                  MediaQuery.textScalerOf(context).scale(16) < 25;
              final message = _HeroMessage(
                onJoin: onJoin,
                onExplore: onExplore,
              );
              final portrait = Column(
                children: [
                  const AspectRatio(
                    aspectRatio: 1.12,
                    child: LearningPortrait(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FAITH AT THE HEART. LEARNING WITHOUT LIMITS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: publicGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      height: 1.6,
                    ),
                  ),
                ],
              );
              return Column(
                children: [
                  EntryReveal(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 6, child: message),
                              const SizedBox(width: 64),
                              Expanded(flex: 5, child: portrait),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              message,
                              const SizedBox(height: 36),
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: portrait,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 40),
                  const Divider(color: Color(0xFFDED5C5), height: 1),
                  const SizedBox(height: 32),
                  PublicHomeFeatures(key: featuresKey),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _HeroMessage extends StatelessWidget {
  const _HeroMessage({required this.onJoin, required this.onExplore});
  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EntryEyebrow('ISLAMIC VALUES. MODERN POSSIBILITIES.'),
        const SizedBox(height: 20),
        Text(
          'Knowledge that\nshapes brighter\ntomorrows.',
          style: TextStyle(
            color: publicInk,
            fontFamily: 'NotoSerifDisplay',
            fontSize: constraints.maxWidth >= 500 ? 56 : 38,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 24),
        Container(width: 52, height: 3, color: publicGold),
        const SizedBox(height: 24),
        const Text(
          'Rooted in faith. Built for your future.',
          style: TextStyle(
            color: publicInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Explore Islamic education and practical skills in one connected space for learners, families and teachers.',
          style: TextStyle(color: publicMuted, fontSize: 16, height: 1.7),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            GoldAction(
              key: const ValueKey('hero-register'),
              label: 'Get Started',
              icon: Icons.arrow_forward_rounded,
              fullWidth: false,
              onPressed: onJoin,
            ),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: publicInk,
                  side: const BorderSide(color: Color(0xFFD1C7B5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(Icons.auto_stories_outlined, size: 20),
                label: const Text(
                  'Explore Learning',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'For curious minds. For every stage of learning.',
          style: TextStyle(color: publicMuted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class PublicHomeFeatures extends StatelessWidget {
  const PublicHomeFeatures({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Window-size transitions can briefly leave no space after page padding.
      if (constraints.maxWidth == 0) return const SizedBox.shrink();
      final columns = switch (constraints.maxWidth) {
        >= 600 => 4,
        >= 260 => 2,
        _ => 1,
      };
      final width = (constraints.maxWidth - 20 * (columns - 1)) / columns;
      const features = [
        (
          Icons.menu_book_outlined,
          "Qur'an Tracking",
          'Follow memorization\nand recitation',
        ),
        (
          Icons.groups_outlined,
          'Student Management',
          'Organize and support\nevery learner',
        ),
        (
          Icons.bar_chart_rounded,
          'Progress Reports',
          'See growth and\ncelebrate progress',
        ),
        (
          Icons.favorite_border_rounded,
          'Community Support',
          'Connect families\nand teachers',
        ),
      ];
      return Wrap(
        spacing: 20,
        runSpacing: 26,
        children: features
            .map(
              (feature) => SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEAF0F5), Color(0xFFF6F6F5)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        feature.$1,
                        color: const Color(0xFF123C62),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      feature.$2,
                      style: const TextStyle(
                        color: publicInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      feature.$3,
                      style: const TextStyle(
                        color: Color(0xFF405772),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key, required this.onJoin});
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final message = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A PLACE TO LEARN AND BELONG',
                  style: TextStyle(
                    color: publicGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Rooted in values.\nReady for tomorrow.',
                  style: TextStyle(
                    color: publicInk,
                    fontFamily: 'NotoSerifDisplay',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'From a child\'s first lesson to lifelong study, we bring faith, knowledge and practical skills together.',
                  style: TextStyle(
                    color: publicMuted,
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: onJoin,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Start your learning journey',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
            const paths = Column(
              children: [
                _LearningPath(
                  icon: Icons.menu_book_outlined,
                  title: 'Faith & understanding',
                  text: 'Qur\'an, Arabic and Islamic studies.',
                ),
                SizedBox(height: 16),
                _LearningPath(
                  icon: Icons.computer_outlined,
                  title: 'Skills for today',
                  text: 'Technology and practical online courses.',
                ),
                SizedBox(height: 16),
                _LearningPath(
                  icon: Icons.people_outline_rounded,
                  title: 'A connected community',
                  text: 'Families and teachers, supporting every step.',
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: message),
                      const SizedBox(width: 90),
                      const Expanded(child: paths),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [message, const SizedBox(height: 30), paths],
                  );
          },
        ),
      ),
    ),
  );
}

class _LearningPath extends StatelessWidget {
  const _LearningPath({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFE2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: publicGold),
      ),
      const SizedBox(width: 17),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: publicInk,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: publicMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
