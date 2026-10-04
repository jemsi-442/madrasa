import 'package:flutter/material.dart';

import 'foundation_ui.dart';

Map<int, String> workspaceGroups(String role) => switch (role) {
  'ADMIN' => const {
    0: 'Overview',
    1: 'School management',
    6: 'Finance & giving',
    8: 'Online learning',
    10: 'Results',
  },
  'ACCOUNTANT' => const {0: 'Overview', 1: 'Collections', 4: 'Finance tools'},
  'TEACHER' => const {
    0: 'Overview',
    1: 'Teaching',
    6: 'Communication',
    8: 'Results',
  },
  'PARENT' => const {
    0: 'Overview',
    1: 'My family',
    4: 'School & support',
    8: 'Results',
  },
  'LEARNER' => const {
    0: 'Overview',
    1: 'Online learning',
    3: 'Account & updates',
    5: 'School records',
  },
  _ => const {},
};

List<int> relatedWorkspacePages(String role, int page) {
  if (page == 0) return const [];
  final journeys = switch (role) {
    'ADMIN' => const [
      [1, 2, 5],
      [3, 4, 8],
      [8, 9],
      [10, 11],
      [6, 7],
    ],
    'ACCOUNTANT' => const [
      [4, 1, 2, 6],
      [3, 1],
      [5, 6],
      [7, 1],
    ],
    'TEACHER' => const [
      [1, 2, 3],
      [1, 4],
      [8, 9],
      [7, 2],
      [5, 6],
    ],
    'PARENT' => const [
      [1, 2, 3],
      [8, 9],
      [5, 6],
      [7, 6],
      [4, 7],
    ],
    'LEARNER' => const [
      [1, 2],
      [5, 6],
      [7, 8, 9],
      [3, 1],
      [4, 5],
    ],
    _ => const <List<int>>[],
  };
  final next = <int>{};
  for (final journey in journeys) {
    final index = journey.indexOf(page);
    if (index >= 0 && index + 1 < journey.length) next.add(journey[index + 1]);
  }
  for (final journey in journeys) {
    if (journey.contains(page)) next.addAll(journey.where((i) => i != page));
  }
  return next.take(2).toList();
}

class WorkspaceTrail extends StatelessWidget {
  const WorkspaceTrail({
    super.key,
    required this.homeTitle,
    required this.pageTitle,
    required this.atHome,
    required this.onHome,
    this.backTitle,
    this.onBack,
  });
  final String homeTitle, pageTitle;
  final bool atHome;
  final String? backTitle;
  final VoidCallback onHome;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('workspace-trail'),
    color: Colors.white,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: 'Back to $backTitle',
              child: TextButton.icon(
                key: const ValueKey('workspace-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size(0, 48),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            key: const ValueKey('workspace-home'),
            tooltip: 'Go to $homeTitle',
            onPressed: atHome ? null : onHome,
            icon: const Icon(Icons.home_outlined, size: 20),
          ),
          if (!atHome) const Icon(Icons.chevron_right, color: muted, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: 'Current page: $pageTitle',
              child: Text(
                pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class WorkspaceNextSteps extends StatelessWidget {
  const WorkspaceNextSteps({
    super.key,
    required this.pages,
    required this.onSelect,
  });
  final List<({int index, String title, String purpose, IconData icon})> pages;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('workspace-next-steps'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue from here',
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Related pages for your next task.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final page in pages)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  key: ValueKey('next-page-${page.index}'),
                  leading: Icon(page.icon, color: gold),
                  title: Text(
                    page.title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    page.purpose,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: muted,
                  ),
                  onTap: () => onSelect(page.index),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
