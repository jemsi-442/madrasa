import 'design_tokens.dart';
import 'package:flutter/material.dart';

import 'foundation_ui.dart';

// Presentation order is separate from stable page IDs used by links/history.
List<int>? workspacePageOrder(String role) =>
    role == 'TEACHER' ? const [0, 1, 2, 10, 5, 4, 3, 8, 9, 6, 7] : null;

List<int> relatedWorkspacePages(String role, int page) {
  if (page == 0) return const [];
  // Teaching suggestions move toward recording, reporting and communication.
  // Returning to an earlier task belongs to Back or the sidebar, not Next.
  if (role == 'TEACHER') {
    return switch (page) {
      10 => const [5],
      1 => const [2, 4],
      2 => const [4, 8],
      4 => const [3, 8],
      3 => const [8, 9],
      8 => const [9, 7],
      9 => const [7],
      _ => const [],
    };
  }
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
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: AfaqDesign.iconSmall,
                ),
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
            icon: const Icon(Icons.home_outlined, size: AfaqDesign.iconSmall),
          ),
          if (!atHome)
            const Icon(
              Icons.chevron_right,
              color: muted,
              size: AfaqDesign.iconSmall,
            ),
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
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    size: AfaqDesign.iconSmall,
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
