import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'foundation_ui.dart' show DashboardMetric;

const _ink = AfaqDesign.ink;
const _muted = AfaqDesign.muted;
const _gold = AfaqDesign.gold;

class PlatformOfficeDashboard extends StatelessWidget {
  const PlatformOfficeDashboard({
    super.key,
    required this.name,
    required this.snapshot,
    required this.busy,
    required this.error,
    required this.onRefresh,
    required this.onApplications,
    required this.onAccounts,
    required this.onHistory,
    this.onReview,
    this.onApproved,
  });
  final String name;
  final Map<String, dynamic>? snapshot;
  final bool busy;
  final String? error;
  final VoidCallback onRefresh, onApplications, onAccounts, onHistory;
  final VoidCallback? onReview, onApproved;

  Widget panel(String title, Widget child, {Widget? action}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: AfaqDesign.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  Widget empty(IconData icon, String title, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xffa9b9cb), size: 42),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.5),
        ),
      ],
    ),
  );

  Widget link(String label, VoidCallback? action) =>
      TextButton(onPressed: busy ? null : action, child: Text(label));

  @override
  Widget build(BuildContext context) {
    final applications = snapshot?['applications'] as Map?;
    final onboarding = snapshot?['onboarding'] as Map?;
    final recent = snapshot?['recentApplications'] as List?;
    final metrics = [
      (
        'Requested',
        applications?['REQUESTED'],
        Icons.domain_outlined,
        const Color(0xff246bcc),
      ),
      (
        'Awaiting your review',
        snapshot?['awaitingYourReview'],
        Icons.groups_outlined,
        _gold,
      ),
      (
        'Approved',
        applications?['APPROVED'],
        Icons.task_alt,
        const Color(0xff209369),
      ),
      (
        'Awaiting setup',
        onboarding?['awaitingSetup'],
        Icons.school_outlined,
        const Color(0xff7663af),
      ),
      (
        'Awaiting activation',
        onboarding?['pendingActivation'],
        Icons.menu_book_outlined,
        _gold,
      ),
      (
        'Declined',
        applications?['REJECTED'],
        Icons.do_not_disturb_alt,
        const Color(0xffb64f68),
      ),
    ];
    final counts = [
      applications?['REQUESTED'],
      applications?['APPROVED'],
      applications?['REJECTED'],
    ];
    final available = counts.every(
      (value) => value is num && value.isFinite && value >= 0,
    );
    final total = available
        ? counts.fold<num>(0, (sum, value) => sum + (value as num))
        : 0;
    final checkedAt = DateTime.tryParse('${snapshot?['checkedAt']}');
    return LayoutBuilder(
      builder: (context, bounds) {
        final desktop = bounds.maxWidth >= 1000;
        final columns = desktop
            ? 6
            : bounds.maxWidth >= 600
            ? 3
            : 1;
        final padding = bounds.maxWidth < 600 ? 16.0 : 24.0;
        final width = bounds.maxWidth - padding * 2;
        Widget grid(List<Widget> children) => desktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: children[i]),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 14),
                  ],
                ],
              );
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $name!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Here is your overview of madrassa onboarding and company oversight.',
                          style: TextStyle(color: _muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  WorkspaceRefreshButton(
                    tooltip: 'Refresh overview',
                    onRefresh: onRefresh,
                    loading: busy,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                checkedAt == null
                    ? 'No snapshot loaded'
                    : 'Last updated: ${checkedAt.toUtc().toIso8601String()} (UTC)',
                style: const TextStyle(color: _muted, fontSize: AfaqDesign.secondarySize),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: (width - (columns - 1) * 12) / columns,
                      child: DashboardMetric(
                        label: metric.$1,
                        value: metric.$2 is num
                            ? '${metric.$2}'
                            : 'Not available',
                        icon: metric.$3,
                        accent: metric.$4,
                        dense: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              grid([
                panel(
                  'Applications overview',
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: desktop ? 180 : 0),
                    child: !available
                        ? empty(
                            Icons.bar_chart,
                            'Application breakdown is unavailable. Refresh to try again.',
                            'No totals have been estimated.',
                          )
                        : total == 0
                        ? empty(
                            Icons.bar_chart,
                            'No applications recorded yet.',
                            'New requests will appear in this overview.',
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < counts.length; i++) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        [
                                          'Pending decision',
                                          'Approved requests',
                                          'Declined requests',
                                        ][i],
                                        style: const TextStyle(color: _muted),
                                      ),
                                    ),
                                    Text(
                                      '${counts[i]}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                LinearProgressIndicator(
                                  value: (counts[i] as num) / total,
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(6),
                                  color: [
                                    const Color(0xff246bcc),
                                    const Color(0xff209369),
                                    _gold,
                                  ][i],
                                  backgroundColor: const Color(0xffedf1f6),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                  ),
                ),
                panel(
                  'Madrassas by region',
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: desktop ? 180 : 0),
                    child: empty(
                      Icons.map_outlined,
                      'Regional overview not connected',
                      'Regional school totals are not available in this workspace yet.',
                    ),
                  ),
                ),
                panel(
                  'Onboarding pathway',
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: desktop ? 180 : 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final step in [
                          (Icons.edit_note, 'Request submitted'),
                          (
                            Icons.fact_check_outlined,
                            'Independent office review',
                          ),
                          (Icons.domain, 'Approved request handed to IT'),
                          (
                            Icons.mark_email_read_outlined,
                            'Admin invitation & activation',
                          ),
                        ])
                          Row(
                            children: [
                              Icon(step.$1, color: _gold, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  step.$2,
                                  style: const TextStyle(color: _ink),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              grid([
                panel(
                  'Madrassa requests',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xfff5f7fa),
                        child: const Text(
                          'REQUESTS & DECISIONS',
                          style: TextStyle(
                            color: _muted,
                            fontSize: AfaqDesign.secondarySize,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (recent == null)
                        Text(
                          busy
                              ? 'Loading requests...'
                              : 'Requests could not be loaded. Refresh to try again.',
                          style: const TextStyle(color: _muted, height: 1.6),
                        )
                      else if (recent.isEmpty)
                        const Text(
                          'No madrassa requests yet.',
                          style: TextStyle(color: _muted, height: 1.6),
                        )
                      else
                        for (final record in recent.take(5).whereType<Map>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${record['schoolName'] ?? 'Madrassa request'}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${record['requestedCode'] ?? 'Code unavailable'}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: AfaqDesign.secondarySize,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  switch (record['status']) {
                                    'REQUESTED' => 'Awaiting decision',
                                    'APPROVED' => 'Approved',
                                    'REJECTED' => 'Declined',
                                    _ => 'Status unavailable',
                                  },
                                  style: const TextStyle(
                                    color: _gold,
                                    fontSize: AfaqDesign.secondarySize,
                                  ),
                                ),
                                const Divider(height: 14),
                              ],
                            ),
                          ),
                      const SizedBox(height: 12),
                      link('Review pending applications', onReview),
                      link('View approved onboarding', onApproved),
                    ],
                  ),
                  action: link('View all', onApplications),
                ),
                panel(
                  'Office activity',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.history, color: _gold, size: 32),
                      const SizedBox(height: 14),
                      const Text(
                        'Decisions and account changes',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Open office history for recorded actions and their details. Activity is not streamed on this overview.',
                        style: TextStyle(color: _muted, height: 1.6),
                      ),
                      const SizedBox(height: 12),
                      link('Follow office decisions', onHistory),
                    ],
                  ),
                ),
                panel(
                  'Quick actions',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : onApplications,
                        icon: const Icon(Icons.domain_add_outlined),
                        label: const Text('Review madrassa requests'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onAccounts,
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Manage company access'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'School users are managed by their madrassa administrator.',
                        style: TextStyle(color: _muted, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfff4ecdc), Color(0xfffffcf6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: _gold, size: 38),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Our Mission',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Stronger madrassas. Brighter futures. Support learning through responsible decisions and trusted school communities.',
                            style: TextStyle(color: _muted, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'AFAQ  /  Company office                       Knowledge • Character • Brighter Futures',
                style: TextStyle(color: _muted, fontSize: AfaqDesign.secondarySize),
              ),
            ],
          ),
        );
      },
    );
  }
}
