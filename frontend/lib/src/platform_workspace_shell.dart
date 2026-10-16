import 'package:flutter/material.dart';
import 'status_badge.dart';
import 'shared_feedback.dart';
import 'app_layout.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'platform_office_dashboard.dart';

const _navy = AfaqDesign.ink;
const _gold = AfaqDesign.gold;

enum PlatformPage {
  home,
  madrasas,
  staff,
  curriculum,
  applications,
  accounts,
  history,
  setup,
  health,
  sessions,
}

class PlatformAccountStatus extends StatelessWidget {
  const PlatformAccountStatus({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'ACTIVE' => (
        'Active',
        const Color(0xff216744),
        Icons.check_circle_outline,
      ),
      'DISABLED' => ('Disabled', const Color(0xff984149), Icons.block),
      _ => ('Status unavailable', const Color(0xff526777), Icons.help_outline),
    };
    return AfaqStatusBadge(label: label, color: color, icon: icon);
  }
}

class PlatformApplicationHeading extends StatelessWidget {
  const PlatformApplicationHeading({super.key, required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (record['status']) {
      'REQUESTED' => (
        'Awaiting decision',
        const Color(0xff856019),
        Icons.schedule,
      ),
      'APPROVED' => (
        'Approved',
        const Color(0xff216744),
        Icons.check_circle_outline,
      ),
      'REJECTED' => (
        'Declined',
        const Color(0xff984149),
        Icons.cancel_outlined,
      ),
      _ => ('Status unavailable', const Color(0xff526777), Icons.help_outline),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${record['schoolName'] ?? 'Madrassa request'}',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            AfaqStatusBadge(label: label, color: color, icon: icon),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'REQUESTED SCHOOL CODE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: Color(0xff667984),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText('${record['requestedCode'] ?? 'Not supplied'}'),
        const SizedBox(height: 12),
        const Text(
          'PROPOSED MADRASSA ADMIN',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: Color(0xff667984),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText('${record['adminEmail'] ?? 'Not supplied'}'),
        const Divider(height: 28),
      ],
    );
  }
}

class PlatformTaskIntro extends StatelessWidget {
  const PlatformTaskIntro({
    super.key,
    required this.page,
    required this.isAdmin,
  });

