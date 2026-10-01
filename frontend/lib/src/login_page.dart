import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'public_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.state,
    required this.onNavigate,
    required this.onSignedIn,
  });
  final AppState state;
  final PublicNavigate onNavigate;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  bool revealPassword = false;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.state.busy || !formKey.currentState!.validate()) return;
    final success = await widget.state.signIn(
      loginController.text,
      passwordController.text,
    );
    if (success && mounted) {
      TextInput.finishAutofillContext();
      widget.onSignedIn();
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    onNavigate: widget.onNavigate,
    mobileTitle: 'Sign in',
    child: AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: publicInk,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Login to your account',
              textAlign: TextAlign.center,
              style: TextStyle(color: publicMuted, fontSize: 14),
            ),
            const SizedBox(height: 34),
            LabeledField(
              label: 'Phone number or email',
              child: TextFormField(
                key: const ValueKey('login-identifier'),
                controller: loginController,
                autofillHints: const [AutofillHints.username],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Your phone number or email',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? 'Enter your phone number or email.'
                    : null,
              ),
            ),
            const SizedBox(height: 22),
            LabeledField(
              label: 'Password',
              child: TextFormField(
                key: const ValueKey('login-password'),
                controller: passwordController,
                autofillHints: const [AutofillHints.password],
                obscureText: !revealPassword,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: revealPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => revealPassword = !revealPassword),
                    icon: Icon(
                      revealPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Enter your password.' : null,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.state.busy
                    ? null
                    : () => widget.onNavigate('/forgot-password'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1761AB),
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            if (widget.state.error != null) ...[
              FormNotice(widget.state.error!),
              const SizedBox(height: 18),
            ],
            const SizedBox(height: 12),
            GoldAction(
              label: 'Login',
              busy: widget.state.busy,
              onPressed: submit,
            ),
            const SizedBox(height: 25),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(color: publicMuted, fontSize: 13),
                ),
                TextButton(
                  onPressed: widget.state.busy
                      ? null
                      : () => widget.onNavigate('/register'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1761AB),
                  ),
                  child: const Text(
                    'Register here',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
