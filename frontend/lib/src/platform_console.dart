import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'foundation_ui.dart';
import 'platform_provisioning_panel.dart';
import 'platform_onboarding_progress.dart';

String platformTimestamp(dynamic value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  return parsed?.toUtc().toIso8601String() ?? 'Not recorded';
}

/// Platform credentials never enter school session storage or browser cookies.
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

  Future<dynamic> call(String path, {Map<String, dynamic>? body}) async {
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Access history'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        controller: scroll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.fullName}\nPage $page. Times are UTC.'),
            const Text(
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
              SelectableText(
                'By account: ${event['actorId']}\n${event['createdAt']}',
              ),
              const SizedBox(height: 6),
              SelectableText(
                event['reason'] as String? ?? 'No reason recorded.',
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
  const PlatformConsole({super.key, this.api});
  final PlatformApi? api;
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
  String auditRole = '';
  String auditPeriod = '';
  DateTime? auditSince;
  bool healthView = false;
  bool sessionsView = false;
  bool accountsView = false;
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
  }) async {
    final version = api.sessionVersion;
    final route = DialogRoute<T>(context: context, builder: builder);
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
    // Never present a previous access/audit snapshot as a successful refresh.
    setState(() => records = []);
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
          ? '/sessions'
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
      audit = !isAdmin;
      auditApplicationId = null;
      healthView = false;
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

  Future<void> openApplicationAudit(String? id) => run(() async {
    audit = true;
    healthView = false;
    sessionsView = false;
    accountsView = false;
    overview = null;
    auditApplicationId = id;
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
    final version = api.sessionVersion;
    Map<String, dynamic>? result;
    await run(() async {
      result = Map<String, dynamic>.from(
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
    await sessionDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onboarding progress'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: RefreshableOnboardingProgress(
              initialData: data,
              sessionIsCurrent: () =>
                  api.user != null && api.sessionVersion == version,
              load: () async => Map<String, dynamic>.from(
                await api.call(
                      '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/onboarding-progress',
                    )
                    as Map,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> inspectProvisioning(Map<String, dynamic> record) async {
    if (busy) return;
    final version = api.sessionVersion;
    Map<String, dynamic>? result;
    await run(() async {
      result = Map<String, dynamic>.from(
        await api.call(
              '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/provisioning-preflight',
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
    final checks = Map<String, dynamic>.from(data['checks'] as Map);
    await sessionDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Madrassa setup checks'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record['schoolName']} / ${record['requestedCode']}'),
                const SizedBox(height: 16),
                Text(
                  checks['independentReview'] == true
                      ? 'Passed: independent approval recorded.'
                      : 'Blocked: independent approval is incomplete.',
                ),
                const SizedBox(height: 8),
                Text(
                  data['alreadyProvisioned'] == true
                      ? 'Already provisioned: this application has a linked madrassa. Do not create another.'
                      : checks['schoolCodeAvailable'] == true
                      ? 'Passed: school code is currently available.'
                      : 'Blocked: school code is already in use.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'This check does not create a madrassa, reserve its code, or send an invitation. Automatic provisioning is not enabled yet.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Next stages: create an inactive madrassa, invite the first admin, verify acceptance, then activate the school.',
                ),
                const SizedBox(height: 12),
                Text('Checked: ${platformTimestamp(data['checkedAt'])}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            ? 'Signed out on this device. We could not confirm sign-out on all sessions. Sign in again and use My sessions to review access.'
            : 'Signed out on this device. Server sign-out could not be confirmed. Sign in again and use My sessions to review access.',
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

  Future<void> applicationDialog({
    Map<String, dynamic>? record,
    String? decision,
  }) async {
    final version = api.sessionVersion;
    final name = TextEditingController();
    final schoolCode = TextEditingController();
    final adminEmail = TextEditingController();
    final reason = TextEditingController();
    final key = GlobalKey<FormState>();
    final body = await sessionDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          record == null ? 'Request a madrassa' : '$decision application',
        ),
        content: SizedBox(
          width: 440,
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
                    TextFormField(
                      controller: schoolCode,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Unique code (e.g. afaq-school)',
                      ),
                      validator: (v) =>
                          !RegExp(
                                r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
                              ).hasMatch(v ?? '') ||
                              (v?.length ?? 0) < 3
                          ? 'Use lowercase letters, numbers and hyphens.'
                          : null,
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
                  ] else ...[
                    SelectableText(
                      '${record['schoolName']}\nCode: ${record['requestedCode']}\nNominated admin: ${record['adminEmail']}\nApplication ID: ${record['id']}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      decision == 'APPROVED'
                          ? 'Approval records the review only. It does not activate the madrassa or create school accounts.'
                          : 'Rejection closes this request. It does not delete school data or disable an existing madrassa.',
                    ),
                    const Text(
                      'This decision cannot be edited after confirmation.',
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
                        'requestedCode': schoolCode.text,
                        'adminEmail': adminEmail.text.trim(),
                      }
                    : {'decision': decision, 'reason': reason.text.trim()},
              );
            },
            child: Text(record == null ? 'Submit request' : 'Confirm decision'),
          ),
        ],
      ),
    );
    // The closing dialog may still animate with these controllers attached.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    schoolCode.dispose();
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
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Afaq / Platform governance'),
      actions: [
        if (api.user != null)
          PopupMenuButton<bool>(
            enabled: !busy,
            tooltip: 'Sign out options',
            onSelected: requestLogout,
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('Sign out')),
              PopupMenuItem(value: true, child: Text('Sign out all sessions')),
            ],
          ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                  'Sessions last 15 minutes. Refreshing this page requires a new sign-in. Access is provisioned by an authorized operator; there is no public signup.',
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
                  if (isAdmin) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                overview = null;
                                final result = await api.call('/overview');
                                if (mounted && api.user != null) {
                                  overview = Map<String, dynamic>.from(
                                    result as Map,
                                  );
                                }
                              }),
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
                              Text('Checked (UTC): ${overview!['checkedAt']}'),
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
                      if (isAdmin)
                        ChoiceChip(
                          label: const Text('Madrassa applications'),
                          selected:
                              !audit &&
                              !healthView &&
                              !sessionsView &&
                              !accountsView,
                          onSelected: busy
                              ? null
                              : (_) => run(() async {
                                  audit = false;
                                  healthView = false;
                                  sessionsView = false;
                                  accountsView = false;
                                  page = 1;
                                  records = [];
                                  await load();
                                }),
                        ),
                      ChoiceChip(
                        label: const Text('Audit trail'),
                        selected:
                            audit &&
                            !healthView &&
                            !sessionsView &&
                            !accountsView,
                        onSelected: busy
                            ? null
                            : (_) => run(() async {
                                audit = true;
                                healthView = false;
                                sessionsView = false;
                                accountsView = false;
                                page = 1;
                                records = [];
                                await load();
                              }),
                      ),
                      if (api.user?['role'] == 'IT_SECURITY')
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  final version = api.sessionVersion;
                                  await sessionDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Madrassa setup'),
                                      content: SizedBox(
                                        width: 620,
                                        child: SingleChildScrollView(
                                          child: PlatformProvisioningPanel(
                                            call: api.call,
                                            sessionIsCurrent: () =>
                                                api.user != null &&
                                                api.sessionVersion == version,
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                },
                          icon: const Icon(Icons.domain_add_outlined),
                          label: const Text('Madrassa setup'),
                        ),
                      ChoiceChip(
                        label: const Text('System health'),
                        selected: healthView,
                        onSelected: busy
                            ? null
                            : (_) => run(() async {
                                healthView = true;
                                sessionsView = false;
                                accountsView = false;
                                records = [];
                                await load();
                              }),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => run(load),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      ChoiceChip(
                        label: const Text('My sessions'),
                        selected: sessionsView,
                        onSelected: busy
                            ? null
                            : (_) => run(() async {
                                sessionsView = true;
                                accountsView = false;
                                healthView = false;
                                page = 1;
                                records = [];
                                await load();
                              }),
                      ),
                      if (isAdmin)
                        ChoiceChip(
                          label: const Text('Company accounts'),
                          selected: accountsView,
                          onSelected: busy
                              ? null
                              : (_) => run(() async {
                                  accountsView = true;
                                  sessionsView = false;
                                  healthView = false;
                                  page = 1;
                                  records = [];
                                  await load();
                                }),
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
                          ? 'Company accounts only. School users are managed separately. Super Admin can disable active IT accounts; Super Admin accounts are protected.'
                          : sessionsView
                          ? 'Your active sessions. Times are UTC. Only sessions belonging to your account are shown.'
                          : audit
                          ? 'Platform activity'
                          : 'Request > Independent review > IT setup > Admin invitation (pending)',
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
                      if (auditApplicationId != null) ...[
                        Text('Application history: $auditApplicationId'),
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
                            const {
                              '': 'All events',
                              'platform.login.failed': 'Failed login',
                              'platform.login.succeeded': 'Successful login',
                              'tenant.application.requested':
                                  'Madrassa requested',
                              'tenant.application.approved':
                                  'Madrassa approved',
                              'tenant.application.rejected':
                                  'Madrassa rejected',
                              'tenant.school.provisioned':
                                  'Inactive madrassa created',
                              'tenant.admin.invitation.issued':
                                  'Admin invitation recorded',
                              'tenant.school.activated': 'Madrassa activated',
                              'platform.session.revoked': 'Session revoked',
                              'platform.sessions.revoked':
                                  'All sessions revoked',
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Times are UTC. Failed login events identify the account targeted, not a verified person. Filters do not grant school-data access.',
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
                                Text(
                                  '${record[audit ? 'action' : 'schoolName']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  audit
                                      ? '${record['actorRole']} / ${record['entityType']}\n${record['createdAt']}'
                                      : '${record['requestedCode']} / ${record['status']}\nAdmin: ${record['adminEmail']}',
                                ),
                                if (audit)
                                  ExpansionTile(
                                    key: ValueKey(record['id']),
                                    title: const Text('Event details'),
                                    tilePadding: EdgeInsets.zero,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: SelectableText(
                                          'Event ID: ${record['id']}\nAccount ID: ${record['actorId']}\nEntity ID: ${record['entityId']}'
                                          '${record['metadata'] is Map && (record['metadata'] as Map).isNotEmpty ? '\nStatus details: ${jsonEncode(record['metadata'])}' : ''}',
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!audit && record['decisionReason'] != null)
                                  Text('Decision: ${record['decisionReason']}'),
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
                                          : () =>
                                                showOnboardingProgress(record),
                                      icon: const Icon(
                                        Icons.checklist_outlined,
                                      ),
                                      label: const Text('Onboarding progress'),
                                    ),
                                  if (record['status'] == 'APPROVED')
                                    OutlinedButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => inspectProvisioning(record),
                                      icon: const Icon(
                                        Icons.fact_check_outlined,
                                      ),
                                      label: const Text(
                                        'Check setup readiness',
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
      builder: (context) => AlertDialog(
        title: Text(restore ? 'Restore IT access?' : 'Disable IT account?'),
        content: SingleChildScrollView(
          child: Form(
            key: dialogForm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record['fullName']}\n${record['email']}'),
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
                      ? 'Only a different Super Admin can approve this restoration. Confirm the reason for suspension has been resolved. IT must sign in again with MFA; old sessions remain revoked.'
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
          ? 'IT access restored. Sign in again with password and MFA; old sessions remain revoked.'
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
          Text(
            '${record['fullName']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText('${record['email']}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  record['role'] == 'SUPER_ADMIN'
                      ? 'Super Admin'
                      : 'IT Security',
                ),
              ),
              Chip(label: Text('${record['status']}')),
              if (record['id'] == api.user?['id'])
                const Chip(label: Text('Your account')),
            ],
          ),
          Text(
            record['role'] == 'SUPER_ADMIN'
                ? 'Platform governance, independent madrassa review and company oversight.'
                : 'Platform audit and service health. No school academic or finance access.',
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Account ID: ${record['id']}\nCreated (UTC): ${record['createdAt']}',
          ),
          if (api.user?['role'] == 'SUPER_ADMIN')
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
          SelectableText(
            'ID: ${record['id']}\nSigned in: ${record['createdAt']}\nExpires: ${record['expiresAt']}',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await sessionDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
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
    final healthy = snapshot?['status'] == 'healthy';
    final checks = (snapshot?['checks'] as List?) ?? [];
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
                  Text(
                    'Checked: ${snapshot['checkedAt']} (UTC). Results may be cached for 5 seconds.',
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
                check['status'] == 'available'
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: check['status'] == 'available'
                    ? const Color(0xff197447)
                    : const Color(0xffa32e2e),
              ),
              title: Text(
                check['name'] == 'database'
                    ? 'Database'
                    : 'Redis / login rate limiting',
              ),
              subtitle: Text(
                check['status'] == 'available'
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
                        'Redis: verify the service and API connectivity. Protected login rate limiting may deny new sign-ins while Redis is unavailable. Do not bypass rate limits, MFA or session checks to restore access.',
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
