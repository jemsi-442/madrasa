import 'dart:async';

import 'package:flutter/material.dart';

import 'foundation_ui.dart';

/// Only used before a session is restored, never over an active workspace.
class AccountConnectionPage extends StatefulWidget {
  const AccountConnectionPage({
    super.key,
    required this.restoring,
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final bool restoring;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  State<AccountConnectionPage> createState() => _AccountConnectionPageState();
}

class _AccountConnectionPageState extends State<AccountConnectionPage> {
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _watchConnection();
  }

  @override
  void didUpdateWidget(AccountConnectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restoring != widget.restoring) _watchConnection();
  }

  void _watchConnection() {
    _slowTimer?.cancel();
    _slow = false;
    if (widget.restoring) {
      _slowTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _slow = true);
      });
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restoring = widget.restoring;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff4eddf), paper, Color(0xffeaf1f3)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: line),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0c092136),
                            blurRadius: 48,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandMark(),
                          const SizedBox(height: 28),
                          Container(width: 40, height: 3, color: gold),
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restoring
                                      ? 'Reconnecting to your account...'
                                      : 'Let\'s get you connected',
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  restoring
                                      ? (_slow
                                            ? 'This is taking longer than usual. Waiting for a response from the server.'
                                            : 'Checking your saved session securely.')
                                      : (widget.error ??
                                            'Please check your connection and try again.'),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (restoring)
                            if (reduceMotion)
                              const Icon(
                                Icons.hourglass_top_rounded,
                                color: gold,
                                size: 28,
                              )
                            else
                              const LinearProgressIndicator(
                                color: gold,
                                backgroundColor: Color(0xffedf0f2),
                                minHeight: 5,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(5),
                                ),
                                semanticsLabel: 'Connecting to your account',
                              )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: widget.onRetry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try again'),
                                ),
                                OutlinedButton(
                                  onPressed: widget.onSignOut,
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Your saved work stays in your account.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
