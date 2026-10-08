import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'foundation_ui.dart';

class SchoolInvitationApi {
  SchoolInvitationApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultApiBaseUrl();
  final http.Client _client;
  final String baseUrl;

  Future<void> accept(String token, String fullName, String password) async {
    final response = await _client
        .post(
          Uri.parse(
            '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/school-invitations/accept',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'fullName': fullName,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw ApiException(switch (response.statusCode) {
        410 =>
          'This invitation is unavailable, expired or already used. Contact your onboarding team.',
        422 => 'Check your invitation code, name and password requirements.',
        429 => 'Too many attempts. Wait 15 minutes before trying again.',
        409 =>
          'The invitation state changed. Contact your onboarding team before trying again.',
        _ =>
          'Acceptance is unavailable or could not be confirmed. Contact your onboarding team before trying again.',
      }, response.statusCode);
    }
    final result = jsonDecode(response.body);
    if (result is! Map ||
        result['success'] != true ||
        result['data'] is! Map ||
        result['data']['status'] != 'PENDING_ACTIVATION') {
      throw const ApiException(
        'Acceptance could not be confirmed. Contact your onboarding team.',
        503,
      );
    }
  }

  void close() => _client.close();
}

class SchoolInvitationPage extends StatefulWidget {
  const SchoolInvitationPage({super.key, this.api});
  final SchoolInvitationApi? api;

  @override
  State<SchoolInvitationPage> createState() => _SchoolInvitationPageState();
}

class _SchoolInvitationPageState extends State<SchoolInvitationPage> {
  late final api = widget.api ?? SchoolInvitationApi();
  final form = GlobalKey<FormState>();
  final token = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool accepted = false;
  bool visible = false;
  String? error;

  @override
  void dispose() {
    token.dispose();
    name.dispose();
    password.dispose();
    confirmation.dispose();
    if (widget.api == null) api.close();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || accepted || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.accept(token.text.trim(), name.text.trim(), password.text);
      if (!mounted) return;
      token.clear();
      name.clear();
      setState(() {
        accepted = true;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        error = failure is ApiException
            ? failure.message
            : 'Acceptance could not be confirmed. Check your connection and contact your onboarding team before trying again.';
      });
    } finally {
      if (mounted) {
        password.clear();
        confirmation.clear();
        setState(() {
          busy = false;
          visible = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(title: const Text('Afaq / School onboarding')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ink, Color(0xff164d59)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AFAQ  /  A TRUSTED BEGINNING',
                        style: TextStyle(
                          color: Color(0xffe5c480),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        accepted
                            ? 'Your acceptance is recorded.'
                            : 'Welcome,\nSchool Administrator.',
                        style: const TextStyle(
                          fontFamily: 'NotoSerifDisplay',
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Approval  >  Your acceptance  >  Activation',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: accepted
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: forest,
                                size: 40,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Waiting for activation',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Your administrator account has been created but is not active yet. The Afaq team must complete its activation review before you can sign in.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No sign-in session has been created. Do not submit the invitation again.',
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamedAndRemoveUntil('/', (_) => false),
                                child: const Text('Return to home'),
                              ),
                            ],
                          )
                        : Form(
                            key: form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Accept your invitation',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Testing stage: email invitations and acceptance are not enabled in the current deployment. This page does not bypass that restriction.',
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: token,
                                  enabled: !busy,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Invitation code',
                                    helperText:
                                        'Keep this code private. Never put it in the URL.',
                                  ),
                                  validator: (value) =>
                                      RegExp(
                                        r'^[A-Za-z0-9_-]{43}$',
                                      ).hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'Enter the complete invitation code.',
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: name,
                                  enabled: !busy,
                                  maxLength: 150,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) >= 2
                                      ? null
                                      : 'Enter your full name.',
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: password,
                                  enabled: !busy,
                                  obscureText: !visible,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: 'New password',
                                    helperText:
                                        'At least 12 characters; no more than 72 UTF-8 bytes.',
                                    helperMaxLines: 2,
                                    suffixIcon: IconButton(
                                      tooltip: visible
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                              visible = !visible;
                                            }),
                                      icon: Icon(
                                        visible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.runes.length ?? 0) < 12
                                      ? 'Use at least 12 characters.'
                                      : utf8.encode(value!).length > 72
                                      ? 'Password exceeds 72 UTF-8 bytes.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: confirmation,
                                  enabled: !busy,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm password',
                                  ),
                                  validator: (value) =>
                                      value != password.text ||
                                          (value?.isEmpty ?? true)
                                      ? 'Passwords must match.'
                                      : null,
                                  onFieldSubmitted: (_) => submit(),
                                ),
                                if (error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Color(0xffa32e2e),
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: busy ? null : submit,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      busy
                                          ? 'Submitting...'
                                          : 'Accept invitation',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'This does not activate your madrassa or sign you in.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
