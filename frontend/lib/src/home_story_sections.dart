import 'package:flutter/material.dart';
import 'public_shell.dart';
import 'home_photo.dart';
import 'home_team_viewer.dart';

/// Public copy adapted from the supplied pitch deck and event proposal.
/// Projections, fundraising targets and personal biographies are not published.
class HomeStorySections extends StatelessWidget {
  const HomeStorySections({super.key, this.storyKey, this.practiceKey});
  final Key? storyKey, practiceKey;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Section(
        eyebrow: 'OUR APPROACH',
        title: 'Faith is the foundation.\nPossibility is the horizon.',
        intro:
            'Afaq is an Islamic education initiative connecting authentic Islamic foundations with the skills learners need to contribute to contemporary life. We focus on how learning is taught, experienced and put into practice.',
        child: _Columns(
          children: const [
            _Pillar(
              number: '01',
              accent: Color(0xFF235B79),
              title: 'Meaningful learning',
              icon: Icons.auto_stories_outlined,
              text:
                  'Bring Islamic knowledge together with critical thinking, creativity and practical problem-solving. Preserve values while making lessons relevant to everyday life.',
            ),
            _Pillar(
              number: '02',
              accent: Color(0xFF24705D),
              title: 'Empowered educators',
              icon: Icons.school_outlined,
              text:
                  'Support teachers with guidance, engaging learning materials and modern tools. Stronger teaching helps every learner participate with confidence.',
            ),
            _Pillar(
              number: '03',
              accent: Color(0xFF88600D),
              title: 'Community-backed support',
              icon: Icons.diversity_3_outlined,
              text:
                  'Bring families, madrasas and partners together around learning. Our model seeks sustained support through partnerships, shared resources and community giving.',
            ),
          ],
        ),
      ),
      _Section(
        key: storyKey,
        color: Colors.white,
        eyebrow: 'OUR STORY',
        title: 'Small beginnings.\nA shared ambition.',
        intro:
            'Our story began with volunteer teaching in a local mosque and lessons for three children at home.\n\nIt grew into a wider effort to strengthen madrasa education, rooted in community and driven by the needs of learners.',
        child: _Columns(
          children: [
            const _Photo(
              asset: 'assets/home/shared-learning.jpg',
              aspectRatio: 1100 / 619,
              description:
                  'Learners working together on schoolwork before a Quran session.',
              caption: 'Learning together, with faith at the centre.',
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StoryStep(
                  year: '2021–2022',
                  title: 'Start with the community',
                  text:
                      'Volunteer teaching and home lessons laid the foundation for an approach built around care, participation and belonging.',
                ),
                _StoryStep(
                  year: '2023–2024',
                  title: 'Grow through local learning',
                  text:
                      'Teaching moved into a local mosque. The experience highlighted a wider need for stronger structures, teacher support and learning resources.',
                ),
                _StoryStep(
                  year: 'OUR DIRECTION',
                  title: 'Build a model others can use',
                  text:
                      'We are developing an approach that other madrasas can adapt, with a long-term vision for a Modern Islamic Academy where faith meets contemporary skills.',
                ),
              ],
            ),
          ],
        ),
      ),
      _Section(
        key: practiceKey,
        eyebrow: 'LEARNING IN PRACTICE',
        title: 'More than a lesson.\nAn opportunity to take part.',
        intro:
            'Knowledge becomes meaningful when learners can use it. Our programme materials show students working together, using digital tools and sharing what they learn through projects and exhibitions.',
        child: _Columns(
          children: [
            const _Photo(
              asset: 'assets/home/digital-learning.jpg',
              aspectRatio: 900 / 507,
              description: 'A learner using a laptop to take attendance.',
              caption:
                  'Digital skills and responsibility in everyday learning.',
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StoryStep(
                  year: 'IN THE CLASSROOM',
                  title: 'Connect knowledge and daily life',
                  text:
                      'Schoolwork, Quran learning and practical activities can support one another rather than compete for a learner\'s attention.',
                ),
                _StoryStep(
                  year: 'BEYOND THE CLASSROOM',
                  title: 'Make learning visible',
                  text:
                      'Student exhibitions create space to share projects, explain ideas and engage families with the learning process.',
                ),
                _StoryStep(
                  year: 'LOOKING AHEAD',
                  title: 'Create lasting partnerships',
                  text:
                      'Exhibitions are a starting point for conversations with educators and partners, not an end in themselves. Contact us for current programme and event information.',
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class HomeTeamSection extends StatelessWidget {
  const HomeTeamSection({super.key});

  @override
  Widget build(BuildContext context) => _Section(
    color: Colors.white,
    eyebrow: 'OUR TEAM',
    title: 'The people behind Afaq.',
    intro: 'Meet our founders, mentors and advisors.',
    child: Column(
      children: [
        const HomePhoto(
          asset: 'assets/home/team.webp',
          description:
              'Afaq team: Kassim Iddi, Founder; Miraji Hamidu, '
              'Co-Founder; Mrs. Ismail and Zuberi Bani, Mentors and Advisors.',
          aspectRatio: 16 / 9,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.zoom_in_rounded),
          label: const Text('View full team image'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => const HomeTeamViewer(),
          ),
        ),
      ],
    ),
  );
}

class HomeSchoolSection extends StatelessWidget {
  const HomeSchoolSection({super.key, required this.onNavigate});
  final PublicNavigate onNavigate;

  @override
  Widget build(BuildContext context) => _Section(
    color: const Color(0xFFEAF0F5),
    eyebrow: 'FOR SCHOOLS & MADRASAS',
    title: 'Support the teacher.\nConnect the learning journey.',
    intro:
        'The Afaq platform brings learning plans, classroom records and communication into one connected workspace. Technology supports the people doing the teaching; it does not replace their judgement.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Columns(
          children: [
            _Pillar(
              number: 'PLAN',
              accent: Color(0xFF235B79),
              title: 'Give lessons a clear direction',
              icon: Icons.route_outlined,
              text:
                  'Organise shared curriculum, learning objectives and lesson plans. Connect a framework to the madrasa and the teachers who use it.',
            ),
            _Pillar(
              number: 'TEACH',
              accent: Color(0xFF24705D),
              title: 'Keep records with context',
              icon: Icons.menu_book_outlined,
              text:
                  'Record attendance and learning observations. Follow Quran recitation, memorisation and revision as distinct areas of learning.',
            ),
            _Pillar(
              number: 'SUPPORT',
              accent: Color(0xFF88600D),
              title: 'Turn records into follow-up',
              icon: Icons.insights_outlined,
              text:
                  'Review progress and identify where support is needed. Families and staff access information according to their assigned roles.',
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => onNavigate('/contact'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Discuss your madrasa'),
            ),
            OutlinedButton(
              onPressed: () => onNavigate('/login'),
              child: const Text('Already part of Afaq? Sign in'),
            ),
          ],
        ),
      ],
    ),
  );
}

class HomePartnershipSection extends StatelessWidget {
  const HomePartnershipSection({
    super.key,
    required this.onNavigate,
    this.faqKey,
  });
  final PublicNavigate onNavigate;
  final Key? faqKey;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Section(
        color: Colors.white,
        eyebrow: 'PARTNER WITH AFAQ',
        title: 'A stronger learning community\nstarts with shared effort.',
        intro:
            'There is more than one way to contribute. Bring your experience, resources or institution into a conversation about meaningful, sustained support for Islamic education.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Columns(
              children: [
                _Pillar(
                  number: 'EDUCATORS',
                  accent: Color(0xFF235B79),
                  title: 'Share knowledge',
                  icon: Icons.people_outline,
                  text:
                      'Explore teacher development, learning materials and collaboration with other education institutions.',
                ),
                _Pillar(
                  number: 'FAMILIES',
                  accent: Color(0xFF24705D),
                  title: 'Be part of the journey',
                  icon: Icons.favorite_border,
                  text:
                      'Ask about learning opportunities, stay involved in your child\'s education and connect with the team.',
                ),
                _Pillar(
                  number: 'PARTNERS',
                  accent: Color(0xFF88600D),
                  title: 'Help learning grow',
                  icon: Icons.handshake_outlined,
                  text:
                      'Discuss resources, programme support or student exhibitions. Partnership details are agreed directly with the Afaq team.',
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => onNavigate('/contact'),
              icon: const Icon(Icons.mail_outline),
              label: const Text('Talk to the Afaq team'),
            ),
          ],
        ),
      ),
      _Section(
        key: faqKey,
        eyebrow: 'QUESTIONS & ANSWERS',
        title: 'A little clarity before you begin.',
        child: Column(
          children: [
            for (final item in const [
              (
                'What is Afaq?',
                'Afaq is an Islamic education initiative bringing together faith, contemporary skills, teacher support and community partnerships. The digital platform supports this wider educational mission.',
              ),
              (
                'Does technology replace the madrasa teacher?',
                'No. Teachers lead learning and confirm classroom observations. The platform helps organise their work and makes follow-up easier.',
              ),
              (
                'How can our madrasa get involved?',
                'Contact the Afaq team to discuss your institution and its needs. The team will guide you through the appropriate onboarding steps; creating a public account does not grant staff access.',
              ),
              (
                'Can families and partners take part?',
                'Yes. Contact us about learning opportunities, parent access, educational collaboration or programme support. Current arrangements are confirmed by the team.',
              ),
            ])
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFDED5C5)),
                ),
                child: ExpansionTile(
                  key: PageStorageKey(item.$1),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: publicGold,
                  collapsedIconColor: publicInk,
                  backgroundColor: const Color(0xFFF5F8FA),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    item.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      height: 1.4,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          height: 1.7,
                          color: publicMuted,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: publicInk,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Let\'s talk about your next step.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For learning opportunities, madrasa partnerships or programme support, start a conversation with our team.',
                    style: TextStyle(
                      color: Color(0xFFD8E2EC),
                      fontSize: 16,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('home-contact-next-step'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF0D899),
                          foregroundColor: publicInk,
                        ),
                        onPressed: () => onNavigate('/contact'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Contact Afaq'),
                      ),
                      TextButton(
                        key: const ValueKey('home-sign-in-next-step'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => onNavigate('/login'),
                        child: const Text('Already registered? Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.intro,
    this.color = publicCream,
  });
  final String eyebrow, title;
  final String? intro;
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: publicGold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'NotoSerifDisplay',
                  fontSize: MediaQuery.sizeOf(context).width >= 1000 ? 42 : 32,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: publicInk,
                ),
              ),
            ),
            if (intro != null) ...[
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, paragraph)
                        in intro!.split('\n\n').indexed) ...[
                      if (index > 0) const SizedBox(height: 14),
                      Text(
                        paragraph,
                        style: const TextStyle(
                          color: publicMuted,
                          fontSize: 18,
                          height: 1.75,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Theme(
              data: Theme.of(context).copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style:
                      Theme.of(
                        context,
                      ).filledButtonTheme.style?.merge(_sectionActionStyle) ??
                      _sectionActionStyle,
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style:
                      Theme.of(
                        context,
                      ).outlinedButtonTheme.style?.merge(_sectionActionStyle) ??
                      _sectionActionStyle,
                ),
                textButtonTheme: TextButtonThemeData(
                  style:
                      Theme.of(
                        context,
                      ).textButtonTheme.style?.merge(_sectionActionStyle) ??
                      _sectionActionStyle,
                ),
              ),
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}

const _sectionActionStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, 56)),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  ),
  textStyle: WidgetStatePropertyAll(
    TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  ),
  iconSize: WidgetStatePropertyAll(26),
);