  final PlatformPage page;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final (heading, description, icon) = switch (page) {
      PlatformPage.applications => (
        'A clear path for every madrassa',
        'Submit a request or review one independently. Approval comes before IT setup; an approved request is not yet an active school.',
        Icons.school_outlined,
      ),
      PlatformPage.accounts => (
        'The people behind Afaq',
        'Review company access and account status. School staff accounts belong to each madrassa and are managed separately.',
        Icons.badge_outlined,
      ),
      PlatformPage.history => (
        isAdmin
            ? 'Follow every office decision'
            : 'Investigate platform activity',
        isAdmin
            ? 'Use the filters to find requests, decisions and company account changes, then open a record for its details.'
            : 'Filter recorded events and inspect their context. A failed login identifies a targeted account, not a verified person.',
        Icons.history_rounded,
      ),
      PlatformPage.health => (
        'Check before you act',
        'Review service availability and the time of the latest check. Refresh to request a new snapshot; old results are not live monitoring.',
        Icons.monitor_heart_outlined,
      ),
      PlatformPage.sessions => (
        'Know where you are signed in',
        'Review your own active sessions. Revoking your current session signs you out; other accounts are not shown here.',
        Icons.devices_outlined,
      ),
      _ => ('', '', Icons.info_outline),
    };
    if (heading.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xffeef3f2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdce5e1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _navy, size: 28),
          const SizedBox(height: 14),
          Text(
            heading,
            style: const TextStyle(
              fontFamily: 'NotoSerifDisplay',
              fontSize: 25,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Color(0xff526777), height: 1.6),
          ),
          if (page == PlatformPage.applications) ...[
            const SizedBox(height: 18),
            const Text(
              'APPLICATION WORKFLOW',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final step in [
                  '1. Request',
                  '2. Independent review',
                  '3. IT setup',
                  '4. Admin invitation',
                ])
                  Chip(
                    label: Text(step),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PlatformWorkspaceShell extends StatefulWidget {
  const PlatformWorkspaceShell({
    super.key,
    required this.isAdmin,
    required this.name,
    required this.page,
    required this.onNavigate,
    required this.busy,
    required this.actions,
    required this.child,
  });
  final bool isAdmin, busy;
  final String name;
  final PlatformPage page;
  final ValueChanged<PlatformPage> onNavigate;
  final List<Widget> actions;
  final Widget child;

  @override
  State<PlatformWorkspaceShell> createState() => _PlatformWorkspaceShellState();
}

class _PlatformWorkspaceShellState extends State<PlatformWorkspaceShell> {
  bool collapsed = false;
  bool get isAdmin => widget.isAdmin;
  bool get busy => widget.busy;
  String get name => widget.name;
  PlatformPage get page => widget.page;
  ValueChanged<PlatformPage> get onNavigate => widget.onNavigate;
  List<Widget> get actions => widget.actions;
  Widget get child => widget.child;

  List<(PlatformPage, String, IconData)> get destinations => [
    (PlatformPage.home, 'Overview', Icons.grid_view_rounded),
    if (isAdmin) ...[
      (PlatformPage.madrasas, 'Madrasas', Icons.account_balance_outlined),
      (PlatformPage.staff, 'Users & Permissions', Icons.people_outline),
      (
        PlatformPage.curriculum,
        'Curriculum & Subjects',
        Icons.menu_book_outlined,
      ),
      (PlatformPage.accounts, 'Company accounts', Icons.badge_outlined),
      (PlatformPage.history, 'Office history', Icons.history_rounded),
    ] else ...[
      (PlatformPage.health, 'System health', Icons.monitor_heart_outlined),
      (PlatformPage.history, 'Audit trail', Icons.policy_outlined),
      (PlatformPage.setup, 'Madrassa setup', Icons.domain_add_outlined),
      (PlatformPage.sessions, 'My sessions', Icons.devices_outlined),
    ],
  ];

  String get title => switch (page) {
    PlatformPage.home => isAdmin ? 'Office overview' : 'Operations overview',
    PlatformPage.madrasas => 'Madrasa directory',
    PlatformPage.staff => 'Users & Permissions',
    PlatformPage.curriculum => 'Curriculum & Subjects',
    PlatformPage.applications => 'Madrasas / Applications',
    PlatformPage.accounts => 'People & access',
    PlatformPage.history => isAdmin ? 'Office activity' : 'Security activity',
    PlatformPage.setup => 'School provisioning',
    PlatformPage.health => 'Service availability',
    PlatformPage.sessions => 'Your signed-in devices',
  };

  Widget navigation(BuildContext context, {required bool drawer}) =>
      WorkspaceSidebar(
        items: [for (final item in destinations) (item.$2, item.$3)],
        selected: destinations.indexWhere(
          (item) =>
              item.$1 ==
              (page == PlatformPage.applications
                  ? PlatformPage.madrasas
                  : page),
        ),
        roleLabel: isAdmin ? 'Company office' : 'IT operations',
        enabled: !busy,
        collapsed: !drawer && collapsed,
        onClose: drawer ? () => Navigator.pop(context) : null,
        onSelect: (index) {
          if (drawer) Navigator.pop(context);
          onNavigate(destinations[index].$1);
        },
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          !AppLayoutScope.isMobile(context) &&
          constraints.maxWidth >= AfaqDesign.desktopBreakpoint;
      return Scaffold(
        backgroundColor: AfaqDesign.canvas,
        drawer: wide
            ? null
            : Drawer(width: 264, child: navigation(context, drawer: true)),
        body: Row(
          children: [
            if (wide)
              WorkspaceDesktopSidebar(
                collapsed: collapsed,
                child: navigation(context, drawer: false),
              ),
            Expanded(
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    child: SafeArea(
                      bottom: false,
                      child: WorkspaceHeaderSurface(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 20 : 8,
                          vertical: wide ? 0 : 10,
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) => WorkspaceSidebarToggle(
                                control: !wide
                                    ? SidebarControl.open
                                    : collapsed
                                    ? SidebarControl.expand
                                    : SidebarControl.collapse,
                                onPressed: () {
                                  if (wide) {
                                    setState(() => collapsed = !collapsed);
                                  } else {
                                    Scaffold.of(context).openDrawer();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: _navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  if (wide)
                                    Text(
                                      isAdmin
                                          ? 'Afaq / Company office'
                                          : 'Afaq / IT operations',
                                      style: const TextStyle(
                                        color: Color(0xff6a7881),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child),
                  const WorkspaceFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PlatformOverview extends StatelessWidget {
  const PlatformOverview({
    super.key,
    required this.isAdmin,
    required this.name,
    required this.snapshot,
    required this.busy,
    required this.error,
    required this.onRefresh,
    required this.onNavigate,
    this.healthPanel,
    this.onReviewPending,
    this.onApproved,
  });
  final bool isAdmin, busy;
  final String name;
  final Map<String, dynamic>? snapshot;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<PlatformPage> onNavigate;
  final Widget? healthPanel;
  final VoidCallback? onReviewPending, onApproved;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (isAdmin) {
        return PlatformOfficeDashboard(
          name: name,
          snapshot: snapshot,
          busy: busy,
          error: error,
          onRefresh: onRefresh,
          onApplications: () => onNavigate(PlatformPage.applications),
          onAccounts: () => onNavigate(PlatformPage.accounts),
          onHistory: () => onNavigate(PlatformPage.history),
          onReview: onReviewPending,
          onApproved: onApproved,
        );
      }
      final small = constraints.maxWidth < 650;
      return SingleChildScrollView(
        padding: EdgeInsets.all(small ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YOUR OPERATIONS DESK',
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Assalamu alaikum, $name',
              style: TextStyle(
                fontFamily: 'NotoSerifDisplay',
                fontSize: small ? 27 : 36,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isAdmin
                  ? 'Review madrassa requests, coordinate onboarding and manage company access.'
                  : 'Check service availability, review recorded activity and prepare approved madrassas.',
              style: const TextStyle(color: Color(0xff667984), height: 1.6),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot == null
                        ? 'No snapshot loaded'
                        : 'Snapshot: ${snapshot!['checkedAt'] ?? 'Time not supplied'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff667984),
                    ),
                  ),
                ),
                WorkspaceRefreshButton(
                  tooltip: 'Refresh overview',
                  onRefresh: onRefresh,
                  loading: busy,
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Color(0xffa32e2e)),
                  ),
                ),
              ),
            if (healthPanel != null) healthPanel!,
            const SizedBox(height: 28),
            const Text(
              'Quick actions',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, bounds) {
                final columns = bounds.maxWidth >= 900
                    ? 3
                    : bounds.maxWidth >= 580
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final item in [
                      (
                        PlatformPage.history,
                        'Review security activity',
                        'Inspect recorded events. An audit log is not a threat-detection verdict.',
                        Icons.policy_outlined,
                      ),
                      (
                        PlatformPage.setup,
                        'Prepare approved madrassas',
                        'Continue technical setup after the office approval process.',
                        Icons.domain_add_outlined,
                      ),
                      (
                        PlatformPage.sessions,
                        'Review your sessions',
                        'Manage your own signed-in devices and access.',
                        Icons.devices_outlined,
                      ),
                    ])
                      SizedBox(
                        width: (bounds.maxWidth - (columns - 1) * 16) / columns,
                        child: AfaqActionTile(
                          title: item.$2,
                          subtitle: item.$3,
                          icon: item.$4,
                          onTap: busy ? null : () => onNavigate(item.$1),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'School academic and financial records remain outside this workspace.',
              style: const TextStyle(color: Color(0xff667984), fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
