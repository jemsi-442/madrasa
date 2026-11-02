import 'design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'public_shell.dart';
import 'public_entry_visuals.dart';
import 'public_site_footer.dart';
import 'home_story_sections.dart';
import 'home_photo.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key, required this.onNavigate});
  final PublicNavigate onNavigate;

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  final scrollController = ScrollController();
  bool showBackToTop = false;
  final topKey = GlobalKey();
  final aboutKey = GlobalKey();
  final featuresKey = GlobalKey();
  final schoolsKey = GlobalKey();
  final storyKey = GlobalKey();
  final practiceKey = GlobalKey();
  final teamKey = GlobalKey();
  final partnersKey = GlobalKey();
  final faqKey = GlobalKey();
  String selected = 'Home';

  Map<String, GlobalKey> get sectionKeys => {
    'Home': topKey,
    'Features': featuresKey,
    'About': aboutKey,
    'Our story': storyKey,
    'Learning in practice': practiceKey,
    'Our team': teamKey,
    'For Schools': schoolsKey,
    'Partners': partnersKey,
    'FAQs': faqKey,
  };

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateScrollActions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) updateScrollActions();
    });
  }

  void updateScrollActions() {
    final visible = scrollController.offset > 700;
    var active = 'Home';
    for (final entry in sectionKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final offset = viewport.getOffsetToReveal(box, 0).offset;
      if (offset <= scrollController.offset + 100) active = entry.key;
    }
    if (visible != showBackToTop || selected != active) {
      setState(() {
        showBackToTop = visible;
        selected = active;
      });
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void openSection(String label) {
    if (label == 'Contact') {
      widget.onNavigate('/contact');
      return;
    }
    final key = sectionKeys[label] ?? topKey;
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
      floatingActionButton: showBackToTop
          ? FloatingActionButton.small(
              key: const ValueKey('home-back-to-top'),
              tooltip: 'Back to top',
              backgroundColor: publicInk,
              foregroundColor: Colors.white,
              onPressed: () => openSection('Home'),
              child: const Icon(Icons.arrow_upward_rounded, size: 28),
            )
          : null,
      body: Column(
        children: [
          _HomeHeader(
            selected: selected,
            onSection: openSection,
            onNavigate: widget.onNavigate,
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: MediaQuery.sizeOf(context).width >= 900,
              interactive: true,
              child: SingleChildScrollView(
                key: const PageStorageKey('public-home-scroll'),
                controller: scrollController,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final label in [
                            'Our story',
                            'Learning in practice',
                            'Our team',
                            'For Schools',
                            'Partners',
                            'FAQs',
                          ])
                            OutlinedButton.icon(
                              onPressed: () => openSection(label),
                              icon: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 22,
                              ),
                              label: Text(label),
                            ),
                        ],
                      ),
                    ),
                    HomeStorySections(
                      storyKey: storyKey,
                      practiceKey: practiceKey,
                    ),
                    HomeTeamSection(key: teamKey),
                    HomeSchoolSection(
                      key: schoolsKey,
                      onNavigate: widget.onNavigate,
                    ),
                    HomePartnershipSection(
                      key: partnersKey,
                      faqKey: faqKey,
                      onNavigate: widget.onNavigate,
                    ),
                    PublicSiteFooter(onNavigate: widget.onNavigate),
                  ],
                ),
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
            Expanded(
              child: Semantics(
                label: 'Afaq home',
                button: true,
                child: InkWell(
                  onTap: () => onSection('Home'),
                  borderRadius: BorderRadius.circular(8),
                  child: PublicBrand(
                    light: true,
                    compact: compact,
                    wordmarkSize: 18,
                  ),
                ),
              ),
            ),
            if (wide) ...[
              for (final label in sections)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Semantics(
                    key: ValueKey('home-nav-$label'),
                    selected: selected == label,
                    child: TextButton(
                      onPressed: () => onSection(label),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: selected == label
                                  ? publicHeaderAccent
                                  : Colors.white,
                              fontSize: 15,
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
                ),
              PopupMenuButton<String>(
                tooltip: 'More homepage sections',
                onSelected: onSection,
                itemBuilder: (_) => [
                  for (final label in [
                    'Our story',
                    'Learning in practice',
                    'Our team',
                    'Partners',
                    'FAQs',
                  ])
                    CheckedPopupMenuItem(
                      value: label,
                      checked: selected == label,
                      child: Text(label),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'More',
                        style: TextStyle(
                          color: sections.contains(selected)
                              ? Colors.white
                              : publicHeaderAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onSelected: (value) => value == 'Get Started'
                    ? onNavigate('/register')
                    : onSection(value),
                itemBuilder: (_) => [
                  for (final label in [
                    'Home',
                    'Features',
                    'About',
                    'Our story',
                    'Learning in practice',
                    'Our team',
                    'For Schools',
                    'Partners',
                    'FAQs',
                  ])
                    CheckedPopupMenuItem(
                      value: label,
                      checked: selected == label,
                      child: Text(label, style: const TextStyle(fontSize: 16)),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'Contact',
                    child: Text('Contact Afaq'),
                  ),
                  const PopupMenuItem(
                    value: 'Get Started',
                    child: Text('Get Started'),
                  ),
                ],
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
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 1000 ? 32 : 24,
            vertical: MediaQuery.sizeOf(context).width >= 1000 ? 64 : 40,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth == 0) return const SizedBox.shrink();
              final wide =
                  constraints.maxWidth >= 1050 &&
                  MediaQuery.textScalerOf(context).scale(16) < 25;
              final message = _HeroMessage(
                onJoin: onJoin,
                onExplore: onExplore,
              );
              final portrait = Column(
                children: [
                  Container(
                    key: const ValueKey('home-hero-photo'),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDED5C5)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18092136),
                          blurRadius: 30,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: HomePhoto(
                        aspectRatio: 1100 / 619,
                        asset: 'assets/home/shared-learning.jpg',
                        description:
                            'Learners working together before a Quran session.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Learning together, growing with purpose.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: publicInk,
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FAITH AT THE HEART. LEARNING WITHOUT LIMITS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: publicGold,
                      fontSize: 14,
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
                    child: ConstrainedBox(
                      key: const ValueKey('home-hero-primary'),
                      constraints: BoxConstraints(
                        minHeight: wide
                            ? (MediaQuery.sizeOf(context).height * 0.78).clamp(
                                640.0,
                                880.0,
                              )
                            : 0,
                      ),
                      child: Center(
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(child: message),
                                  const SizedBox(width: 48),
                                  Expanded(child: portrait),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 680,
                                      ),
                                      child: message,
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 680,
                                      ),
                                      child: portrait,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: wide ? 64 : 40),
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
        Semantics(
          header: true,
          child: Text(
            'Knowledge that\nshapes brighter\ntomorrows.',
            style: TextStyle(
              color: publicInk,
              fontFamily: 'NotoSerifDisplay',
              fontSize: switch (constraints.maxWidth) {
                >= 620 => 72,
                >= 500 => 64,
                >= 360 => 48,
                _ => 40,
              },
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.12,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(width: 76, height: 4, color: publicGold),
        const SizedBox(height: 24),
        const Text(
          'Rooted in faith. Built for your future.',
          style: TextStyle(
            color: publicInk,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Explore Islamic education and practical skills in one connected space for learners, families and teachers.',
          style: TextStyle(color: publicMuted, fontSize: 20, height: 1.65),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            SizedBox(
              width: constraints.maxWidth < 480 ? constraints.maxWidth : null,
              child: GoldAction(
                key: const ValueKey('hero-register'),
                label: 'Get Started',
                icon: Icons.arrow_forward_rounded,
                fullWidth: constraints.maxWidth < 480,
                onPressed: onJoin,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth < 480 ? constraints.maxWidth : null,
              height: 58,
              child: OutlinedButton.icon(
                key: const ValueKey('hero-explore'),
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: publicInk,
                  side: const BorderSide(color: Color(0xFFD1C7B5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(
                  Icons.auto_stories_outlined,
                  size: AfaqDesign.iconSmall,
                ),
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
          style: TextStyle(color: publicMuted, fontSize: 14, height: 1.6),
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
      final textScale = MediaQuery.textScalerOf(context).scale(22) / 22;
      final readableWidth = constraints.maxWidth / textScale.clamp(1.0, 3.0);
      final columns = switch (readableWidth) {
        >= 960 => 4,
        >= 480 => 2,
        _ => 1,
      };
      final width = (constraints.maxWidth - 24 * (columns - 1)) / columns;
      const features = [
        (
          Icons.menu_book_outlined,
          "Qur'an Tracking",
          'Follow memorization and recitation',
          Color(0xFF175D88),
          Color(0xFFE0EFF9),
        ),
        (
          Icons.groups_outlined,
          'Student Management',
          'Organize and support every learner',
          Color(0xFF236A50),
          Color(0xFFE2F3EB),
        ),
        (
          Icons.bar_chart_rounded,
          'Progress Reports',
          'See growth and celebrate progress',
          Color(0xFF8A5D0C),
          Color(0xFFF8EDCF),
        ),
        (
          Icons.favorite_border_rounded,
          'Community Support',
          'Connect families and teachers',
          Color(0xFF246A73),
          Color(0xFFDFF2F3),
        ),
      ];
      const titleStyle = TextStyle(
        color: publicInk,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.35,
      );
      var titleHeight = 0.0;
      // Align descriptions when a longer heading wraps in multi-column layouts.
      if (columns > 1) {
        for (final feature in features) {
          final painter = TextPainter(
            text: TextSpan(
              text: feature.$2,
              style: DefaultTextStyle.of(context).style.merge(titleStyle),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: width);
          if (painter.height > titleHeight) titleHeight = painter.height;
          painter.dispose();
        }
      }
      return Wrap(
        spacing: 24,
        runSpacing: 36,
        children: features
            .map(
              (feature) => SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [feature.$5, Colors.white],
                        ),
                        border: Border.all(
                          color: feature.$4.withValues(alpha: 0.12),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(feature.$1, color: feature.$4, size: 48),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: titleHeight),
                      child: Semantics(
                        header: true,
                        child: Text(feature.$2, style: titleStyle),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feature.$3,
                      style: const TextStyle(
                        color: Color(0xFF405772),
                        fontSize: 18,
                        height: 1.6,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: const Text(
                    'Rooted in values.\nReady for tomorrow.',
                    style: TextStyle(
                      color: publicInk,
                      fontFamily: 'NotoSerifDisplay',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'From a child\'s first lesson to lifelong study, we bring faith, knowledge and practical skills together.',
                  style: TextStyle(
                    color: publicMuted,
                    fontSize: 18,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: onJoin,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: AfaqDesign.iconSmall,
                  ),
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
        child: Icon(icon, color: publicGold, size: 32),
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
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: publicMuted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
