import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'dashboard_views.dart';
import 'foundation_ui.dart';

class SectionSpec {
  const SectionSpec(this.title, this.path, this.icon, this.purpose);

  final String title;
  final String path;
  final IconData icon;
  final String purpose;
}

List<SectionSpec> sectionsForRole(String role) => switch (role) {
  'ADMIN' => const [
    SectionSpec(
      'Home',
      '/api/reports/dashboard',
      Icons.home_outlined,
      'Your foundation at a glance',
    ),
    SectionSpec(
      'Students',
      '/api/students?page=1&pageSize=20',
      Icons.groups_outlined,
      'Student records',
    ),
    SectionSpec(
      'Classes',
      '/api/classes',
      Icons.menu_book_outlined,
      'Classes across the school',
    ),
    SectionSpec(
      'Attendance',
      '/api/reports/attendance/summary',
      Icons.event_available_outlined,
      'Saved attendance records',
    ),
    SectionSpec(
      'Finance',
      '/api/reports/finance/home',
      Icons.account_balance_wallet_outlined,
      'Financial overview',
    ),
    SectionSpec(
      'Courses',
      '/api/courses',
      Icons.auto_stories_outlined,
      'Online courses and subjects',
    ),
    SectionSpec(
      'Course access',
      '/api/courses/access-requests',
      Icons.verified_user_outlined,
      'Requests for office review',
    ),
  ],
  'ACCOUNTANT' => const [
    SectionSpec(
      'Home',
      '/api/reports/finance/home',
      Icons.home_outlined,
      'Your finance overview',
    ),
    SectionSpec(
      'Invoices',
      '/api/invoices?page=1&pageSize=20',
      Icons.receipt_long_outlined,
      'Issued invoices',
    ),
    SectionSpec(
      'Payments',
      '/api/payments?page=1&pageSize=20',
      Icons.payments_outlined,
      'Payment records',
    ),
    SectionSpec(
      'Course access',
      '/api/courses/access-requests',
      Icons.verified_user_outlined,
      'Course payment follow-up',
    ),
  ],
  'TEACHER' => const [
    SectionSpec(
      'Home',
      '/api/reports/teacher-dashboard',
      Icons.home_outlined,
      'Your teaching day',
    ),
    SectionSpec(
      'My classes',
      '/api/classes',
      Icons.menu_book_outlined,
      'Classes assigned to you',
    ),
    SectionSpec(
      'My courses',
      '/api/teaching/courses',
      Icons.auto_stories_outlined,
      'Courses assigned to you',
    ),
    SectionSpec(
      'School updates',
      '/api/announcements',
      Icons.campaign_outlined,
      'Notices for teaching staff',
    ),
  ],
  'PARENT' => const [
    SectionSpec(
      'Home',
      '/api/parent-portal/me',
      Icons.home_outlined,
      'Your family at a glance',
    ),
    SectionSpec(
      'My children',
      '/api/parent-portal/students',
      Icons.school_outlined,
      'Students linked to your account',
    ),
    SectionSpec(
      'School updates',
      '/api/parent-portal/announcements',
      Icons.campaign_outlined,
      'News for your family',
    ),
  ],
  'LEARNER' => const [
    SectionSpec(
      'Home',
      '/api/learner/me',
      Icons.home_outlined,
      'Your learning space',
    ),
    SectionSpec(
      'My courses',
      '/api/learner/courses',
      Icons.auto_stories_outlined,
      'Courses open to you',
    ),
    SectionSpec(
      'My progress',
      '/api/learner/progress',
      Icons.trending_up_outlined,
      'Your learning progress',
    ),
    SectionSpec(
      'My billing',
      '/api/learner/finance',
      Icons.receipt_long_outlined,
      'Your invoices',
    ),
    SectionSpec(
      'My updates',
      '/api/learner/announcements',
      Icons.campaign_outlined,
      'Your learning notices',
    ),
  ],
  _ => const [],
};

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;
  late Future<dynamic> currentData;
  late List<SectionSpec> sections;

  @override
  void initState() {
    super.initState();
    sections = sectionsForRole(widget.state.session!.role);
    currentData = sections.isEmpty
        ? Future.value(null)
        : widget.state.load(sections.first.path);
  }

  void selectSection(int index) {
    if (index != selectedIndex) {
      setState(() {
        selectedIndex = index;
        currentData = widget.state.load(sections[index].path);
      });
    }
    scaffoldKey.currentState?.closeDrawer();
  }

  void refresh() {
    setState(() {
      currentData = widget.state.load(sections[selectedIndex].path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.state.session;
    if (session == null) return const SizedBox.shrink();
    if (sections.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No pages are available for this account.')),
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < 860;
    final section = sections[selectedIndex];
    final firstName = session.fullName.trim().split(' ').first;
    final visibleTabs = sections.length > 4 ? 3 : sections.length;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: paper,
      drawer: narrow
          ? Drawer(backgroundColor: ink, child: navigation(session))
          : null,
      appBar: narrow
          ? AppBar(
              toolbarHeight: 68,
              title: Text(
                section.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh page',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: widget.state.signOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      bottomNavigationBar: narrow
          ? NavigationBar(
              selectedIndex: selectedIndex < visibleTabs
                  ? selectedIndex
                  : visibleTabs,
              onDestinationSelected: (index) {
                if (index == visibleTabs && sections.length > visibleTabs) {
                  scaffoldKey.currentState?.openDrawer();
                } else {
                  selectSection(index);
                }
              },
              destinations: [
                for (var index = 0; index < visibleTabs; index++)
                  NavigationDestination(
                    icon: Icon(sections[index].icon),
                    selectedIcon: Icon(sections[index].icon, color: gold),
                    label: sections[index].title,
                  ),
                if (sections.length > visibleTabs)
                  const NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!narrow)
            SizedBox(
              width: 266,
              child: ColoredBox(color: ink, child: navigation(session)),
            ),
          Expanded(
            child: Column(
              children: [
                if (!narrow) desktopHeader(session, firstName),
                Expanded(
                  child: PatternBackdrop(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        refresh();
                        try {
                          await currentData;
                        } catch (_) {}
                      },
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 19 : 36,
                          narrow ? 26 : 36,
                          narrow ? 19 : 36,
                          42,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionLabel(
                                    selectedIndex == 0
                                        ? 'Assalamu alaikum'
                                        : section.purpose,
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    selectedIndex == 0
                                        ? 'Welcome back, $firstName'
                                        : section.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    selectedIndex == 0
                                        ? section.purpose
                                        : 'Your ${section.title.toLowerCase()} in one place.',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  FutureBuilder<dynamic>(
                                    future: currentData,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState !=
                                          ConnectionState.done) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(48),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                      if (snapshot.hasError) {
                                        return SurfacePanel(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.info_outline_rounded,
                                                color: gold,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                snapshot.error is ApiException
                                                    ? (snapshot.error!
                                                              as ApiException)
                                                          .message
                                                    : 'This page is unavailable right now.',
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton(
                                                onPressed: refresh,
                                                child: const Text('Try again'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      if (selectedIndex == 0) {
                                        return DashboardView(
                                          role: session.role,
                                          data: snapshot.data,
                                          onOpenSection: selectSection,
                                        );
                                      }
                                      if (section.title == 'Attendance') {
                                        return AttendanceSummaryView(
                                          data: snapshot.data,
                                        );
                                      }
                                      return SectionContent(
                                        role: session.role,
                                        title: section.title,
                                        data: snapshot.data,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget desktopHeader(AuthSession session, String firstName) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          const Text(
            'MODERN ISLAMIC FOUNDATION',
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh page',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(0x1FB78A2F),
            child: Text(
              firstName.isEmpty ? '?' : firstName[0].toUpperCase(),
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              session.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.state.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget navigation(AuthSession session) {
    Widget tile(int index) {
      final section = sections[index];
      final selected = selectedIndex == index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: ListTile(
            leading: Icon(
              section.icon,
              color: selected ? const Color(0xFFE8C778) : Colors.white70,
            ),
            title: Text(
              section.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            selected: selected,
            onTap: () => selectSection(index),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 20),
            child: BrandMark(light: true, compact: true),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 23),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
                  child: SectionLabel('Start here', color: Color(0xFFDFC68F)),
                ),
                tile(0),
                if (sections.length > 1) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 27, 24, 10),
                    child: SectionLabel('Your pages', color: Color(0xFFDFC68F)),
                  ),
                  for (var index = 1; index < sections.length; index++)
                    tile(index),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: gold.withValues(alpha: 0.25),
                  child: const Icon(Icons.person_outline, color: Colors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _roleLabel(session.role),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'ADMIN' => 'Administration',
  'ACCOUNTANT' => 'Finance',
  'TEACHER' => 'Teaching',
  'PARENT' => 'Family',
  'LEARNER' => 'Learning',
  _ => 'Account',
};

class SectionContent extends StatelessWidget {
  const SectionContent({
    super.key,
    required this.role,
    required this.title,
    required this.data,
  });

  final String role;
  final String title;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final map = data is Map<String, dynamic>
        ? data as Map<String, dynamic>
        : null;
    final records = data is List ? data as List : null;

    if (records != null) {
      if (records.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(26),
            child: Text('Nothing to show here yet.'),
          ),
        );
      }
      return _RecordGrid(records: records);
    }

    if (map != null) {
      final metrics = metricsFor(role, title, map);
      final children = map['items'] is List
          ? map['items'] as List
          : map['students'] is List
          ? map['students'] as List
          : map['classes'] is List
          ? map['classes'] as List
          : map['courses'] is List
          ? map['courses'] as List
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metrics.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width > 760
                    ? 3
                    : width > 470
                    ? 2
                    : 1;
                final cardWidth = (width - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: cardWidth,
                          child: MetricCard(label: metric.$1, value: metric.$2),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          if (children != null && children.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              role == 'PARENT'
                  ? 'Your children'
                  : title == 'Teaching home'
                  ? 'Your classes'
                  : 'Recent records',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _RecordGrid(records: children),
          ],
          if (metrics.isEmpty && (children == null || children.isEmpty))
            const Card(
              child: Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'Your information will appear here as it becomes available.',
                ),
              ),
            ),
        ],
      );
    }

    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Text('Nothing to show here yet.'),
      ),
    );
  }
}

class _RecordGrid extends StatelessWidget {
  const _RecordGrid({required this.records});

  final List records;

  @override
  Widget build(BuildContext context) {
    final items = records.whereType<Map<String, dynamic>>().toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (record) => SizedBox(
                  width: width,
                  child: RecordCard(record: record),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

List<(String, String)> metricsFor(
  String role,
  String title,
  Map<String, dynamic> data,
) {
  String value(dynamic source, String key) =>
      source is Map<String, dynamic> ? (source[key]?.toString() ?? '0') : '0';

  if (role == 'ADMIN' && title == 'Finance') {
    final finance = data['finance'];
    return [
      ('Invoices', value(finance?['invoices'], 'total')),
      ('Collected', value(finance?['collections'], 'collectedAmount')),
      ('Outstanding', value(finance?['invoices'], 'outstandingBalance')),
    ];
  }
  if (role == 'TEACHER' && title == 'Teaching home') {
    final summary = data['summary'];
    return [
      ('Classes', value(summary, 'assignedClasses')),
      ('Students', value(summary, 'assignedStudents')),
      ('Attendance today', value(summary, 'attendanceMarkedToday')),
    ];
  }
  if (role == 'PARENT') {
    return [
      (
        'Linked students',
        (data['students'] as List?)?.length.toString() ?? '0',
      ),
    ];
  }
  if (role == 'LEARNER' && title == 'Learning home') {
    final student = data['student'];
    return [
      ('Your name', value(student, 'fullName')),
      ('Admission number', value(student, 'admissionNo')),
      ('Study path', value(student, 'programCategory').replaceAll('_', ' ')),
    ];
  }
  if (role == 'LEARNER' && title == 'My progress') {
    final summary = data['summary'];
    return [
      ('Active courses', value(summary, 'activeCourses')),
      ('Completed lessons', value(summary, 'completedLessons')),
      ('Average progress', '${value(summary, 'averageProgressPercent')}%'),
    ];
  }
  return [];
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    return DashboardMetric(
      label: label.toUpperCase(),
      value: value,
      icon: lower.contains('course')
          ? Icons.auto_stories_outlined
          : lower.contains('progress')
          ? Icons.trending_up_outlined
          : Icons.receipt_long_outlined,
      accent: lower.contains('outstanding') ? gold : blue,
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final subject = record['subject'] is Map ? record['subject'] as Map : null;
    final course = record['course'] is Map ? record['course'] as Map : null;
    final lesson = record['lesson'] is Map ? record['lesson'] as Map : null;
    final currentClass = record['currentClass'] is Map
        ? record['currentClass'] as Map
        : null;
    final teacher = record['teacher'] is Map ? record['teacher'] as Map : null;
    final stats = record['stats'] is Map ? record['stats'] as Map : null;

    final title =
        lesson?['title'] ??
        record['title'] ??
        record['fullName'] ??
        record['invoiceNo'] ??
        record['name'] ??
        record['reference'] ??
        course?['title'] ??
        'Record';
    final summary =
        record['summary'] ??
        record['message'] ??
        record['level'] ??
        course?['title'];
    final status =
        record['status'] ??
        record['publicationStatus'] ??
        record['accessState'];
    final details = [
      if (record['admissionNo'] != null) record['admissionNo'].toString(),
      if (currentClass?['name'] != null) currentClass!['name'].toString(),
      if (teacher?['fullName'] != null) teacher!['fullName'].toString(),
      if (stats?['currentStudents'] != null)
        'Students: ${stats!['currentStudents']}',
      if (subject?['name'] != null) subject!['name'].toString(),
      if (record['amountDue'] != null)
        '${record['currency'] ?? 'TZS'} ${record['amountDue']}',
      if (record['amount'] != null)
        '${record['currency'] ?? 'TZS'} ${record['amount']}',
      if (record['balanceRemaining'] != null)
        'Balance ${record['balanceRemaining']}',
      if (record['progressPercent'] != null)
        '${record['progressPercent']}% complete',
    ].join('  •  ');
    final icon = record['admissionNo'] != null
        ? Icons.school_outlined
        : record['invoiceNo'] != null
        ? Icons.receipt_long_outlined
        : stats != null
        ? Icons.menu_book_outlined
        : record['message'] != null
        ? Icons.campaign_outlined
        : Icons.auto_stories_outlined;

    return SurfacePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: blue, size: 23),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toString().replaceAll('_', ' '),
                      style: const TextStyle(
                        color: forest,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (summary != null && summary.toString().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    summary.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8B6A29),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
