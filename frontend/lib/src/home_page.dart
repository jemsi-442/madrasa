import 'package:flutter/material.dart';

import 'public_shell.dart';
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
      final wide = constraints.maxWidth >= 1150;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final inset = constraints.maxWidth > 1384
          ? (constraints.maxWidth - 1320) / 2
          : 32.0;
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: _HeroMessage(onJoin: onJoin, onExplore: onExplore),
            ),
            const AspectRatio(aspectRatio: 1.45, child: _HeroPhoto()),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PublicHomeFeatures(key: featuresKey),
            ),
          ],
        );
      }
      return SizedBox(
        height: 664,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: constraints.maxWidth * 0.59,
              child: const _HeroPhoto(fade: true),
            ),
            Positioned(
              top: 52,
              left: inset,
              width: constraints.maxWidth >= 1250 ? 620 : 470,
              child: _HeroMessage(onJoin: onJoin, onExplore: onExplore),
            ),
            Positioned(
              left: inset,
              bottom: 30,
              width: constraints.maxWidth >= 1200 ? 790 : 630,
              child: PublicHomeFeatures(key: featuresKey),
            ),
            if (constraints.maxWidth >= 1200)
              Positioned(
                right: 40,
                bottom: 28,
                width: 300,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: publicCream.withValues(alpha: 0.91),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '“My Lord, increase me in knowledge.”\nQur\'an 20:114',
                    style: TextStyle(
                      color: publicInk,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({this.fade = false});
  final bool fade;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/learning-hero.png',
        fit: BoxFit.cover,
        alignment: const Alignment(0.25, 0),
        semanticLabel:
            'Illustration of a young learner studying with a tablet in a madrasa library',
      ),
      if (fade)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [publicCream, Color(0xE6FCFAF6), Color(0x00FCFAF6)],
              stops: [0, 0.12, 0.46],
            ),
          ),
        ),
    ],
  );
}

class _HeroMessage extends StatelessWidget {
  const _HeroMessage({required this.onJoin, required this.onExplore});
  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ISLAMIC VALUES. MODERN SKILLS. BRIGHTER FUTURES.',
          style: TextStyle(
            color: publicGold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Empowering the Next\nGeneration of Muslims',
          style: TextStyle(
            color: publicInk,
            fontFamily: 'NotoSansDisplay',
            fontSize: width >= 1250
                ? 51
                : width >= 600
                ? 43
                : 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.13,
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 505),
          child: Text(
            'Authentic Islamic education, modern skills and a community that supports every learner.',
            style: TextStyle(
              color: Color(0xFF344D68),
              fontSize: 16,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 28),
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
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: publicInk,
                  side: const BorderSide(color: publicInk),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
      ],
    );
  }
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
                    fontSize: 32,
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
