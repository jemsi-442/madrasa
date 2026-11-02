import 'dart:async';
import 'madrasa_location_fields.dart';
import 'madrasa_review_summary.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'browser_state.dart';
import 'foundation_ui.dart';
import 'platform_onboarding_progress.dart';
import 'school_password_dialog.dart';
import 'platform_workspace_shell.dart';
import 'workspace_chrome.dart';
import 'platform_madrasas_page.dart';
import 'platform_staff_page.dart';
import 'platform_curriculum_page.dart';
import 'curriculum_oversight_page.dart';
import 'platform_funds_page.dart';
import 'institutional_reports_page.dart';
import 'live_data.dart';
import 'it_workspace_visuals.dart';
import 'platform_system_health_page.dart';
import 'platform_access_page.dart';
import 'platform_sessions_page.dart';
import 'platform_audit_page.dart';
import 'security_incident_register.dart';
import 'platform_updates_page.dart';
import 'platform_sync_register.dart';
import 'platform_integrations_page.dart';
import 'platform_backup_requests.dart';
import 'workspace_form_dialog.dart';
import 'workspace_details_dialog.dart';

String platformTimestamp(dynamic value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  return parsed?.toUtc().toIso8601String() ?? 'Not recorded';
}

/// Access tokens stay in memory; browser restoration uses an HttpOnly cookie.
class PlatformApi {
  PlatformApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultApiBaseUrl();
  final http.Client _client;
  final String baseUrl;
  String? _token;
  Map<String, dynamic>? user;
  DateTime? expiresAt;
  int sessionVersion = 0;

  void acceptSession(AuthSession session) {
    if (session.scope != 'platform' ||
        !['SUPER_ADMIN', 'IT_SECURITY'].contains(session.role)) {
      throw const ApiException('Invalid account session.', 401);
    }
    clear();
    _token = session.accessToken;
    user = {
      'id': session.userId,
      'fullName': session.fullName,
      'role': session.role,
    };
    expiresAt = DateTime.now().add(Duration(seconds: session.expiresIn));
  }

  void clear() {
    sessionVersion++;
    _token = null;
    user = null;
    expiresAt = null;
  }

  void close() {
    clear();
    _client.close();
  }

  Future<dynamic> call(String path, {Map<String, dynamic>? body}) {
    final owner = sessionVersion;
    Future<dynamic> perform() {
      if (owner != sessionVersion) {
        throw const ApiException('Session changed.', 409);
      }
      return _call(path, body: body);
    }

    if (body != null && path.endsWith('/preview')) {
      return perform();
    }
    if (body != null) return dataWrite(perform);
    if (!liveDataPath(path)) return perform();
    return liveRead(perform);
  }

  Future<dynamic> Function(String, Map<String, dynamic>?) bindSession() {
    final owner = sessionVersion;
    return (path, body) async {
      if (owner != sessionVersion) {
        throw const ApiException('Session changed. Reopen this form.', 409);
      }
      return call(path, body: body);
    };
  }

  Future<dynamic> _call(String path, {Map<String, dynamic>? body}) async {
    final version = sessionVersion;
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (path != '/login') {
      if (_token == null ||
          expiresAt == null ||
          !expiresAt!.isAfter(DateTime.now())) {
        clear();
        throw const ApiException('Session expired. Sign in again.', 401);
      }
      headers['Authorization'] = 'Bearer $_token';
    }
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/platform$path',
    );
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 25));
    // An old response must never expose data or invalidate a newer login.
    if (version != sessionVersion) {
      throw const ApiException('Session changed. Refresh and try again.', 409);
    }
    if (path != '/login' &&
        (expiresAt == null || !expiresAt!.isAfter(DateTime.now()))) {
      clear();
      throw const ApiException('Session expired. Sign in again.', 401);
    }
    if (response.statusCode == 401 && path != '/login') clear();
    if (response.statusCode >= 400) {
      final message = switch (response.statusCode) {
        401 =>
          path == '/login'
              ? 'Check your password and authenticator code.'
              : 'Session expired. Sign in again.',
        403 => 'This action is not permitted for your platform account.',
        409 =>
          'This record has changed or already exists. Refresh and try again.',
        422 => 'Check the information entered and try again.',
        429 => 'Too many attempts. Please wait 15 minutes before trying again.',
        503 =>
          'Platform access is not available yet. Contact the deployment administrator.',
        _ => 'The request could not be completed. Please try again.',
      };
      throw ApiException(message, response.statusCode);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['data'];
  }

  Future<void> login(String email, String password, String code) async {
    clear();
    final version = sessionVersion;
    final data = await call(
      '/login',
      body: {'email': email.trim(), 'password': password, 'code': code},
    );
    if (version != sessionVersion) {
      throw const ApiException('Session changed. Sign in again.', 409);
    }
    final profile = Map<String, dynamic>.from(data['user'] as Map);
    if (!['SUPER_ADMIN', 'IT_SECURITY'].contains(profile['role'])) {
      throw const ApiException('Not a platform account.', 403);
    }
    _token = data['accessToken'] as String;
    user = profile;
    expiresAt = DateTime.now().add(
      Duration(seconds: (data['expiresIn'] as num).toInt()),
    );
  }
}

class _AccountHistoryDialog extends StatefulWidget {
  const _AccountHistoryDialog({
    required this.api,
    required this.accountId,
    required this.fullName,
  });
  final PlatformApi api;
  final String accountId;
  final String fullName;
  @override
  State<_AccountHistoryDialog> createState() => _AccountHistoryDialogState();
}

class _AccountHistoryDialogState extends State<_AccountHistoryDialog> {
  int page = 1;
  bool loading = false;
  String? error;
  List<dynamic> events = [];
  Timer? expiry;
  final scroll = ScrollController();
  bool closing = false;

