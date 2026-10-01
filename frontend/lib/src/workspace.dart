import 'package:flutter/material.dart';

import 'keyboard_scrolling.dart';
import 'api_client.dart';
import 'accountant_page.dart';
import 'finance_operations_page.dart';
import 'finance_reports_page.dart';
import 'app_state.dart';
import 'app_layout.dart';
import 'dashboard_views.dart';
import 'foundation_ui.dart';
import 'dashboard_components.dart';
import 'workspace_chrome.dart';
import 'student_registry_page.dart';
import 'classes_page.dart';
import 'attendance_page.dart';
import 'attendance_register_page.dart';
import 'admin_academic_pages.dart';
import 'admin_overview.dart';
import 'donations_page.dart';
import 'teacher_teaching_pages.dart';
import 'teacher_students_page.dart';
import 'teacher_quran_page.dart';
import 'parent_portal_page.dart';
import 'family_messages_page.dart';
import 'assessments_page.dart';
import 'student_reports_page.dart';
import 'learner_portal_page.dart';
import 'learner_courses_page.dart';

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
      'Overview',
      '/api/admin/overview',
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
      'Teachers',
      '/api/admin/teachers',
      Icons.person_outline,
      'Teaching accounts, assignments and workload',
    ),
    SectionSpec(
      'Subjects',
      '/api/admin/subjects',
      Icons.layers_outlined,
      'Manage the subject catalog and learning courses',
    ),
    SectionSpec(
      'Attendance',
      '/api/reports/attendance/summary',
      Icons.event_available_outlined,
      'Daily registers and attendance history',
    ),
    SectionSpec(
      'Donations',
      '/api/fundraising/overview',
      Icons.favorite_outline,
      'Manage donors, campaigns and contributions',
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
    SectionSpec(
      'Assessment Review',
      '/api/assessments',
      Icons.fact_check_outlined,
      'Review and publish teacher-recorded results.',
    ),
    SectionSpec(
      'Reports',
      '/api/student-reports',
      Icons.description_outlined,
      'Set reporting periods, review and publish student learning reports.',
    ),
  ],
  'ACCOUNTANT' => const [
    SectionSpec(
      'Home',
      '/api/reports/finance/home',
      Icons.home_outlined,
      'School fees, payment records and follow-up in one workspace.',
    ),
    SectionSpec(
      'Invoices',
      '/api/invoices?page=1&pageSize=20',
      Icons.receipt_long_outlined,
      'Check invoice balances and follow each payment trail.',
    ),
    SectionSpec(
      'Payments',
      '/api/payments?page=1&pageSize=20',
      Icons.payments_outlined,
      'Verify payment status and view confirmed receipts.',
    ),
    SectionSpec(
      'Course access',
      '/api/courses/access-requests',
      Icons.verified_user_outlined,
      'Follow learner requests through invoices and payments.',
    ),
    SectionSpec(
      'Fee structures',
      '/api/fee-structures',
      Icons.price_change_outlined,
      'Set school billing rates and review existing fee structures.',
    ),
    SectionSpec(
      'Expenses',
      '/api/expenses',
      Icons.account_balance_wallet_outlined,
      'Record school costs and keep clear expense records.',
    ),
    SectionSpec(
      'Financial reports',
      '/api/reports/finance/monthly-summary',
      Icons.assessment_outlined,
      'Review monthly collections and expenses, with CSV exports.',
    ),
    SectionSpec(
      'Finance inbox',
      '/api/public-inquiries',
      Icons.mark_email_unread_outlined,
      'Follow up finance questions received by the school office.',
    ),
  ],
  'TEACHER' => const [
    SectionSpec(
      'Dashboard',
      '/api/teacher-workspace/overview',
      Icons.home_outlined,
      'Your classes, learners and teaching tasks in one place.',
    ),
    SectionSpec(
      'My Classes',
      '/api/teacher-workspace/classes',
      Icons.co_present_outlined,
      'Open a class to record attendance and follow student progress.',
    ),
    SectionSpec(
      'My Students',
      '/api/teacher-workspace/students',
      Icons.people_outline,
      'See individual learning records and identify where support is needed.',
    ),
    SectionSpec(
      "Qur'an Tracking",
      '/api/teacher-workspace/quran',
      Icons.menu_book_outlined,
      'Record exactly what each learner read, memorised or revised.',
    ),
    SectionSpec(
      'Attendance',
      '/api/attendance/register',
      Icons.calendar_month_outlined,
      'Record class attendance. Unmarked students stay unmarked.',
    ),
    SectionSpec(
      'My courses',
      '/api/teaching/courses',
      Icons.auto_stories_outlined,
      'Your assigned online courses',
    ),
    SectionSpec(
      'School updates',
      '/api/announcements',
      Icons.campaign_outlined,
      'Notices for teaching staff',
    ),
    SectionSpec(
      'Parent Communication',
      '/api/family-messages/conversations',
      Icons.chat_bubble_outline,
      'Private conversations with verified parents of your assigned students.',
    ),
    SectionSpec(
      'Assessments',
      '/api/assessments',
      Icons.fact_check_outlined,
      'Record scores and feedback, then submit for review.',
    ),
    SectionSpec(
      'Reports',
      '/api/student-reports',
      Icons.description_outlined,
      'Review each learner\'s progress and prepare reports for administrator review.',
    ),
  ],
  'PARENT' => const [
    SectionSpec(
      'Dashboard',
      '/api/parent-portal/me',
      Icons.home_outlined,
      "An overview of your children's learning and school updates.",
    ),
    SectionSpec(
      'My Children',
      '/api/parent-portal/students',
      Icons.people_outline,
      "View your children's profiles, classes and learning records.",
    ),
    SectionSpec(
      'Attendance',
      '/family/attendance',
      Icons.calendar_month_outlined,
      "View your child's attendance records and school notes.",
    ),
    SectionSpec(
      "Qur'an Progress",
      '/family/quran',
      Icons.menu_book_outlined,
      "Follow reading, memorisation and revision, one ayah at a time.",
    ),
    SectionSpec(
      'School updates',
      '/api/parent-portal/announcements',
      Icons.campaign_outlined,
      'Published notices from your school.',
    ),
    SectionSpec(
      'Payments',
      '/family/payments',
      Icons.payments_outlined,
      "Your child's invoices and confirmed payment records.",
    ),
    SectionSpec(
      'Support',
      '/family/support',
      Icons.support_agent_outlined,
      'Find answers and contact the school office.',
    ),
    SectionSpec(
      'Messages',
      '/api/family-messages/conversations',
      Icons.chat_bubble_outline,
      "Stay connected with your child's assigned teacher.",
    ),
    SectionSpec(
      'Academic Progress',
      '/family/academic',
      Icons.bar_chart_outlined,
      "Your child's published subject scores and teacher feedback.",
    ),
    SectionSpec(
      "Reports",
      "/family/reports",
      Icons.description_outlined,
      "View and download your child's published learning reports.",
    ),
  ],
  'LEARNER' => const [
    SectionSpec(
      'Home',
      '/api/learner/me',
      Icons.home_outlined,
      'Your classes, learning records and published results in one place.',
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
    SectionSpec(
      'Classes',
      '/api/learner/workspace/classes',
      Icons.calendar_month_outlined,
      'Your assigned class timetable and upcoming lessons.',
    ),
    SectionSpec(
      'Attendance',
      '/api/learner/workspace/attendance',
      Icons.event_available_outlined,
      'Every recorded day counts. View your attendance history.',
    ),
    SectionSpec(
      "Qur'an Progress",
      '/api/learner/workspace/quran',
      Icons.menu_book_outlined,
      'Follow your memorisation, reading and revision records.',
    ),
    SectionSpec(
      'Academic Progress',
      '/api/learner/workspace/academic',
      Icons.bar_chart_outlined,
      'Your published assessments and teacher feedback.',
    ),
    SectionSpec(
      'Reports',
      '/api/learner/workspace/reports',
      Icons.description_outlined,
      'View and download your published learning reports.',
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
  final contentFocus = FocusNode(debugLabel: 'Workspace content');
  int selectedIndex = 0;
  int refreshToken = 0;
  bool collapsed = false;
  late Future<dynamic> currentData;
  late List<SectionSpec> sections;

  final messagesKey = GlobalKey<FamilyMessagesPageState>();
  final quranKey = GlobalKey<TeacherQuranPageState>();
  String? teachingClassId;
  String? familyChildId;
  FinanceDestination financeDestination = const FinanceDestination(0);
  Map<String, dynamic>? teachingStudent;

  bool get dedicated =>
      sections[selectedIndex].path == '/api/student-reports' ||
      sections[selectedIndex].path == '/api/assessments' ||
      sections[selectedIndex].path == '/api/family-messages/conversations' ||
      widget.state.session?.role == 'PARENT' ||
      widget.state.session?.role == 'ACCOUNTANT' ||
      (widget.state.session?.role == 'LEARNER' &&
          (selectedIndex <= 1 || selectedIndex >= 5)) ||
      (widget.state.session?.role == 'TEACHER' && selectedIndex <= 4) ||
      [
        'Students',
        'Classes',
        'My classes',
        'Attendance',
        'Teachers',
        'Subjects',
        'Donations',
      ].contains(sections[selectedIndex].title);

  @override
  void dispose() {
    contentFocus.dispose();
    super.dispose();
  }

  Future<dynamic> loadCurrent() => dedicated
      ? Future.value(null)
      : widget.state.load(sections[selectedIndex].path);

  @override
  void initState() {
    super.initState();
    sections = sectionsForRole(widget.state.session!.role);
    final remembered = sections.indexWhere(
      (s) => s.path == widget.state.rememberedSection,
    );
    selectedIndex = remembered < 0 ? 0 : remembered;
    financeDestination = FinanceDestination(selectedIndex);
    currentData = sections.isEmpty ? Future.value(null) : loadCurrent();
  }

  Future<bool> leaveTeacherDraft() async {
    if (!(await quranKey.currentState?.confirmLeave() ?? true)) return false;
    return await messagesKey.currentState?.confirmLeave() ?? true;
  }

  void openTeacher(
    int index, {
    String? classId,
    Map<String, dynamic>? student,
  }) async {
    if (!await leaveTeacherDraft() || !mounted) return;
    contentFocus.requestFocus();
    setState(() {
      teachingClassId = classId;
      teachingStudent = student;
      selectedIndex = index;
      widget.state.rememberSection(sections[index].path);
      currentData = loadCurrent();
    });
    scaffoldKey.currentState?.closeDrawer();
  }

  void openFinance(FinanceDestination destination) {
    contentFocus.requestFocus();
    setState(() {
      financeDestination = destination;
      selectedIndex = destination.page;
      widget.state.rememberSection(sections[selectedIndex].path);
    });
    scaffoldKey.currentState?.closeDrawer();
  }

  void selectSection(int index) async {
    if (widget.state.session?.role == 'ACCOUNTANT') {
      openFinance(FinanceDestination(index));
      return;
    }
    if (index != selectedIndex) {
      if (!await leaveTeacherDraft() || !mounted) return;
      contentFocus.requestFocus();
      setState(() {
        teachingStudent = null;
        selectedIndex = index;
        widget.state.rememberSection(sections[index].path);
        currentData = loadCurrent();
      });
    }
    scaffoldKey.currentState?.closeDrawer();
  }

  void requestSignOut() async {
    if (!await leaveTeacherDraft() || !mounted) return;
    await widget.state.signOut();
  }

  void refresh() async {
    if (!await leaveTeacherDraft() || !mounted) return;
    quranKey.currentState?.refreshPage();
    setState(() {
      refreshToken++;
      currentData = loadCurrent();
    });
  }

  Widget pageContent(AuthSession session) {
    final section = sections[selectedIndex];
    if (session.role == 'ACCOUNTANT') {
      if (selectedIndex == 6) {
        return FinanceReportsPage(
          load: widget.state.load,
          exportCsv: widget.state.exportCsv,
          refreshToken: refreshToken,
        );
      }
      if (selectedIndex >= 4) {
        return FinanceOperationsPage(
          key: ValueKey('finance-operations-$selectedIndex'),
          page: selectedIndex,
          load: widget.state.load,
          submit: widget.state.submit,
          update: widget.state.update,
          refreshToken: refreshToken,
        );
      }
      return AccountantPage(
        key: ValueKey('finance-${financeDestination.key}'),
        load: widget.state.load,
        destination: financeDestination,
        onOpen: openFinance,
        refreshToken: refreshToken,
      );
    }
    if (section.path == '/api/student-reports') {
      return StudentReportsPage(
        load: widget.state.load,
        submit: widget.state.submit,
        admin: session.role == 'ADMIN',
        refreshToken: refreshToken,
      );
    }
    if (section.path == '/api/assessments') {
      return AssessmentsPage(
        load: widget.state.load,
        submit: widget.state.submit,
        admin: session.role == 'ADMIN',
        refreshToken: refreshToken,
      );
    }
    if (section.path == '/api/family-messages/conversations') {
      return FamilyMessagesPage(
        key: messagesKey,
        load: widget.state.load,
        submit: widget.state.submit,
        userId: session.userId,
        teacherMode: session.role == 'TEACHER',
        refreshToken: refreshToken,
      );
    }
    if (session.role == 'LEARNER' && selectedIndex == 1) {
      return LearnerCoursesPage(
        load: widget.state.load,
        submit: widget.state.submit,
        apiBaseUrl: widget.state.api.baseUrl,
        refreshToken: refreshToken,
      );
    }
    if (session.role == 'LEARNER' &&
        (selectedIndex == 0 || selectedIndex >= 5)) {
      return LearnerPortalPage(
        key: ValueKey('learner-$selectedIndex'),
        load: widget.state.load,
        page: selectedIndex,
        onOpen: selectSection,
        refreshToken: refreshToken,
      );
    }
    if (session.role == 'PARENT') {
      return ParentPortalPage(
        load: widget.state.load,
        page: selectedIndex,
        childId: familyChildId,
        refreshToken: refreshToken,
        onChildSelected: (id) => setState(() => familyChildId = id),
        onOpen: (index, {childId}) {
          if (childId != null) familyChildId = childId;
          selectSection(index);
        },
      );
    }
    if (session.role == 'TEACHER' && selectedIndex <= 4) {
      return switch (selectedIndex) {
        0 => TeacherOverviewPage(
          load: widget.state.load,
          onOpen: openTeacher,
          refreshToken: refreshToken,
        ),
        1 => TeacherClassesPage(
          load: widget.state.load,
          onOpen: openTeacher,
          refreshToken: refreshToken,
        ),
        2 => TeacherStudentsPage(
          key: ValueKey(
            'teacher-students-$teachingClassId-${teachingStudent?['id']}',
          ),
          load: widget.state.load,
          submit: widget.state.submit,
          onOpen: openTeacher,
          initialClassId: teachingClassId,
          initialStudent: teachingStudent,
          refreshToken: refreshToken,
        ),
        3 => TeacherQuranPage(
          key: quranKey,
          load: widget.state.load,
          submit: widget.state.submit,
          teacherId: session.userId,
          initialClassId: teachingClassId,
          initialStudent: teachingStudent,
        ),
        _ => AttendanceRegisterPage(
          key: ValueKey('teacher-attendance-$teachingClassId'),
          load: widget.state.load,
          submit: widget.state.submit,
          refreshToken: refreshToken,
          teacherMode: true,
          initialClassId: teachingClassId,
        ),
      };
    }
    if (session.role == 'ADMIN' && selectedIndex == 0) {
      return PageResult(
        future: currentData,
        onRetry: refresh,
        builder: (data) => AdminOverview(
          report: recordMap(data),
          onOpen: selectSection,
          submit: widget.state.submit,
          onChanged: refresh,
        ),
      );
    }
    switch (section.title) {
      case 'Teachers':
        return TeachersPage(
          load: widget.state.load,
          submit: widget.state.submit,
          refreshToken: refreshToken,
        );
      case 'Subjects':
        return SubjectsPage(
          load: widget.state.load,
          submit: widget.state.submit,
          refreshToken: refreshToken,
        );
      case 'Donations':
        return DonationsPage(
          load: widget.state.load,
          submit: widget.state.submit,
          refreshToken: refreshToken,
        );
      case 'Students':
        return StudentRegistryPage(
          load: widget.state.load,
          submit: session.role == 'ADMIN' ? widget.state.submit : null,
          refreshToken: refreshToken,
        );
      case 'Classes':
      case 'My classes':
        return ClassesPage(
          load: widget.state.load,
          refreshToken: refreshToken,
          submit: session.role == 'ADMIN' ? widget.state.submit : null,
        );
      case 'Attendance':
        if (session.role == 'ADMIN') {
          return AttendanceRegisterPage(
            load: widget.state.load,
            submit: widget.state.submit,
            refreshToken: refreshToken,
          );
        }
        return AttendancePage(
          load: widget.state.load,
          refreshToken: refreshToken,
        );
      default:
        return PageResult(
          future: currentData,
          onRetry: refresh,
          builder: (data) => selectedIndex == 0
              ? DashboardView(
                  role: session.role,
                  data: data,
                  onOpenSection: selectSection,
                )
              : SectionContent(
                  role: session.role,
                  title: section.title,
                  data: data,
                ),
        );
    }
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
    final mobile = AppLayoutScope.isMobile(context);
    final narrow = mobile || MediaQuery.sizeOf(context).width < 1000;
    final section = sections[selectedIndex];
    final firstName = session.role == 'TEACHER'
        ? session.fullName.trim()
        : session.role == 'ADMIN' &&
              session.fullName.trim() == 'System Administrator'
        ? 'Admin'
        : session.fullName.trim().split(' ').first;
    final visibleTabs = sections.length > 4 ? 3 : sections.length;
    final items = sections.map((s) => (s.title, s.icon)).toList();

    Widget sidebar({bool rail = false, bool primary = false}) =>
        WorkspaceSidebar(
          items: items,
          selected: selectedIndex,
          onSelect: selectSection,
          roleLabel: _roleLabel(session.role),
          collapsed: rail,
          primary: primary,
          groups: !mobile && session.role == 'ACCOUNTANT'
              ? const {0: 'Overview', 1: 'Collections', 4: 'Finance tools'}
              : const {},
        );

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: paper,
      drawer: narrow
          ? KeyboardScrollScope(
              child: Drawer(
                backgroundColor: ink,
                child: sidebar(primary: true),
              ),
            )
          : null,
      appBar: narrow
          ? AppBar(
              toolbarHeight: 64,
              title: !mobile && session.role == 'ADMIN'
                  ? const BrandMark(compact: true)
                  : Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              actions: [
                IconButton(
                  tooltip: 'Refresh page',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account menu',
                  onSelected: (_) => requestSignOut(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
                  ],
                  icon: const Icon(Icons.account_circle_outlined),
                ),
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
                for (var i = 0; i < visibleTabs; i++)
                  NavigationDestination(
                    icon: Icon(sections[i].icon),
                    selectedIcon: Icon(sections[i].icon, color: gold),
                    label: sections[i].title,
                  ),
                if (sections.length > visibleTabs)
                  const NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
              ],
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            if (!narrow)
              SizedBox(
                width: collapsed ? 84 : 250,
                child: sidebar(rail: collapsed),
              ),
            Expanded(
              child: Column(
                children: [
                  if (!narrow)
                    WorkspaceTopBar(
                      fullName: session.fullName,
                      roleLabel: session.role == 'TEACHER'
                          ? 'Teacher account'
                          : _roleLabel(session.role),
                      items: items,
                      onSelect: selectSection,
                      collapsed: collapsed,
                      onToggle: () => setState(() => collapsed = !collapsed),
                      onRefresh: refresh,
                      onSignOut: requestSignOut,
                    ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFAF9F6), Color(0xFFF4F6F8)],
                        ),
                      ),
                      child: Focus(
                        focusNode: contentFocus,
                        autofocus: true,
                        skipTraversal: true,
                        child: ListView(
                          primary: true,
                          key: PageStorageKey(
                            'workspace-${session.role}-$selectedIndex',
                          ),
                          padding: EdgeInsets.fromLTRB(
                            narrow ? 16 : 26,
                            narrow ? 24 : 28,
                            narrow ? 16 : 26,
                            24,
                          ),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1560,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (session.role == 'TEACHER' ||
                                                  session.role ==
                                                      'ACCOUNTANT') ...[
                                                Text(
                                                  session.role == 'ACCOUNTANT'
                                                      ? 'MY FINANCE WORKSPACE'
                                                      : 'MY TEACHING WORKSPACE',
                                                  style: const TextStyle(
                                                    color: gold,
                                                    letterSpacing: 1.6,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                              Text(
                                                selectedIndex == 0
                                                    ? session.role == 'PARENT'
                                                          ? 'Welcome back, $firstName!'
                                                          : 'Assalamu alaikum, $firstName'
                                                    : section.title,
                                                style: TextStyle(
                                                  fontFamily: 'NotoSansDisplay',
                                                  fontSize: narrow ? 26 : 30,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.2,
                                                  color: ink,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                section.purpose,
                                                style: const TextStyle(
                                                  color: muted,
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!narrow &&
                                            session.role == 'TEACHER' &&
                                            selectedIndex == 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 20,
                                              top: 12,
                                            ),
                                            child: FilledButton.icon(
                                              onPressed: () => openTeacher(4),
                                              icon: const Icon(
                                                Icons.calendar_month_outlined,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Take attendance',
                                              ),
                                            ),
                                          ),
                                        if (!narrow &&
                                            session.role != 'TEACHER' &&
                                            session.role != 'PARENT' &&
                                            MediaQuery.sizeOf(context).width >=
                                                1280)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 24,
                                              top: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_outlined,
                                                  color: gold,
                                                  size: 21,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  MaterialLocalizations.of(
                                                    context,
                                                  ).formatFullDate(
                                                    DateTime.now(),
                                                  ),
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    KeyedSubtree(
                                      key: ValueKey('page-$selectedIndex'),
                                      child: pageContent(session),
                                    ),
                                    if (!mobile) ...[
                                      const SizedBox(height: 28),
                                      const Divider(color: line),
                                      const SizedBox(height: 12),
                                      Text(
                                        '\u00a9 ${DateTime.now().year} Modern Islamic Foundation. All rights reserved.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'ADMIN' => 'Administration',
  'ACCOUNTANT' => 'Finance',
  'TEACHER' => 'Teacher workspace',
  'PARENT' => 'Parent',
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
