import 'package:flutter/material.dart';

import 'api_client.dart';
import 'public_shell.dart';

class OfficeHelpScreen extends StatefulWidget {
  const OfficeHelpScreen({
    super.key,
    required this.api,
    required this.onNavigate,
    required this.path,
  });

  final MifApiClient api;
  final PublicNavigate onNavigate;
  final String path;

  @override
  State<OfficeHelpScreen> createState() => _OfficeHelpScreenState();
}

class _OfficeHelpScreenState extends State<OfficeHelpScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final message = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? error;

  bool get recovery => widget.path == '/forgot-password';
  bool get parent => widget.path == '/parent-access';
  String get title => recovery
      ? 'Get Back Into Your Account'
      : parent
      ? 'Stay Close to Their Learning'
      : 'Let\'s Talk';

  @override
  void dispose() {
    for (final controller in [name, phone, email, message]) {
      controller.dispose();
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
      await widget.api.request(
        '/api/public/inquiries',
        method: 'POST',
        body: {
          'inquiryType': parent || recovery ? 'PARENT_SUPPORT' : 'GENERAL',
          'fullName': name.text.trim(),
          'phone': phone.text.trim(),
          'email': email.text.trim(),
          'subject': recovery
              ? 'Help signing in'
              : parent
              ? 'Parent account access'
              : 'Contact the foundation',
          'message': recovery
              ? 'Please help me regain access to my account. ${message.text.trim()}'
              : parent
              ? 'Please help me access my child\'s account. ${message.text.trim()}'
              : message.text.trim(),
          'preferredContact': 'phone',
          'sourcePage': recovery
              ? 'forgot-password'
              : parent
              ? 'parent-access'
              : 'contact',
        },
      );
      if (mounted) setState(() => sent = true);
    } on ApiException catch (exception) {
      if (mounted) {
        setState(
          () => error = switch (exception.statusCode) {
            0 => 'We could not reach the office. Please try again.',
            429 => 'Please wait a moment before trying again.',
            _ => 'We could not send your message. Please try again later.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    onNavigate: widget.onNavigate,
    mobileTitle: recovery
        ? 'Sign-in help'
        : parent
        ? 'Parent access'
        : 'Contact office',
    child: sent
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: publicGold,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'We Have Your Message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: publicInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Our office will contact you using the details you shared.',
                textAlign: TextAlign.center,
                style: TextStyle(color: publicMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              GoldAction(
                label: 'Back to Login',
                onPressed: () => widget.onNavigate('/login'),
              ),
            ],
          )
        : Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    color: publicInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recovery
                      ? 'Share your account details. Our office will help you sign in again.'
                      : parent
                      ? 'Our office will help link your account to your child.'
                      : 'Tell us how we can help you or your school.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: publicMuted, height: 1.5),
                ),
                const SizedBox(height: 26),
                LabeledField(
                  label: 'Full name',
                  child: TextFormField(
                    key: const ValueKey('help-name'),
                    controller: name,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      hintText: 'Your full name',
                    ),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Enter your full name.'
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Phone number',
                  child: TextFormField(
                    key: const ValueKey('help-phone'),
                    controller: phone,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'Your phone number',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().length < 8 ||
                            value!.trim().length > 30
                        ? 'Enter a valid phone number.'
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Email address (optional)',
                  child: TextFormField(
                    key: const ValueKey('help-email'),
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      hintText: 'you@example.com',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isNotEmpty &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(value!.trim())
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: parent
                      ? 'Child\'s name or registration number'
                      : recovery
                      ? 'Anything else? (optional)'
                      : 'Your message',
                  child: TextFormField(
                    key: const ValueKey('help-message'),
                    controller: message,
                    enabled: !busy,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      hintText: 'Tell us a little more',
                    ),
                    validator: (value) =>
                        !recovery &&
                            (value ?? '').trim().length < (parent ? 2 : 10)
                        ? 'Please add a little more detail.'
                        : null,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  FormNotice(error!),
                ],
                const SizedBox(height: 20),
                GoldAction(
                  label: 'Send Message',
                  busy: busy,
                  onPressed: submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => widget.onNavigate('/login'),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
  );
}