  void close() {
    if (!mounted || closing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      closing = true;
      events = [];
    });
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    final remaining =
        widget.api.expiresAt?.difference(DateTime.now()) ?? Duration.zero;
    expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      close();
    });
    load(1);
  }

  Future<void> load(int target) async {
    setState(() {
      page = target;
      loading = true;
      error = null;
      events = [];
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    try {
      final data = await widget.api.call(
        '/accounts/${Uri.encodeComponent(widget.accountId)}/access-history?page=$target&pageSize=20',
      );
      if (!mounted || closing) return;
      if (widget.api.user == null) {
        close();
        return;
      }
      setState(() {
        events = data as List;
        loading = false;
      });
    } catch (_) {
      if (!mounted || closing) return;
      if (widget.api.user == null) {
        close();
        return;
      }
      setState(() {
        loading = false;
        error = 'History could not be loaded. Retry or close this window.';
      });
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkspaceFormDialog(
    icon: Icons.manage_history_rounded,
    eyebrow: 'ACCOUNT / ACCESS HISTORY',
    title: const Text('Access history'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        controller: scroll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Page $page. Times are UTC.'),
            const SizedBox(height: 12),
            const WorkspaceFormNotice(
              message:
                  'Newest first. New activity may shift records between pages.',
            ),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton(
                onPressed: () => load(page),
                child: const Text('Retry'),
              ),
            ],
            if (!loading && error == null && events.isEmpty)
              Text(
                page == 1
                    ? 'No suspension or restoration recorded.'
                    : 'No older changes on this page.',
              ),
            for (final event in events) ...[
              Text(
                event['action'] == 'platform.account.disabled'
                    ? 'Access disabled'
                    : 'Access restored',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ItRecordDetails(
                values: {
                  'Changed by': event['actorId'],
                  'Recorded (UTC)': event['createdAt'],
                },
              ),
              const SizedBox(height: 14),
              ItRecordDetails(
                values: {'Reason': event['reason'] ?? 'No reason recorded.'},
              ),
              const Divider(height: 24),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading || page <= 1 ? null : () => load(page - 1),
        child: const Text('Newer'),
      ),
      TextButton(
        onPressed:
            loading || error != null || events.length < 20 || page >= 10000
            ? null
            : () => load(page + 1),
        child: const Text('Older'),
      ),
      TextButton(onPressed: close, child: const Text('Close')),
    ],
  );
}

class PlatformConsole extends StatefulWidget {
  const PlatformConsole({
    super.key,
    this.api,
    this.onSignedOut,
    this.browserState = const BrowserState(),
  });
  final PlatformApi? api;
  final VoidCallback? onSignedOut;
  final BrowserState browserState;
  @override
  State<PlatformConsole> createState() => _PlatformConsoleState();
}

class _PlatformConsoleState extends State<PlatformConsole> {
  late final api = widget.api ?? PlatformApi();
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  Timer? expiry;
  bool busy = false;
  String? error;
  String? confirmation;
  bool audit = false;
  String auditAction = '';
  String? auditApplicationId;
  String? auditActorId;
  String? auditTechnicalReviewId;
  String auditRole = '';
  String auditPeriod = '';
  DateTime? auditSince;
  bool healthView = false;
  bool incidentsView = false;
  String? incidentToOpen;
  String? incidentInitialStatus, incidentInitialPriority;
  String? incidentDraft;
  bool updatesView = false;
  bool backupsView = false;
  bool offlineSyncView = false;
  bool integrationsView = false;
  bool sessionsView = false;
  String sessionSource = 'platform';
  String sessionSearch = '';
  String sessionFilter = 'all';
  bool accountsView = false;
  bool homeView = false;
  bool madrasasView = false;
  bool staffView = false;
  bool curriculumView = false;
  bool oversightView = false;
  bool fundsView = false;
  bool reportsView = false;
  String applicationStatus = '';
  String applicationScope = '';
  Map<String, dynamic>? overview;
  String accountRole = '';
  String accountStatus = '';
  Map<String, dynamic>? health;
  int page = 1;
  List<Map<String, dynamic>> records = [];
  bool get isAdmin => api.user?['role'] == 'SUPER_ADMIN';
  final Set<Route<dynamic>> sessionDialogs = {};

  @override
  void initState() {
    super.initState();
    scheduleExpiry();
    if (widget.onSignedOut != null && api.user != null) {
      audit = !isAdmin;
      homeView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || api.user == null) return;
        final saved = widget.browserState.read(navigationKey);
        final destination = PlatformPage.values
            .where((page) => page.name == saved)
            .firstOrNull;
        navigateTo(
          destination != null && allowedDestination(destination)
              ? destination
              : PlatformPage.home,
        );
      });
    }
  }

  void closeSessionDialogs() {
    for (final route in sessionDialogs.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  void scheduleExpiry() {
    expiry?.cancel();
    final deadline = api.expiresAt;
    if (deadline == null) return;
    final version = api.sessionVersion;
    final remaining = deadline.difference(DateTime.now());
    expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!mounted || api.sessionVersion != version) return;
      api.clear();
      closeSessionDialogs();
      setState(() {
        records = [];
        overview = null;
        health = null;
        confirmation = null;
        error = 'Session expired. Sign in again.';
      });
    });
  }

  Future<T?> sessionDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final version = api.sessionVersion;
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
    sessionDialogs.add(route);
    try {
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      return api.user != null && api.sessionVersion == version ? result : null;
    } finally {
      sessionDialogs.remove(route);
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    email.dispose();
    password.dispose();
    code.dispose();
    if (widget.api == null) api.close();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      confirmation = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is ApiException
              ? e.message
              : 'Unable to connect. Check your connection and try again.';
          if (api.user == null) {
            records = [];
            closeSessionDialogs();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> load() async {
    if (!mounted) return;
    if (incidentsView ||
        updatesView ||
        backupsView ||
        offlineSyncView ||
        integrationsView) {
      return;
    }
    if (madrasasView ||
        staffView ||
        curriculumView ||
        oversightView ||
        fundsView ||
        reportsView) {
      return;
    }
    // Never present a previous access/audit snapshot as a successful refresh.
    setState(() => records = []);
    if (homeView) {
      final version = api.sessionVersion;
      final office = isAdmin;
      overview = null;
      health = null;
      final result = Map<String, dynamic>.from(
        await api.call(office ? '/overview' : '/health') as Map,
      );
      if (!office &&
          mounted &&
          api.user != null &&
          api.sessionVersion == version) {
        try {
          final incidentData = Map<String, dynamic>.from(
            await api.call('/incidents?page=1') as Map,
          );
          result['incidents'] = {
            'recentOpen': (incidentData['attention'] as List? ?? [])
                .whereType<Map>()
                .take(3)
                .map(
                  (row) => {
                    'id': row['id'],
                    'title': row['title'],
                    'priority': row['priority'],
                  },
                )
                .toList(),
            'open': incidentData['open'],
            'high': incidentData['high'],
            'resolved': incidentData['resolved'],
            'checkedAt': DateTime.now().toUtc().toIso8601String(),
          };
        } catch (_) {
          // Keep connectivity results usable when the incident register is unavailable.
          result['incidentsUnavailable'] = true;
        }
      }
      if (!mounted || api.user == null || api.sessionVersion != version) return;
      if (mounted && api.user != null && api.sessionVersion == version) {
        setState(() {
          if (isAdmin) {
            overview = Map<String, dynamic>.from(result as Map);
          } else {
            health = Map<String, dynamic>.from(result as Map);
          }
        });
      }
      return;
    }
    if (healthView) {
      health = null;
      final data = await api.call('/health');
      if (mounted && api.user != null) {
        setState(() {
          health = Map<String, dynamic>.from(data as Map);
        });
      }
      return;
    }
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'pageSize': '20',
        if (sessionsView && !isAdmin) 'source': sessionSource,
        if (sessionsView && !isAdmin) 'filter': sessionFilter,
        if (sessionsView && !isAdmin && sessionSearch.isNotEmpty)
          'q': sessionSearch,
        if (!accountsView &&
            !sessionsView &&
            !audit &&
            applicationStatus.isNotEmpty)
          'status': applicationStatus,
        if (!accountsView &&
            !sessionsView &&
            !audit &&
            applicationScope.isNotEmpty)
          'scope': applicationScope,
        if (accountsView && accountRole.isNotEmpty) 'role': accountRole,
        if (accountsView && accountStatus.isNotEmpty) 'status': accountStatus,
        if (audit && !sessionsView && !accountsView && auditAction.isNotEmpty)
          'action': auditAction,
        if (audit &&
            !sessionsView &&
            !accountsView &&
            auditApplicationId != null)
          'applicationId': auditApplicationId!,
        if (audit && !sessionsView && !accountsView && auditActorId != null)
          'actorId': auditActorId!,
        if (audit &&
            !sessionsView &&
            !accountsView &&
            auditTechnicalReviewId != null)
          'technicalReviewId': auditTechnicalReviewId!,
        if (audit && !sessionsView && !accountsView && auditRole.isNotEmpty)
          'actorRole': auditRole,
        if (audit && !sessionsView && !accountsView && auditSince != null)
          'from': auditSince!.toUtc().toIso8601String(),
      },
    ).query;
    final data = await api.call(
      '${accountsView
          ? '/accounts'
          : sessionsView
          ? (isAdmin ? '/sessions' : '/security-sessions')
          : audit
          ? '/audit-events'
          : '/tenant-applications'}?$query',
    );
    if (mounted && api.user != null) {
      setState(() {
        records = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    }
  }

  Future<void> signIn() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      try {
        await api.login(email.text, password.text, code.text);
      } finally {
        if (mounted) {
          password.clear();
          code.clear();
        }
      }
      if (!mounted) {
        api.clear();
        return;
      }
      audit = false;
      auditApplicationId = null;
      auditActorId = null;
      auditTechnicalReviewId = null;
      homeView = true;
      madrasasView = false;
      staffView = false;
      curriculumView = false;
      oversightView = false;
      fundsView = false;
      reportsView = false;
      healthView = false;
      incidentsView = false;
      updatesView = false;
      backupsView = false;
      offlineSyncView = false;
      integrationsView = false;
      sessionsView = false;
      accountsView = false;
      applicationStatus = '';
      applicationScope = '';
      overview = null;
      accountRole = '';
      accountStatus = '';
      health = null;
      page = 1;
      scheduleExpiry();
      await load();
    });
  }

  Future<void> openApplicationAudit(
    String? id, {
    String? actorId,
    String? technicalReviewId,
  }) => run(() async {
    if (isAdmin) return;
    audit = true;
    healthView = false;
    incidentsView = false;
    updatesView = false;
    backupsView = false;
    offlineSyncView = false;
    integrationsView = false;
    sessionsView = false;
    accountsView = false;
    overview = null;
    auditApplicationId = id;
    auditActorId = actorId;
    auditTechnicalReviewId = technicalReviewId;
    auditAction = '';
    auditRole = '';
    auditPeriod = '';
    auditSince = null;
    page = 1;
    records = [];
    await load();
  });

  Future<void> showOnboardingProgress(Map<String, dynamic> record) async {
    if (busy) return;
    Map<String, dynamic> visibleProgress(dynamic raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      if (isAdmin) data.remove('activationReview');
      return data;
    }

    final version = api.sessionVersion;
    Map<String, dynamic>? result;
    await run(() async {
      result = visibleProgress(
        await api.call(
              '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/onboarding-progress',
            )
            as Map,
      );
    });
    final data = result;
    if (!mounted ||
        api.user == null ||
        api.sessionVersion != version ||
        data == null) {
      return;
    }
    final viewHistory = await sessionDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: const Text('Onboarding progress'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: RefreshableOnboardingProgress(
              initialData: data,
              sendInvitation: () async {
                final result =
                    await api.call(
                          '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/send-invitation',
                          body: {},
                        )
                        as Map;
                return result['status'] as String;
              },
              sessionIsCurrent: () =>
                  api.user != null && api.sessionVersion == version,
              load: () async => visibleProgress(
                await api.call(
                      '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/onboarding-progress',
                    )
                    as Map,
              ),
            ),
          ),
        ),
        actions: [
          if (!isAdmin)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('View application history'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (viewHistory == true &&
        mounted &&
        api.user != null &&
        api.sessionVersion == version) {
      await openApplicationAudit(record['id'] as String);
    }
  }

  Future<void> requestLogout(bool all) async {
    if (busy || api.user == null) return;
    final version = api.sessionVersion;
    if (all) {
      final confirmed = await sessionDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out everywhere?'),
          content: const Text(
            'This ends all platform sessions for your company account, including this one. '
            'Other company accounts and school accounts are not affected. '
            'You will need your password and authenticator code to sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm sign out everywhere'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted || api.user == null || api.sessionVersion != version) return;
    await logout(all);
  }

  Future<void> logout(bool all) => run(() async {
    final version = api.sessionVersion;
    try {
      await api.call(all ? '/logout-all' : '/logout', body: {});
    } catch (_) {
      if (api.sessionVersion != version && api.user != null) rethrow;
      throw ApiException(
        all
            ? 'Signed out on this device. We could not confirm sign-out on all sessions. Contact your company IT team if you need help confirming access.'
            : 'Signed out on this device. Server sign-out could not be confirmed. Contact your company IT team if you need help confirming access.',
        503,
      );
    } finally {
      // A failed revocation must not leave credentials on a shared device.
      if (api.sessionVersion == version || api.user == null) {
        api.clear();
        expiry?.cancel();
        closeSessionDialogs();
        records = [];
        overview = null;
        health = null;
        confirmation = null;
      }
    }
  });

  Future<bool?> applicationDialog({
    Map<String, dynamic>? record,
    String? decision,
  }) async {
    var saved = false;
    final version = api.sessionVersion;
    final name = TextEditingController();
    final adminEmail = TextEditingController();
    final reason = TextEditingController();
    final location = <String, String>{};
    final key = GlobalKey<FormState>();
    final body = await sessionDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: Text(
          record == null
              ? 'Add Madrasa'
              : decision == 'APPROVED'
              ? 'Approve madrasa'
              : 'Decline madrasa',
        ),
        content: SizedBox(
          width: record == null ? 700 : 680,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (record == null) ...[
                    TextFormField(
                      controller: name,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Madrassa name',
                      ),
                      validator: (v) =>
                          (v?.trim().length ?? 0) < 2 ? 'Enter a name.' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Afaq code is assigned automatically when saved (for example AFQ-000001).',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: adminEmail,
                      maxLength: 150,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'School admin email',
                      ),
                      validator: (v) =>
                          !(v ?? '').contains('@') ? 'Enter an email.' : null,
                    ),
                    MadrasaLocationFields(
                      values: location,
                      loadSuggestions: (path) => api.call(path),
                    ),
                  ] else ...[
                    MadrasaReviewSummary(
                      record: record,
                      approving: decision == 'APPROVED',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reason,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Decision reason',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 10
                          ? 'Give a reason of at least 10 characters.'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!key.currentState!.validate()) return;
              Navigator.pop(
                context,
                record == null
                    ? {
                        'schoolName': name.text.trim(),
                        'adminEmail': adminEmail.text.trim(),
                        'location': {
                          for (final entry in location.entries)
                            if (entry.value.isNotEmpty) entry.key: entry.value,
                        },
                      }
                    : {'decision': decision, 'reason': reason.text.trim()},
              );
            },
            child: Text(
              record == null
                  ? 'Save for approval'
                  : decision == 'APPROVED'
                  ? 'Confirm approval'
                  : 'Confirm decline',
            ),
          ),
        ],
      ),
    );
    // The closing dialog may still animate with these controllers attached.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    adminEmail.dispose();
    reason.dispose();
    if (body != null &&
        mounted &&
        api.user != null &&
        api.sessionVersion == version) {
      await run(() async {
        records = [];
        overview = null;
        try {
          await api.call(
            record == null
                ? '/tenant-applications'
                : '/tenant-applications/${record['id']}/review',
            body: body,
          );
          saved = true;
        } catch (e) {
          if (e is ApiException && e.statusCode < 500) rethrow;
          throw const ApiException(
            'We could not confirm whether the request was saved. Refresh the application list before trying again.',
            503,
          );
        }
        if (!mounted || api.user == null) return;
        confirmation = record == null
            ? 'Application submitted. Another Super Admin must review it.'
            : decision == 'APPROVED'
            ? 'Approval saved. This does not activate the madrassa.'
            : 'Rejection saved. The application is now closed.';
        try {
          await load();
        } catch (e) {
          if (api.user == null) rethrow;
          throw const ApiException(
            'The change was saved, but the list could not be refreshed. Use Refresh; do not submit the decision again.',
            503,
          );
        }
      });
    }
    return body == null ? null : saved;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onSignedOut != null && api.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && api.user == null) widget.onSignedOut!();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _buildConsole(context);
  }

  PlatformPage get currentPage => homeView
      ? PlatformPage.home
      : madrasasView
      ? PlatformPage.madrasas
      : staffView
      ? PlatformPage.staff
      : curriculumView
      ? PlatformPage.curriculum
      : oversightView
      ? PlatformPage.oversight
      : fundsView
      ? PlatformPage.funds
      : reportsView
      ? PlatformPage.reports
      : healthView
      ? PlatformPage.health
      : incidentsView
      ? PlatformPage.incidents
      : updatesView
      ? PlatformPage.updates
      : backupsView
      ? PlatformPage.backups
      : offlineSyncView
      ? PlatformPage.offlineSync
      : integrationsView
      ? PlatformPage.integrations
      : sessionsView
      ? PlatformPage.sessions
      : accountsView
      ? PlatformPage.accounts
      : audit
      ? PlatformPage.history
      : PlatformPage.applications;

  String get navigationKey =>
      'afaq.platform.page.${api.user?['id']}.${api.user?['role']}';

  bool allowedDestination(PlatformPage destination) => isAdmin
      ? {
          PlatformPage.home,
          PlatformPage.madrasas,
          PlatformPage.staff,
          PlatformPage.curriculum,
          PlatformPage.oversight,
          PlatformPage.funds,
          PlatformPage.reports,
        }.contains(destination)
      : api.user?['role'] == 'IT_SECURITY' &&
            {
              PlatformPage.accounts,
              PlatformPage.home,
              PlatformPage.health,
              PlatformPage.incidents,
              PlatformPage.updates,
              PlatformPage.backups,
              PlatformPage.offlineSync,
              PlatformPage.integrations,
              PlatformPage.sessions,
              PlatformPage.history,
            }.contains(destination);

  void navigateTo(PlatformPage destination) {
    if (busy || api.user == null) return;
    if (destination == PlatformPage.applications && isAdmin) {
      destination = PlatformPage.madrasas;
    }
    if (!allowedDestination(destination)) return;
    if (widget.onSignedOut != null) {
      widget.browserState.write(navigationKey, destination.name);
    }
    run(() async {
      if (destination == PlatformPage.history && !audit) {
        auditApplicationId = null;
        auditActorId = null;
        auditTechnicalReviewId = null;
        auditAction = '';
        auditRole = '';
        auditPeriod = '';
        auditSince = null;
      }
      homeView = destination == PlatformPage.home;
      madrasasView = destination == PlatformPage.madrasas;
      staffView = destination == PlatformPage.staff;
      curriculumView = destination == PlatformPage.curriculum;
      oversightView = destination == PlatformPage.oversight;
      fundsView = destination == PlatformPage.funds;
      reportsView = destination == PlatformPage.reports;
      healthView = destination == PlatformPage.health;
      incidentsView = destination == PlatformPage.incidents;
      if (!incidentsView) incidentToOpen = null;
      if (!incidentsView) {
        incidentInitialStatus = null;
        incidentInitialPriority = null;
      }
      if (!incidentsView) incidentDraft = null;
      updatesView = destination == PlatformPage.updates;
      backupsView = destination == PlatformPage.backups;
      offlineSyncView = destination == PlatformPage.offlineSync;
      integrationsView = destination == PlatformPage.integrations;
      sessionsView = destination == PlatformPage.sessions;
      accountsView = destination == PlatformPage.accounts;
      audit = destination == PlatformPage.history;
      overview = null;
      health = null;
      records = [];
      page = 1;
      if (!madrasasView &&
          !staffView &&
          !curriculumView &&
          !oversightView &&
          !fundsView &&
          !reportsView) {
        await load();
      }
    });
  }

  Widget _buildConsole(BuildContext context) {
    final legacy = Scaffold(
      appBar: AppBar(
        title: const Text('Afaq / Platform governance'),
        actions: [
          if (api.user != null)
            IconButton(
              tooltip: 'Change password',
              onPressed: busy
                  ? null
                  : () async {
                      final changed = await showSchoolPasswordDialog(
                        context,
                        (_, body) => api.call('/change-password', body: body),
                      );
                      if (changed) {
                        api.clear();
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
              icon: const Icon(Icons.lock_reset),
            ),
          if (api.user != null)
            PopupMenuButton<bool>(
              enabled: !busy,
              tooltip: 'Sign out options',
              onSelected: requestLogout,
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Sign out')),
                PopupMenuItem(
                  value: true,
                  child: Text('Sign out all sessions'),
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: api.user == null ? 1100 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (api.user == null)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff08283e), Color(0xff164d59)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AFAQ  /  TRUST & OVERSIGHT',
                            style: TextStyle(
                              color: Color(0xffe5c480),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            api.user == null
                                ? 'One platform.\nClear responsibilities.'
                                : 'Welcome, ${api.user!['fullName']}',
                            style: const TextStyle(
                              fontFamily: 'NotoSerifDisplay',
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            api.user == null
                                ? 'Restricted access for company Super Admin and IT/Security. School accounts use the school login.'
                                : '${isAdmin ? 'Super Admin' : 'IT / Security'} workspace. School academic and financial records remain separate.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xffa32e2e)),
                        ),
                      ),
                    ),
                  if (confirmation != null && api.user != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          confirmation!,
                          style: const TextStyle(color: Color(0xff247954)),
                        ),
                      ),
                    ),
                  if (busy) const LinearProgressIndicator(),
                  if (api.user == null)
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 480,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: form,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Platform sign in',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: email,
                                    enabled: !busy,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Company email',
                                    ),
                                    validator: (v) => (v ?? '').contains('@')
                                        ? null
                                        : 'Enter your email.',
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: password,
                                    enabled: !busy,
                                    obscureText: true,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    ),
                                    validator: (v) => (v ?? '').isEmpty
                                        ? 'Enter your password.'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: code,
                                    enabled: !busy,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Authenticator code',
                                    ),
                                    onFieldSubmitted: (_) => signIn(),
                                    validator: (v) => (v?.length ?? 0) == 6
                                        ? null
                                        : 'Enter the six-digit code.',
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: busy ? null : signIn,
                                    child: const Text('Verify and sign in'),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Sessions last 15 minutes. Browser reload restores an unexpired session. Access is provisioned by an authorized operator; there is no public signup.',
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.of(
                                            context,
                                          ).pushNamed('/login'),
                                    child: const Text('Go to school login'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    PlatformTaskIntro(page: currentPage, isAdmin: isAdmin),
                    const SizedBox(height: 20),
                    if (isAdmin) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => navigateTo(PlatformPage.home),
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const Text('Governance overview'),
                        ),
                      ),
                      if (overview != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Platform snapshot',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Checked (UTC): ${overview!['checkedAt']}',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    overviewMetric(
                                      'Awaiting your independent review',
                                      overview!['awaitingYourReview'],
                                    ),
                                    overviewMetric(
                                      'Requested applications',
                                      overview!['applications']['REQUESTED'],
                                    ),
                                    overviewMetric(
                                      'Approved applications',
                                      overview!['applications']['APPROVED'],
                                    ),
                                    overviewMetric(
                                      'Rejected applications',
                                      overview!['applications']['REJECTED'],
                                    ),
                                    if (overview!['onboarding'] is Map) ...[
                                      overviewMetric(
                                        'Approved, awaiting setup',
                                        overview!['onboarding']['awaitingSetup'],
                                      ),
                                      overviewMetric(
                                        'Created, awaiting activation',
                                        overview!['onboarding']['pendingActivation'],
                                      ),
                                    ],
                                    overviewMetric(
                                      'Active IT accounts',
                                      overview!['accounts']['IT_SECURITY']['ACTIVE'],
                                    ),
                                    overviewMetric(
                                      'Disabled IT accounts',
                                      overview!['accounts']['IT_SECURITY']['DISABLED'],
                                    ),
                                    overviewMetric(
                                      'Active Super Admins',
                                      overview!['accounts']['SUPER_ADMIN']['ACTIVE'],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Approval is not activation. Awaiting activation counts linked schools marked pending, not verified readiness. Review each application before taking action. Email delivery and activation controls remain unavailable here. Counts are a snapshot; refresh before making decisions.',
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    overview = null;
                                  }),
                                  child: const Text('Hide overview'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => run(() async {
                                          audit = false;
                                          healthView = false;
                                          sessionsView = false;
                                          accountsView = false;
                                          applicationStatus = 'APPROVED';
                                          applicationScope = '';
                                          page = 1;
                                          records = [];
                                          overview = null;
                                          await load();
                                        }),
                                  icon: const Icon(Icons.checklist_outlined),
                                  label: const Text('View approved onboarding'),
                                ),
                                FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => run(() async {
                                          audit = false;
                                          healthView = false;
                                          sessionsView = false;
                                          accountsView = false;
                                          applicationStatus = 'REQUESTED';
                                          applicationScope = 'reviewable';
                                          page = 1;
                                          records = [];
                                          overview = null;
                                          await load();
                                        }),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text(
                                    'Review pending applications',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        WorkspaceRefreshButton(
                          onRefresh: () => run(load),
                          loading: busy,
                          label: 'Refresh',
                        ),
                        if (isAdmin &&
                            !audit &&
                            !healthView &&
                            !sessionsView &&
                            !accountsView)
                          FilledButton.icon(
                            onPressed: busy ? null : () => applicationDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Request madrassa'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (healthView)
                      PlatformHealthPanel(snapshot: health, loading: busy)
                    else ...[
                      Text(
                        accountsView
                            ? 'Read-only company directory. School users are managed separately.'
                            : sessionsView
                            ? 'Session access metadata. Times are UTC.'
                            : audit
                            ? 'Platform activity'
                            : 'Request > Independent review > Madrasa registration > Admin invitation',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 12),
                      if (!accountsView && !sessionsView && !audit) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            auditFilter(
                              'Application status',
                              applicationStatus,
                              const {
                                '': 'All decisions',
                                'REQUESTED': 'Requested',
                                'APPROVED': 'Approved',
                                'REJECTED': 'Rejected',
                              },
                              (value) {
                                applicationStatus = value;
                                if (applicationScope == 'reviewable' &&
                                    value != 'REQUESTED') {
                                  applicationScope = '';
                                }
                              },
                            ),
                            auditFilter(
                              'Application scope',
                              applicationScope,
                              const {
                                '': 'All applications',
                                'mine': 'My requests',
                                'reviewable': 'Awaiting my review',
                              },
                              (value) {
                                applicationScope = value;
                                if (value == 'reviewable') {
                                  applicationStatus = 'REQUESTED';
                                }
                              },
                            ),
                            TextButton(
                              onPressed:
                                  busy ||
                                      (applicationStatus.isEmpty &&
                                          applicationScope.isEmpty)
                                  ? null
                                  : () => run(() async {
                                      applicationStatus = '';
                                      applicationScope = '';
                                      page = 1;
                                      records = [];
                                      await load();
                                    }),
                              child: const Text('Clear application filters'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (accountsView) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            auditFilter(
                              'Account role',
                              accountRole,
                              const {
                                '': 'All company roles',
                                'SUPER_ADMIN': 'Super Admin',
                                'IT_SECURITY': 'IT Security',
                              },
                              (value) {
                                accountRole = value;
                              },
                            ),
                            auditFilter(
                              'Account status',
                              accountStatus,
                              const {
                                '': 'All statuses',
                                'ACTIVE': 'Active',
                                'DISABLED': 'Disabled',
                              },
                              (value) {
                                accountStatus = value;
                              },
                            ),
                            TextButton(
                              onPressed:
                                  busy ||
                                      (accountRole.isEmpty &&
                                          accountStatus.isEmpty)
                                  ? null
                                  : () => run(() async {
                                      accountRole = '';
                                      accountStatus = '';
                                      page = 1;
                                      records = [];
                                      await load();
                                    }),
                              child: const Text('Clear account filters'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (audit && !sessionsView && !accountsView) ...[
                        if (auditTechnicalReviewId != null ||
                            auditApplicationId != null ||
                            auditActorId != null) ...[
                          Text(
                            auditTechnicalReviewId != null
                                ? 'Sign-off history: $auditTechnicalReviewId'
                                : auditActorId != null
                                ? 'Activity by account: $auditActorId'
                                : 'Application history: $auditApplicationId',
                          ),
                          if (auditActorId != null)
                            const Text(
                              'Filtered by the recorded actor ID, not the affected entity. For failed logins, this ID identifies the target account, not a verified person.',
                            ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => openApplicationAudit(null),
                            child: const Text(
                              'Show all application and platform events',
                            ),
                          ),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            auditFilter(
                              'Event',
                              auditAction,
                              {
                                '': 'All events',
                                if (!isAdmin)
                                  'tenant.technical-review.recorded':
                                      'IT sign-off recorded',
                                if (!isAdmin)
                                  'tenant.technical-review.withdrawn':
                                      'IT sign-off withdrawn',
                                if (!isAdmin)
                                  'platform.login.failed': 'Failed login',
                                if (!isAdmin)
                                  'platform.login.succeeded':
                                      'Successful login',
                                'tenant.application.requested':
                                    'Madrassa requested',
                                'tenant.application.approved':
                                    'Madrassa approved',
                                'tenant.application.rejected':
                                    'Madrassa rejected',
                                if (!isAdmin)
                                  'tenant.school.provisioned':
                                      'Inactive madrassa created',
                                if (!isAdmin)
                                  'tenant.admin.invitation.issued':
                                      'Admin invitation recorded',
                                'tenant.school.activated': 'Madrassa activated',
                                if (!isAdmin)
                                  'platform.session.revoked': 'Session revoked',
                                if (!isAdmin)
                                  'platform.sessions.revoked':
                                      'All sessions revoked',
                                if (!isAdmin)
                                  'platform.account.bootstrapped':
                                      'Reviewer created',
                                'platform.account.disabled':
                                    'IT account disabled',
                                'platform.account.restored':
                                    'IT account restored',
                              },
                              (value) {
                                auditAction = value;
                              },
                            ),
                            if (!isAdmin)
                              auditFilter(
                                'Role',
                                auditRole,
                                const {
                                  '': 'All roles',
                                  'SUPER_ADMIN': 'Super Admin',
                                  'IT_SECURITY': 'IT / Security',
                                },
                                (value) {
                                  auditRole = value;
                                },
                              ),
                            auditFilter(
                              'Period',
                              auditPeriod,
                              const {
                                '': 'All time',
                                '1': 'Last 24 hours',
                                '7': 'Last 7 days',
                                '30': 'Last 30 days',
                              },
                              (value) {
                                auditPeriod = value;
                                auditSince = value.isEmpty
                                    ? null
                                    : DateTime.now().toUtc().subtract(
                                        Duration(days: int.parse(value)),
                                      );
                              },
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            isAdmin
                                ? 'Office decisions and account administration. Times are UTC. Technical and security logs are managed by IT.'
                                : 'Times are UTC. Failed login events identify the account targeted, not a verified person. Filters do not grant school-data access.',
                          ),
                        ),
                      ],
                      if (records.isEmpty && !busy && error == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text('No records to display.'),
                          ),
                        ),
                      for (final record in records)
                        if (accountsView)
                          accountCard(record)
                        else if (sessionsView)
                          sessionCard(record)
                        else
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!audit)
                                    PlatformApplicationHeading(record: record)
                                  else ...[
                                    Text(
                                      '${record[audit ? 'action' : 'schoolName']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ItRecordDetails(
                                      values: {
                                        'Actor role': record['actorRole'],
                                        'Record type': record['entityType'],
                                        'Recorded (UTC)': record['createdAt'],
                                      },
                                    ),
                                  ],
                                  if (audit)
                                    ExpansionTile(
                                      key: ValueKey(record['id']),
                                      title: const Text('Event details'),
                                      tilePadding: EdgeInsets.zero,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: ItRecordDetails(
                                            values: {
                                              'Event ID': record['id'],
                                              'Account ID': record['actorId'],
                                              'Entity ID': record['entityId'],
                                              if (record['metadata'] is Map)
                                                for (final entry
                                                    in (record['metadata']
                                                            as Map)
                                                        .entries)
                                                  'Detail: ${entry.key}':
                                                      entry.value is Map ||
                                                          entry.value is List
                                                      ? jsonEncode(entry.value)
                                                      : entry.value,
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!audit &&
                                      record['decisionReason'] != null)
                                    Text(
                                      'Decision: ${record['decisionReason']}',
                                    ),
                                  if (audit &&
                                      !isAdmin &&
                                      ((record['action'] ==
                                                  'tenant.technical-review.recorded' &&
                                              record['entityType'] ==
                                                  'TenantApplication' &&
                                              record['id'] is String) ||
                                          (record['action'] ==
                                                  'tenant.technical-review.withdrawn' &&
                                              record['entityType'] ==
                                                  'TechnicalReview' &&
                                              record['entityId'] is String)))
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => openApplicationAudit(
                                              null,
                                              technicalReviewId:
                                                  record[record['entityType'] ==
                                                              'TechnicalReview'
                                                          ? 'entityId'
                                                          : 'id']
                                                      as String,
                                            ),
                                      child: const Text(
                                        'View sign-off history',
                                      ),
                                    ),
                                  if (audit &&
                                      !isAdmin &&
                                      record['actorId'] is String &&
                                      (record['actorId'] as String).isNotEmpty)
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => openApplicationAudit(
                                              null,
                                              actorId:
                                                  record['actorId'] as String,
                                            ),
                                      child: const Text('View actor activity'),
                                    ),
                                  if (audit &&
                                      record['entityType'] ==
                                          'TenantApplication' &&
                                      record['entityId'] is String)
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => openApplicationAudit(
                                              record['entityId'] as String,
                                            ),
                                      child: const Text(
                                        'View application history',
                                      ),
                                    ),
                                  if (!audit) ...[
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => openApplicationAudit(
                                              record['id'] as String,
                                            ),
                                      child: const Text(
                                        'View application history',
                                      ),
                                    ),
                                    if (record['status'] == 'APPROVED')
                                      TextButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => showOnboardingProgress(
                                                record,
                                              ),
                                        icon: const Icon(
                                          Icons.checklist_outlined,
                                        ),
                                        label: const Text(
                                          'Onboarding progress',
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(switch (record['status']) {
                                      'APPROVED' =>
                                        'Approved for future provisioning. No madrassa or school account has been created by this approval.',
                                      'REJECTED' =>
                                        'Request closed. No activation will follow from this decision.',
                                      _ =>
                                        'Pending independent review. No school access has been issued.',
                                    }),
                                    ExpansionTile(
                                      key: ValueKey(
                                        'application-details-${record['id']}',
                                      ),
                                      title: const Text('Application details'),
                                      tilePadding: EdgeInsets.zero,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: SelectableText(
                                            'Application ID: ${record['id']}\nRequested by account: ${record['requestedById'] ?? 'Not recorded'}\nRequested (UTC): ${platformTimestamp(record['createdAt'])}\nReviewed by account: ${record['reviewedById'] ?? 'Not yet reviewed'}\nReviewed (UTC): ${platformTimestamp(record['reviewedAt'])}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (!audit &&
                                      record['status'] == 'REQUESTED') ...[
                                    const SizedBox(height: 12),
                                    if (record['requestedById'] ==
                                        api.user!['id'])
                                      const Text(
                                        'Awaiting review by another Super Admin.',
                                      )
                                    else
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          FilledButton(
                                            onPressed: busy
                                                ? null
                                                : () => applicationDialog(
                                                    record: record,
                                                    decision: 'APPROVED',
                                                  ),
                                            child: const Text('Approve'),
                                          ),
                                          OutlinedButton(
                                            onPressed: busy
                                                ? null
                                                : () => applicationDialog(
                                                    record: record,
                                                    decision: 'REJECTED',
                                                  ),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Previous page',
                            onPressed: busy || page == 1
                                ? null
                                : () => run(() async {
                                    page--;
                                    records = [];
                                    await load();
                                  }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page $page'),
                          IconButton(
                            tooltip: 'Next page',
                            onPressed: busy || records.length < 20
                                ? null
                                : () => run(() async {
                                    page++;
                                    records = [];
                                    await load();
                                  }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (api.user == null) return legacy;
    final version = api.sessionVersion;
    return PlatformWorkspaceShell(
      isAdmin: isAdmin,
      name: '${api.user!['fullName']}',
      page: currentPage,
      busy: busy,
      onNavigate: navigateTo,
      actions: [
        WorkspaceAccountMenu(
          fullName: '${api.user!['fullName']}',
          roleLabel: isAdmin ? 'Super Admin' : 'IT / Security',
          email: api.user!['email'] as String?,
          compact: MediaQuery.sizeOf(context).width < 900,
          enabled: !busy,
          onSignOut: () => requestLogout(false),
          onSignOutAll: () => requestLogout(true),
          onSessions: isAdmin ? null : () => navigateTo(PlatformPage.sessions),
          onChangePassword: () async {
            final changed = await showSchoolPasswordDialog(
              context,
              (_, body) => api.call('/change-password', body: body),
            );
            if (changed) {
              api.clear();
              if (mounted) setState(() {});
            }
          },
        ),
      ],
      child: integrationsView && !isAdmin
          ? PlatformIntegrationsPage(
              key: ValueKey('integrations-${api.sessionVersion}'),
              request: () => api.call('/integrations'),
              checkSmtp: () => api.call('/integrations/smtp/check', body: {}),
              checkQuran: () => api.call('/integrations/quran/check', body: {}),
              checkSms: () => api.call('/integrations/sms/check', body: {}),
              checkPayment: () =>
                  api.call('/integrations/payments/check', body: {}),
              onAudit: () => navigateTo(PlatformPage.history),
              onHealth: () => navigateTo(PlatformPage.health),
            )
          : offlineSyncView && !isAdmin
          ? PlatformSyncRegister(
              request: (path) => api.call(path),
              onAudit: () => navigateTo(PlatformPage.history),
              onIncidents: () => navigateTo(PlatformPage.incidents),
              onInvestigate: (description) {
                incidentToOpen = null;
                incidentDraft = description;
                navigateTo(PlatformPage.incidents);
              },
            )
          : backupsView && !isAdmin
          ? PlatformBackupRequests(
              onAudit: () => navigateTo(PlatformPage.history),
              request: api.bindSession(),
              showForm: (context, builder) => sessionDialog<bool>(
                context: context,
                builder: builder,
                barrierDismissible: false,
              ),
            )
          : updatesView && !isAdmin
          ? PlatformUpdatesPage(
              onAudit: () => navigateTo(PlatformPage.history),
              onIncidents: () => navigateTo(PlatformPage.incidents),
            )
          : incidentsView && !isAdmin
          ? SecurityIncidentRegister(
              initialIncidentId: incidentToOpen,
              initialStatus: incidentInitialStatus,
              initialPriority: incidentInitialPriority,
              initialDescription: incidentDraft,
              request: api.bindSession(),
              showForm: (context, builder) => sessionDialog<bool>(
                context: context,
                builder: builder,
                barrierDismissible: false,
              ),
            )
          : audit && !sessionsView && !accountsView && !isAdmin
          ? PlatformAuditPage(
              records: records,
              busy: busy,
              error: error,
              page: page,
              filters: auditPageFilters(),
              onDetails: auditEventDetails,
              exportPdf: (ids) =>
                  api.call('/audit-events/pdf', body: {'ids': ids}),
              onRefresh: () => run(load),
              onPage: (value) => run(() async {
                page = value;
                records = [];
                await load();
              }),
            )
          : sessionsView && !isAdmin
          ? PlatformSessionsPage(
              oversight: true,
              onFilter: (value) => run(() async {
                sessionFilter = value;
                page = 1;
                records = [];
                await load();
              }),
              onSearch: (value) => run(() async {
                sessionSearch = value;
                page = 1;
                records = [];
                await load();
              }),
              source: sessionSource,
              onSource: (value) => run(() async {
                sessionSource = value;
                sessionFilter = 'all';
                page = 1;
                records = [];
                await load();
              }),
              records: records,
              busy: busy,
              error: error,
              page: page,
              details: sessionCard,
              onRefresh: () => run(load),
              onPage: (value) => run(() async {
                page = value;
                records = [];
                await load();
              }),
            )
          : accountsView && !isAdmin
          ? PlatformAccessPage(
              records: records,
              busy: busy,
              error: error,
              page: page,
              role: accountRole,
              status: accountStatus,
              onStatus: (value) => run(() async {
                accountStatus = value;
                page = 1;
                records = [];
                await load();
              }),
              onRefresh: () => run(load),
              onReview: accountAccessHistory,
              onRole: (value) => run(() async {
                accountRole = value;
                page = 1;
                records = [];
                await load();
              }),
              onPage: (value) => run(() async {
                page = value;
                records = [];
                await load();
              }),
            )
          : healthView && !isAdmin
          ? PlatformSystemHealthPage(
              snapshot: health,
              busy: busy,
              error: error,
              onRefresh: () => run(load),
              onInvestigate: (description) {
                incidentToOpen = null;
                incidentDraft = description;
                navigateTo(PlatformPage.incidents);
              },
            )
          : reportsView
          ? InstitutionalReportsPage(
              load: (path) => api.call(path),
              post: (path, body) => api.call(path, body: body),
            )
          : fundsView
          ? PlatformFundsPage(
              load: (path) => api.call(path),
              post: (path, body) => api.call(path, body: body),
              onSessionExpired: () {
                if (mounted) setState(() {});
              },
            )
          : oversightView
          ? CurriculumOversightPage(
              key: ValueKey(version),
              load: (path) => api.call(path),
              onBack: () => navigateTo(PlatformPage.curriculum),
              onSessionExpired: () {
                if (mounted) setState(() {});
              },
            )
          : curriculumView
          ? PlatformCurriculumPage(
              key: ValueKey(version),
              call: api.call,
              accountId: '${api.user!['id']}',
              onOpenOversight: () => navigateTo(PlatformPage.oversight),
              onSessionExpired: () {
                if (mounted) setState(() {});
              },
            )
          : staffView
          ? PlatformStaffPage(
              key: ValueKey(version),
              load: (path) => api.call(path),
              onCompanyAccounts: () => navigateTo(PlatformPage.accounts),
              onApplications: () => navigateTo(PlatformPage.applications),
              onSessionExpired: () {
                if (mounted) setState(() {});
              },
            )
          : madrasasView
          ? PlatformMadrasasPage(
              key: ValueKey(version),
              load: (path) => api.call(path),
              onApplications: () => navigateTo(PlatformPage.applications),
              onAdd: () async {
                await applicationDialog();
                if (context.mounted &&
                    (error != null || confirmation != null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? confirmation!)),
                  );
                }
              },
              onOnboarding: (id) => showOnboardingProgress({'id': id}),
              onReview: (record, decision) async {
                final saved = await applicationDialog(
                  record: {
                    'id': record['applicationId'],
                    'schoolName': record['name'],
                    'requestedCode': record['code'],
                    'adminEmail': record['adminEmail'],
                    'location': record['location'],
                  },
                  decision: decision,
                );
                if (context.mounted &&
                    (error != null || confirmation != null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? confirmation!)),
                  );
                }
                return saved;
              },
              onSessionExpired: () {
                if (mounted) setState(() {});
              },
            )
          : homeView
          ? PlatformOverview(
              onIncidentFilter: (highOnly) {
                incidentInitialStatus = 'UNRESOLVED';
                incidentInitialPriority = highOnly ? 'HIGH' : null;
                navigateTo(PlatformPage.incidents);
              },
              onIncident: (id) {
                incidentToOpen = id;
                navigateTo(PlatformPage.incidents);
              },
              isAdmin: isAdmin,
              name: '${api.user!['fullName']}',
              snapshot: isAdmin ? overview : health,
              busy: busy,
              error: error,
              onRefresh: () => run(load),
              onNavigate: navigateTo,
              onReviewPending: () {
                applicationStatus = 'REQUESTED';
                applicationScope = 'reviewable';
                navigateTo(PlatformPage.applications);
              },
              onApproved: () {
                applicationStatus = 'APPROVED';
                applicationScope = '';
                navigateTo(PlatformPage.applications);
              },
              healthPanel: isAdmin
                  ? null
                  : PlatformHealthPanel(snapshot: health, loading: busy),
            )
          : legacy.body!,
    );
  }

  Future<void> disableItAccount(
    Map<String, dynamic> record, {
    bool restore = false,
  }) async {
    final version = api.sessionVersion;
    Map<String, dynamic>? suspension;
    if (restore) {
      await run(() async {
        final events =
            await api.call(
                  '/accounts/${record['id']}/access-history?page=1&pageSize=1',
                )
                as List;
        if (events.isEmpty ||
            events.first['action'] != 'platform.account.disabled') {
          throw const ApiException(
            'No current suspension to review. Refresh the account list.',
            409,
          );
        }
        suspension = Map<String, dynamic>.from(events.first as Map);
      });
      if (!mounted ||
          api.user == null ||
          api.sessionVersion != version ||
          suspension == null) {
        return;
      }
    }
    var reason = '';
    final dialogForm = GlobalKey<FormState>();
    final confirmed = await sessionDialog<bool>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        title: Text(restore ? 'Restore IT access?' : 'Disable IT account?'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: dialogForm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkspaceRecordDetails(
                    fields: [
                      ('Account name', '${record['fullName']}'),
                      ('Email address', '${record['email']}'),
                    ],
                  ),
                  if (suspension != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Suspension being reviewed',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(
                      'By account: ${suspension!['actorId']}\n${suspension!['createdAt']}',
                    ),
                    SelectableText(
                      suspension!['reason'] as String? ?? 'No reason recorded.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    restore
                        ? 'Only a different Super Admin can approve this restoration. Confirm the reason for suspension has been resolved. IT must sign in again with email and password; old sessions remain revoked.'
                        : 'This blocks login and revokes all sessions. The account and audit history are kept. Restoration requires a different Super Admin.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    onChanged: (value) => reason = value,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      helperText: 'Do not include passwords or other secrets.',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 10
                        ? 'Enter at least 10 characters.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (dialogForm.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(restore ? 'Confirm restore' : 'Confirm disable'),
          ),
        ],
      ),
    );
    final explanation = reason.trim();
    if (confirmed != true ||
        !mounted ||
        api.user == null ||
        api.sessionVersion != version) {
      return;
    }
    await run(() async {
      overview = null;
      try {
        await api.call(
          '/accounts/${record['id']}/${restore ? 'restore' : 'disable'}',
          body: {
            'reason': explanation,
            if (restore) 'suspensionEventId': suspension!['id'],
          },
        );
      } catch (e) {
        if (e is ApiException && e.statusCode < 500) {
          if (e.statusCode == 409) records = [];
          rethrow;
        }
        records = [];
        throw const ApiException(
          'We could not confirm the access change. Refresh Company accounts and check Access history before trying again.',
          503,
        );
      }
      if (!mounted || api.user == null) return;
      confirmation = restore
          ? 'IT access restored. Sign in again with email and password; old sessions remain revoked.'
          : 'IT account disabled. Login is blocked and its sessions are revoked.';
      records = [];
      try {
        await load();
      } catch (e) {
        if (api.user == null) rethrow;
        throw const ApiException(
          'The access change was saved, but the account list could not be refreshed. Use Refresh; do not repeat the access change.',
          503,
        );
      }
    });
  }

  Future<void> accountAccessHistory(Map<String, dynamic> record) async {
    await sessionDialog<void>(
      context: context,
      builder: (context) => _AccountHistoryDialog(
        api: api,
        accountId: record['id'] as String,
        fullName: record['fullName'] as String,
      ),
    );
    if (mounted) setState(() {});
  }

  Widget overviewMetric(String label, dynamic value) => SizedBox(
    width: 230,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    ),
  );

  Widget accountCard(Map<String, dynamic> record) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xffedf3f6),
                foregroundColor: Color(0xff102c3b),
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${record['fullName'] ?? 'Company account'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText('${record['email']}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(switch (record['role']) {
                  'SUPER_ADMIN' => 'Super Admin',
                  'IT_SECURITY' => 'IT Security',
                  _ => 'Role unavailable',
                }),
              ),
              PlatformAccountStatus(status: record['status'] as String?),
              if (record['id'] == api.user?['id'])
                const Chip(label: Text('Your account')),
            ],
          ),
          Text(switch (record['role']) {
            'SUPER_ADMIN' =>
              'Platform governance, independent madrassa review and company oversight.',
            'IT_SECURITY' =>
              'Platform audit and service health. No school academic or finance access.',
            _ =>
              'Account responsibilities are unavailable. Refresh before taking action.',
          }),
          const SizedBox(height: 8),
          ItRecordDetails(
            values: {
              'Account ID': record['id'],
              'Created (UTC)': record['createdAt'],
            },
          ),
          if (api.user?['role'] == 'IT_SECURITY' || isAdmin)
            TextButton.icon(
              onPressed: busy ? null : () => accountAccessHistory(record),
              icon: const Icon(Icons.history),
              label: const Text('Access history'),
            ),
          if (api.user?['role'] == 'SUPER_ADMIN' &&
              record['role'] == 'IT_SECURITY' &&
              ['ACTIVE', 'DISABLED'].contains(record['status'])) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => disableItAccount(
                      record,
                      restore: record['status'] == 'DISABLED',
                    ),
              icon: Icon(
                record['status'] == 'DISABLED'
                    ? Icons.verified_user
                    : Icons.block,
              ),
              label: Text(
                record['status'] == 'DISABLED'
                    ? 'Review restoration'
                    : 'Disable IT account',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget sessionCard(Map<String, dynamic> record) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record['current'] == true ? 'Current session' : 'Another session',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ItRecordDetails(
            values: {
              'Session ID': record['id'],
              if (record['source'] != null) ...{
                'Account': record['accountName'],
                'Role': record['role'],
                'Scope': record['scope'],
                'IP address': record['ipAddress'],
                'Access type': record['source'] == 'madrasa'
                    ? 'Renewable access (not live presence)'
                    : 'Platform session',
              },
              'Signed in (UTC)': record['createdAt'],
              'Expires (UTC)': record['expiresAt'],
            },
          ),
          const SizedBox(height: 12),
          if (record['canRevoke'] != false)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await sessionDialog<bool>(
                        context: context,
                        builder: (context) => WorkspaceFormDialog(
                          icon: Icons.logout_rounded,
                          eyebrow: 'SESSION / CONFIRM ACTION',
                          title: const Text('Revoke this session?'),
                          content: Text(
                            record['current'] == true
                                ? 'You will be signed out of this platform session.'
                                : 'That session will no longer be able to make new requests. Requests already running may finish.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Revoke session'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted || api.user == null) {
                        return;
                      }
                      await run(() async {
                        final result = await api.call(
                          '/sessions/${record['id']}/revoke',
                          body: {},
                        );
                        if (result['current'] == true) {
                          api.clear();
                          expiry?.cancel();
                          records = [];
                        } else {
                          await load();
                        }
                      });
                    },
              child: Text(
                record['current'] == true
                    ? 'Sign out this session'
                    : 'Revoke session',
              ),
            ),
        ],
      ),
    ),
  );

  Widget auditPageFilters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (auditActorId != null ||
          auditApplicationId != null ||
          auditTechnicalReviewId != null) ...[
        Text(
          'Filtered history: ${auditActorId ?? auditApplicationId ?? auditTechnicalReviewId}',
        ),
        TextButton(
          onPressed: busy ? null : () => openApplicationAudit(null),
          child: const Text('Show all application and platform events'),
        ),
      ],
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          auditFilter('Event', auditAction, const {
            '': 'All events',
            'tenant.technical-review.recorded': 'IT sign-off recorded',
            'tenant.technical-review.withdrawn': 'IT sign-off withdrawn',
            'platform.login.failed': 'Failed login',
            'platform.audit.exported': 'Audit PDF generated',
            'platform.login.succeeded': 'Successful login',
            'tenant.application.requested': 'Madrassa requested',
            'tenant.application.approved': 'Madrassa approved',
            'tenant.application.rejected': 'Madrassa rejected',
            'tenant.school.provisioned': 'Inactive madrassa created',
            'tenant.admin.invitation.issued': 'Admin invitation recorded',
            'tenant.school.activated': 'Madrassa activated',
            'platform.session.revoked': 'Session revoked',
            'platform.sessions.revoked': 'All sessions revoked',
            'platform.account.bootstrapped': 'Reviewer created',
            'platform.account.disabled': 'IT account disabled',
            'platform.account.restored': 'IT account restored',
          }, (value) => auditAction = value),
          auditFilter('Role', auditRole, const {
            '': 'All roles',
            'SUPER_ADMIN': 'Super Admin',
            'IT_SECURITY': 'IT / Security',
          }, (value) => auditRole = value),
          auditFilter(
            'Period',
            auditPeriod,
            const {
              '': 'All time',
              '1': 'Last 24 hours',
              '7': 'Last 7 days',
              '30': 'Last 30 days',
            },
            (value) {
              auditPeriod = value;
              auditSince = value.isEmpty
                  ? null
                  : DateTime.now().toUtc().subtract(
                      Duration(days: int.parse(value)),
                    );
            },
          ),
          if (auditAction.isNotEmpty ||
              auditRole.isNotEmpty ||
              auditPeriod.isNotEmpty)
            TextButton.icon(
              onPressed: busy ? null : () => openApplicationAudit(null),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
        ],
      ),
    ],
  );

  Future<void> auditEventDetails(Map<String, dynamic> record) async {
    final next = await sessionDialog<String>(
      context: context,
      builder: (context) => WorkspaceFormDialog(
        icon: Icons.history_rounded,
        eyebrow: 'AUDIT EVENT / READ-ONLY',
        title: Text('${record['action']}'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: ItRecordDetails(
              values: {
                'Event ID': record['id'],
                'Actor ID': record['actorId'],
                'Actor role': record['actorRole'],
                'Recorded (UTC)': record['createdAt'],
                'Record type': record['entityType'],
                'Reference': record['entityId'],
                if (record['metadata'] is Map)
                  for (final entry in (record['metadata'] as Map).entries)
                    'Detail: ${entry.key}':
                        entry.value is Map || entry.value is List
                        ? jsonEncode(entry.value)
                        : entry.value,
              },
            ),
          ),
        ),
        actions: [
          if (record['actorId'] is String &&
              (record['actorId'] as String).isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, 'actor'),
              child: const Text('View actor activity'),
            ),
          if (record['entityType'] == 'TenantApplication' &&
              record['entityId'] is String)
            TextButton(
              onPressed: () => Navigator.pop(context, 'application'),
              child: const Text('View application history'),
            ),
          if ((record['action'] == 'tenant.technical-review.recorded' &&
                  record['entityType'] == 'TenantApplication' &&
                  record['id'] is String) ||
              (record['action'] == 'tenant.technical-review.withdrawn' &&
                  record['entityType'] == 'TechnicalReview' &&
                  record['entityId'] is String))
            TextButton(
              onPressed: () => Navigator.pop(context, 'signoff'),
              child: const Text('View sign-off history'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!mounted || api.user == null) return;
    if (next == 'actor') {
      await openApplicationAudit(null, actorId: record['actorId'] as String);
    }
    if (next == 'application') {
      await openApplicationAudit(record['entityId'] as String);
    }
    if (next == 'signoff') {
      await openApplicationAudit(
        null,
        technicalReviewId:
            record[record['entityType'] == 'TechnicalReview'
                    ? 'entityId'
                    : 'id']
                as String,
      );
    }
  }

  Widget auditFilter(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) update,
  ) => SizedBox(
    width: 240,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: busy
          ? null
          : (next) {
              if (next == null) return;
              run(() async {
                update(next);
                page = 1;
                records = [];
                await load();
              });
            },
    ),
  );
}