class _Columns extends StatelessWidget {
  const _Columns({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) >= 25;
      if (children.every((child) => child is _Pillar)) {
        final columns = largeText || size.maxWidth < 640
            ? 1
            : size.maxWidth < 1050
            ? 2
            : 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < children.length; start += columns) ...[
              if (start > 0) const SizedBox(height: 24),
              if (columns == 1)
                children[start]
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var i = start;
                        i < start + columns && i < children.length;
                        i++
                      ) ...[
                        if (i > start) const SizedBox(width: 24),
                        Expanded(child: children[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        );
      }
      final wide = size.maxWidth >= 800 && !largeText;
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 28),
                  Expanded(child: children[i]),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 24),
                  children[i],
                ],
              ],
            );
    },
  );
}

class _Pillar extends StatelessWidget {
  const _Pillar({
    required this.number,
    required this.title,
    required this.text,
    required this.icon,
    required this.accent,
  });
  final String number, title, text;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(Colors.white, accent, 0.10)!, Colors.white],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Color.lerp(Colors.white, accent, 0.25)!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          number,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: publicInk,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: const TextStyle(color: publicMuted, height: 1.7, fontSize: 17),
        ),
      ],
    ),
  );
}

class _StoryStep extends StatelessWidget {
  const _StoryStep({
    required this.year,
    required this.title,
    required this.text,
  });
  final String year, title, text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 24),
    decoration: const BoxDecoration(
      color: Color(0xFFFAF8F3),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFE5DDCF))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFFF2E8D2),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Text(
            year,
            style: const TextStyle(
              color: Color(0xFF805A14),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.35,
              color: publicInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(height: 1.7, color: publicMuted, fontSize: 17),
        ),
      ],
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.asset,
    required this.description,
    required this.caption,
    required this.aspectRatio,
  });
  final String asset, description, caption;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: HomePhoto(
          asset: asset,
          description: description,
          aspectRatio: aspectRatio,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        caption,
        style: const TextStyle(color: publicMuted, fontSize: 15, height: 1.6),
      ),
    ],
  );
}
