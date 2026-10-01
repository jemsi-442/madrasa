import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'public_shell.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.state,
    required this.onNavigate,
    required this.onRegistered,
  });

  final AppState state;
  final PublicNavigate onNavigate;
  final VoidCallback onRegistered;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool revealPassword = false;
  bool revealConfirmation = false;

  @override
  void dispose() {
    for (final controller in [name, email, password, confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.state.busy || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await widget.state.register(
      fullName: name.text,
      email: email.text,
      password: password.text,
      confirmPassword: confirmation.text,
    );
    if (!mounted || !success) return;
    TextInput.finishAutofillContext();
    widget.onRegistered();
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    onNavigate: widget.onNavigate,
    registration: true,
    mobileTitle: 'Create account',
    child: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create Your Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: publicInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your next chapter of learning starts here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: publicMuted, fontSize: 14),
              ),
              const SizedBox(height: 30),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    LabeledField(
                      label: 'Full name',
                      child: TextFormField(
                        key: const ValueKey('register-name'),
                        controller: name,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        enabled: !widget.state.busy,
                        decoration: const InputDecoration(
                          hintText: 'Your full name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 19,
                          ),
                        ),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter your full name.'
                            : value!.trim().length > 150
                            ? 'Use no more than 150 characters.'
                            : null,
                      ),
                    ),
                    LabeledField(
                      label: 'Email address',
                      child: TextFormField(
                        key: const ValueKey('register-email'),
                        controller: email,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        enabled: !widget.state.busy,
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            size: 19,
                          ),
                        ),
                        validator: (value) =>
                            !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch((value ?? '').trim()) ||
                                (value ?? '').trim().length > 150
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                    ),
                    LabeledField(
                      label: 'Password',
                      child: TextFormField(
                        key: const ValueKey('register-password'),
                        controller: password,
                        autofillHints: const [AutofillHints.newPassword],
                        obscureText: !revealPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        enabled: !widget.state.busy,
                        decoration: InputDecoration(
                          hintText: 'At least 8 characters',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 19,
                          ),
                          suffixIcon: IconButton(
                            tooltip: revealPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(
                              () => revealPassword = !revealPassword,
                            ),
                            icon: Icon(
                              revealPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                        validator: (value) => (value ?? '').length < 8
                            ? 'Use at least 8 characters.'
                            : utf8.encode(value!).length > 72
                            ? 'Please use a shorter password.'
                            : null,
                      ),
                    ),
                    LabeledField(
                      label: 'Confirm password',
                      child: TextFormField(
                        key: const ValueKey('register-confirmation'),
                        controller: confirmation,
                        autofillHints: const [AutofillHints.newPassword],
                        obscureText: !revealConfirmation,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        enabled: !widget.state.busy,
                        onFieldSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          hintText: 'Repeat your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 19,
                          ),
                          suffixIcon: IconButton(
                            tooltip: revealConfirmation
                                ? 'Hide confirmation'
                                : 'Show confirmation',
                            onPressed: () => setState(
                              () => revealConfirmation = !revealConfirmation,
                            ),
                            icon: Icon(
                              revealConfirmation
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value ?? '').isEmpty || value != password.text
                            ? 'Passwords must match.'
                            : null,
                      ),
                    ),
                  ];
                  if (constraints.maxWidth < 530) {
                    return Column(
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          if (i > 0) const SizedBox(height: 18),
                          fields[i],
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 18),
                          Expanded(child: fields[1]),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[2]),
                          const SizedBox(width: 18),
                          Expanded(child: fields[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Icon(Icons.school_outlined, size: 20, color: publicGold),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'An account for your online courses.',
                      style: TextStyle(fontSize: 13, color: publicMuted),
                    ),
                  ),
                ],
              ),
              if (widget.state.error != null) ...[
                const SizedBox(height: 18),
                FormNotice(widget.state.error!),
              ],
              const SizedBox(height: 24),
              GoldAction(
                label: 'Create Account',
                onPressed: submit,
                busy: widget.state.busy,
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(fontSize: 13, color: publicInk),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate('/login'),
                    child: const Text('Login here'),
                  ),
                ],
              ),
              const Divider(color: publicBorder, height: 24),
              TextButton(
                onPressed: () => widget.onNavigate('/parent-access'),
                child: const Text(
                  'Looking for your child\'s account?',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