class PlatformHealthPanel extends StatefulWidget {
  const PlatformHealthPanel({
    super.key,
    required this.snapshot,
    required this.loading,
    this.now,
  });
  final Map<String, dynamic>? snapshot;
  final bool loading;
  final DateTime Function()? now;

  @override
  State<PlatformHealthPanel> createState() => _PlatformHealthPanelState();
}

class _PlatformHealthPanelState extends State<PlatformHealthPanel> {
  Timer? freshnessTimer;

  @override
  void initState() {
    super.initState();
    freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && widget.snapshot != null) setState(() {});
    });
  }

  @override
  void dispose() {
    freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final loading = widget.loading;
    final checkedAt = DateTime.tryParse('${snapshot?['checkedAt']}');
    final now = (widget.now ?? DateTime.now)().toUtc();
    final age = checkedAt == null ? null : now.difference(checkedAt.toUtc());
    final timeUnknown = age == null || age.isNegative;
    final stale = !timeUnknown && age >= const Duration(seconds: 60);
    final checks = (snapshot?['checks'] as List? ?? [])
        .whereType<Map>()
        .where((row) => ['database', 'redis'].contains(row['name']))
        .where((row) => ['available', 'unavailable'].contains(row['status']))
        .toList();
    final healthy =
        checks.map((row) => row['name']).toSet().length == 2 &&
        checks.every((row) => row['status'] == 'available');
    final databaseUnavailable = checks.any(
      (check) => check['name'] == 'database' && check['status'] != 'available',
    );
    final redisUnavailable = checks.any(
      (check) => check['name'] == 'redis' && check['status'] != 'available',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot == null
                      ? (loading
                            ? 'Checking services...'
                            : 'No health result available')
                      : timeUnknown
                      ? 'Health check time cannot be verified'
                      : stale
                      ? 'Health results need refreshing'
                      : healthy
                      ? 'Core services available'
                      : !databaseUnavailable && !redisUnavailable
                      ? 'Service availability is not fully verified'
                      : 'Service attention needed',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Point-in-time connectivity checks, not an uptime guarantee or a security scan. Use Refresh to check again.',
                ),
                if (snapshot != null) ...[
                  const SizedBox(height: 8),
                  if (timeUnknown || stale)
                    Text(
                      timeUnknown
                          ? 'The check timestamp is missing, invalid or ahead of this device clock. Verify the clock and use Refresh; current service availability is unknown.'
                          : 'This snapshot is at least 60 seconds old. Current service availability is unknown. Use Refresh for a new check.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 14),
                  ItRecordDetails(
                    values: {
                      'Last checked (UTC)': snapshot['checkedAt'],
                      'Cache window': 'Up to 5 seconds',
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        for (final check in checks)
          Card(
            child: ListTile(
              leading: Icon(
                timeUnknown || stale
                    ? Icons.schedule
                    : check['status'] == 'available'
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: timeUnknown || stale
                    ? Colors.grey
                    : check['status'] == 'available'
                    ? const Color(0xff197447)
                    : const Color(0xffa32e2e),
              ),
              title: Text(
                check['name'] == 'database'
                    ? 'Database'
                    : 'Redis / login rate limiting',
              ),
              subtitle: Text(
                timeUnknown || stale
                    ? 'Current availability unknown'
                    : check['status'] == 'available'
                    ? 'Available'
                    : 'Unavailable. Escalate to the on-call operator.',
              ),
              trailing: check['latencyMs'] == null
                  ? null
                  : Text('${check['latencyMs']} ms'),
            ),
          ),
        if (databaseUnavailable || redisUnavailable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operator next steps',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (databaseUnavailable)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Database: verify service availability and API connectivity using approved infrastructure tools. Reads and writes may fail. If a write timed out, verify its outcome before submitting it again.',
                      ),
                    ),
                  if (redisUnavailable)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Redis: verify the service and API connectivity. Protected login rate limiting may deny new sign-ins while Redis is unavailable. Do not bypass rate limits or session checks to restore access.',
                      ),
                    ),
                  const Text(
                    'Record the check time and affected service in your approved incident channel. Do not include passwords, tokens or school records. Escalate to the on-call operator, then use Refresh to verify recovery. This panel does not create an incident or restart services.',
                  ),
                ],
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Threat detection, backup verification and incident management are not connected yet. If authentication or the API is down, this protected page may be unreachable; use independent infrastructure monitoring.',
          ),
        ),
      ],
    );
  }
}
