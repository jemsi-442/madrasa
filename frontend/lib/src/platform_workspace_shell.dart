import 'package:flutter/material.dart';
import 'status_badge.dart';
import 'app_layout.dart';
import 'design_tokens.dart';
import 'workspace_chrome.dart';
import 'platform_office_dashboard.dart';
import 'platform_it_dashboard.dart';
import 'it_workspace_visuals.dart';

const _navy = AfaqDesign.ink;

enum PlatformPage {
  home,
  madrasas,
  staff,
  curriculum,
  oversight,
  funds,
  reports,
  applications,
  accounts,
  history,
  health,
  sessions,
  incidents,
  updates,
  backups,
  offlineSync,
  integrations,
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
    if (!isAdmin) {
      final text = switch (page) {
        PlatformPage.accounts => (
          'Company accounts',
          'Account status and access history. Read-only company directory.',
        ),
        PlatformPage.history => (
          'Audit trail',
          'Find recorded events and inspect their context.',
        ),
        PlatformPage.sessions => (
          'My sessions',
          'Review devices signed in to your account.',
        ),
        PlatformPage.health => (
          'System health',
          'Database and Redis connectivity at the latest check.',
        ),
        _ => ('', ''),
      };
      if (text.$1.isNotEmpty) {
        return ItPageHeading(title: text.$1, description: text.$2);
      }
    }
    final (heading, description, icon) = switch (page) {
      PlatformPage.applications => (
        'A clear path for every madrassa',
        'Review registration requests in Madrasas. An approved request is not yet an active school.',
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
          Icon(icon, color: _navy, size: AfaqDesign.iconSize),
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
                  '3. Madrasa registration',
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
      (PlatformPage.curriculum, 'Curriculum &', Icons.menu_book_outlined),
      (PlatformPage.oversight, 'Learning Oversight', Icons.insights_outlined),
      (PlatformPage.funds, 'Donors & Funds', Icons.favorite_border),
      (PlatformPage.reports, 'Report', Icons.description_outlined),
    ] else ...[
      (PlatformPage.health, 'System health', Icons.monitor_heart_outlined),
      (PlatformPage.accounts, 'Company accounts', Icons.badge_outlined),
      (PlatformPage.sessions, 'My sessions', Icons.devices_outlined),
      (PlatformPage.history, 'Audit trail', Icons.policy_outlined),
      (
        PlatformPage.incidents,
        'Security Incidents',
        Icons.warning_amber_outlined,
      ),
      (
        PlatformPage.updates,
        'Vulnerabilities & Updates',
        Icons.bug_report_outlined,
      ),
      (PlatformPage.backups, 'Backups & Recovery', Icons.backup_outlined),
      (PlatformPage.offlineSync, 'Offline Sync', Icons.sync_outlined),
      (
        PlatformPage.integrations,
        'Integrations & Settings',
        Icons.settings_outlined,
      ),
    ],
  ];

  String get title => switch (page) {
    PlatformPage.integrations => 'Integrations & Settings',
    PlatformPage.offlineSync => 'Offline Sync',
    PlatformPage.backups => 'Backups & Recovery',
    PlatformPage.updates => 'Vulnerabilities & Updates',
    PlatformPage.incidents => 'Security Incidents',
    PlatformPage.home => isAdmin ? 'Office overview' : 'Operations overview',
    PlatformPage.madrasas => 'Madrasa directory',
    PlatformPage.staff => 'Users & Permissions',
    PlatformPage.curriculum => 'Curriculum & Subjects',
    PlatformPage.oversight => 'Learning Oversight',
    PlatformPage.funds => 'Donors & Funds',
    PlatformPage.reports => 'Institutional Reports',
    PlatformPage.applications => 'Madrasas / Applications',
    PlatformPage.accounts => 'Company accounts',
    PlatformPage.history =>
      isAdmin ? 'Settings & Security' : 'Security activity',
    PlatformPage.health => 'Service availability',
    PlatformPage.sessions =>
      isAdmin ? 'Settings & Security' : 'Your signed-in devices',
  };

