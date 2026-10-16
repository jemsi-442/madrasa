import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'public_shell.dart';

class FamilyRegistrationScreen extends StatefulWidget {
  const FamilyRegistrationScreen({
    super.key,
    required this.api,
    required this.onNavigate,
  });
  final MifApiClient api;
  final PublicNavigate onNavigate;
  @override
  State<FamilyRegistrationScreen> createState() =>
      _FamilyRegistrationScreenState();
}

class _FamilyRegistrationScreenState extends State<FamilyRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'fullName',
      'email',
      'phone',
      'childReference',
      'password',
      'confirmPassword',
    ])
      key: TextEditingController(),
  };
  bool busy = false, sent = false;
  String? receipt;
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.request(
        '/api/auth/family-registration',
        method: 'POST',
        body: {
          for (final entry in fields.entries)
            entry.key: entry.key.toLowerCase().contains('password')
                ? entry.value.text
                : entry.value.text.trim(),
        },
      );
      if (!mounted) return;
      fields['password']!.clear();
      fields['confirmPassword']!.clear();
      if (mounted) {
        setState(() {
          sent = true;
          receipt = response['receipt'] as String?;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'We could not submit your request. Please try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool password = false,
    int max = 150,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('family-register-$key'),
      controller: fields[key],
      enabled: !busy,
      obscureText: password,
      autocorrect: !password,
      enableSuggestions: !password,
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : key == 'phone'
          ? TextInputType.phone
          : TextInputType.text,
      textInputAction: key == 'confirmPassword'
          ? TextInputAction.done
          : TextInputAction.next,
      maxLines: key == 'childReference' ? 3 : 1,
      decoration: InputDecoration(labelText: label),
      onFieldSubmitted: key == 'confirmPassword' ? (_) => submit() : null,
      validator: (value) {
        final raw = value ?? '', text = raw.trim();
        if (password) {
          if (raw.length < 8 || utf8.encode(raw).length > 72) {
            return 'Use at least 8 characters, within 72 UTF-8 bytes.';
          }
          if (key == 'confirmPassword' && raw != fields['password']!.text) {
            return 'Passwords do not match.';
          }
        } else {
          if (text.length < (key == 'phone' ? 8 : 2) || text.length > max) {
            return 'Check this field (maximum $max characters).';
          }
          if (key == 'email' &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
            return 'Enter a valid email address.';
          }
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AuthFrame(
      onNavigate: (path) {
        if (!busy) widget.onNavigate(path);
      },
      mobileTitle: 'Family registration',
      child: sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 48,
                  color: publicGold,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your request has been received',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contact your school office to verify your family details. The office will provide your sign-in details after approval. No email has been sent. Your children\'s records remain private until verification.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keep this receipt private and provide it to your school during verification. It is not your login or password.',
                ),
                if (receipt != null)
                  SelectableText(
                    receipt!,
                    key: const ValueKey('family-request-receipt'),
                  ),
                const SizedBox(height: 20),
                GoldAction(
                  label: 'Back to Login',
                  onPressed: () => widget.onNavigate('/login'),
                ),
              ],
            )
          : Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'One family. Connected learning.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: publicInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create your family access request. Your school will verify the guardian relationship before giving access to any child\'s records.',
                  ),
                  const SizedBox(height: 24),
                  field('fullName', 'Your full name'),
                  field('email', 'Email address'),
                  field('phone', 'Phone number', max: 30),
                  field(
                    'childReference',
                    'Children\'s names or admission numbers',
                    max: 500,
                  ),
                  field('password', 'Password', password: true),
                  field('confirmPassword', 'Confirm password', password: true),
                  if (error != null) FormNotice(error!),
                  GoldAction(
                    label: 'Submit family request',
                    busy: busy,
                    onPressed: submit,
                  ),
                  TextButton(
                    onPressed: busy ? null : () => widget.onNavigate('/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
    ),
  );
}