  PlatformPage get navigationPage => switch (page) {
    PlatformPage.applications => PlatformPage.madrasas,
    PlatformPage.accounts when isAdmin => PlatformPage.staff,
    PlatformPage.sessions when isAdmin => PlatformPage.history,
    _ => page,
  };

  Widget navigation(BuildContext context, {required bool drawer}) =>
      WorkspaceSidebar(
        items: [for (final item in destinations) (item.$2, item.$3)],
        selected: destinations.indexWhere((item) => item.$1 == navigationPage),
        roleLabel: isAdmin ? 'Company office' : 'IT operations',
        enabled: !busy,
        collapsed: !drawer && collapsed,
        onClose: drawer ? () => Navigator.pop(context) : null,
        onSelect: (index) {
          if (drawer) Navigator.pop(context);
          onNavigate(destinations[index].$1);
        },
      );

  // Related destinations are shortcuts, not sequential approval gates.
  List<(PlatformPage, String)> get relatedDestinations => switch (page) {
    PlatformPage.health => [
      (PlatformPage.integrations, 'Check configuration'),
      (PlatformPage.incidents, 'Record or review incident'),
    ],
    PlatformPage.accounts => [
      (PlatformPage.history, 'Review access history'),
      (PlatformPage.sessions, 'My sessions only'),
    ],
    PlatformPage.sessions => [
      (PlatformPage.history, 'Review audit logs'),
      (PlatformPage.incidents, 'Record or review incident'),
    ],
    PlatformPage.history => [
      (PlatformPage.incidents, 'Investigate in incidents'),
      (PlatformPage.accounts, 'Check company access'),
    ],
    PlatformPage.incidents => [
      (PlatformPage.history, 'Inspect audit evidence'),
      (PlatformPage.health, 'Check service health'),
      (PlatformPage.sessions, 'My sessions only'),
    ],
    PlatformPage.updates => [
      (PlatformPage.incidents, 'Review incidents'),
      (PlatformPage.backups, 'Check recovery readiness'),
    ],
    PlatformPage.backups => [
      (PlatformPage.history, 'Review audit logs'),
      (PlatformPage.health, 'Check service health'),
    ],
    PlatformPage.offlineSync => [
      (PlatformPage.incidents, 'Record or review incident'),
      (PlatformPage.integrations, 'Check configuration'),
    ],
    PlatformPage.integrations => [
      (PlatformPage.health, 'Check service health'),
      (PlatformPage.history, 'Review audit logs'),
    ],
    _ => [],
  };

  Widget relatedActions() => Material(
    color: Colors.white,
    child: SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final item in relatedDestinations)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: busy ? null : () => onNavigate(item.$1),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(item.$2),
                ),
              ),
          ],
        ),
      ),
    ),
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
                  if (!isAdmin && relatedDestinations.isNotEmpty)
                    relatedActions(),
                  Expanded(
                    child: isAdmin ? child : ItWorkspaceSurface(child: child),
                  ),
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
    this.onIncident,
  });
  final bool isAdmin, busy;
  final String name;
  final Map<String, dynamic>? snapshot;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<PlatformPage> onNavigate;
  final Widget? healthPanel;
  final VoidCallback? onReviewPending, onApproved;
  final ValueChanged<String>? onIncident;

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
          onApplications: () => onNavigate(PlatformPage.madrasas),
          onLearning: () => onNavigate(PlatformPage.oversight),
          onFunds: () => onNavigate(PlatformPage.funds),
          onReports: () => onNavigate(PlatformPage.reports),
          onReview: onReviewPending,
          onApproved: onApproved,
        );
      }
      return PlatformItDashboard(
        snapshot: snapshot,
        busy: busy,
        error: error,
        onRefresh: onRefresh,
        onHealth: () => onNavigate(PlatformPage.health),
        onIncidents: () => onNavigate(PlatformPage.incidents),
        onIncident: onIncident,
        onAccounts: () => onNavigate(PlatformPage.accounts),
        onAudit: () => onNavigate(PlatformPage.history),
        onSessions: () => onNavigate(PlatformPage.sessions),
      );
    },
  );
}
