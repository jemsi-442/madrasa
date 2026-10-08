import 'package:flutter/material.dart';

class RefreshableOnboardingProgress extends StatefulWidget {
  const RefreshableOnboardingProgress({
    super.key,
    required this.initialData,
    required this.load,
    required this.sessionIsCurrent,
  });

  final Map<String, dynamic> initialData;
  final Future<Map<String, dynamic>> Function() load;
  final bool Function() sessionIsCurrent;

  @override
  State<RefreshableOnboardingProgress> createState() =>
      _RefreshableOnboardingProgressState();
}

class _RefreshableOnboardingProgressState
    extends State<RefreshableOnboardingProgress> {
  Map<String, dynamic>? data;
  bool busy = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    data = widget.initialData;
  }

  Future<void> refresh() async {
    if (busy || !widget.sessionIsCurrent()) return;
    setState(() {
      busy = true;
      failed = false;
      data = null;
    });
    try {
      final result = await widget.load();
      if (mounted && widget.sessionIsCurrent()) {
        setState(() => data = result);
      }
    } catch (_) {
      if (mounted && widget.sessionIsCurrent()) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionIsCurrent()) {
      return const Text(
        'Session changed or expired. Close this window and sign in again.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh progress'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (failed)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Progress could not be refreshed. Previous information has been hidden. Use Refresh progress to try again; no onboarding state was changed.',
            ),
          ),
        if (data != null) PlatformOnboardingProgress(data: data!),
      ],
    );
  }
}

class PlatformOnboardingProgress extends StatelessWidget {
  const PlatformOnboardingProgress({super.key, required this.data});
  final Map<String, dynamic> data;

  String timestamp(dynamic value) => value is String
      ? DateTime.tryParse(value)?.toUtc().toIso8601String() ?? 'Not recorded'
      : 'Not recorded';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${data['schoolName']} / ${data['requestedCode']}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Text(switch (data['stage']) {
        'PROVISIONING_PENDING' => 'Next: IT must create the inactive madrassa.',
        'INVITATION_PENDING' =>
          'Waiting for an admin invitation. Email delivery is not connected yet.',
        'INVITATION_EXPIRED' =>
          'The invitation expired before acceptance. A replacement is needed through the approved delivery workflow.',
        'ACCEPTANCE_PENDING' =>
          'Waiting for admin acceptance. An invitation record does not confirm email delivery.',
        'ACTIVATION_REVIEW_PENDING' =>
          data['nextResponsibility'] == 'OFFICE_APPROVAL'
              ? 'Preparation is complete. Waiting for independent office approval. Activation is not available in this screen.'
              : 'Acceptance recorded. Waiting for IT to complete preparation before office approval.',
        'ACTIVE' =>
          'Activation is recorded and the first administrator is active.',
        _ =>
          'Review required: the current school or account state needs investigation. Do not bypass onboarding checks.',
      }),
      const SizedBox(height: 16),
      for (final step in (data['steps'] as List? ?? []))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                step['completed'] == true
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: step['completed'] == true
                    ? const Color(0xff278258)
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${step['label']}'),
                    Text(
                      step['completed'] == true
                          ? timestamp(step['at'])
                          : 'Pending',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (data['invitationExpiresAt'] != null)
        Text(
          'Invitation expiry (UTC): ${timestamp(data['invitationExpiresAt'])}',
        ),
      const SizedBox(height: 12),
      if (data['activationReview'] is Map) ...[
        const Divider(),
        Text(
          'IT technical readiness',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(switch (data['activationReview']['signOffStatus']) {
          'CURRENT' =>
            'IT sign-off is current for this snapshot. Office approval is still required.',
          'EXPIRED' =>
            'IT sign-off is expired or its timestamp cannot be verified. A new review is required.',
          'STATE_CHANGED' =>
            'Onboarding changed after IT sign-off. Review the current state again.',
          'OPERATOR_UNAVAILABLE' =>
            'The IT signer is no longer authorized. An authorized IT operator must review again.',
          'MISSING' => 'No IT sign-off has been recorded.',
          _ => 'IT sign-off cannot be confirmed at this stage.',
        }),
        const SizedBox(height: 8),
        Text(
          data['activationReview']['prerequisitesPassed'] == true
              ? data['activationReview']['signOffStatus'] == 'CURRENT'
                    ? 'IT has recorded a manual evidence review. This is not an automated security certification.'
                    : 'Recorded prerequisites pass. Manual evidence review is still required.'
              : 'Activation prerequisites are not met. Resolve the items below before proceeding.',
        ),
        const SizedBox(height: 12),
        for (final check in (data['activationReview']['checks'] as List? ?? []))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  check['passed'] == true
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: check['passed'] == true
                      ? const Color(0xff278258)
                      : const Color(0xff996515),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${check['label']}: ${check['passed'] == true ? 'Pass' : 'Not met'}',
                  ),
                ),
              ],
            ),
          ),
        if (data['activationReview']['signOffStatus'] != 'CURRENT') ...[
          const Text(
            'Manual evidence still needed (not automatically verified):',
          ),
          for (final review
              in (data['activationReview']['manualReviews'] as List? ?? []))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('$review: review required'),
            ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Activation is not available here. Email delivery and the live invitation acceptance workflow are not connected. Passing these checks does not grant school access.',
        ),
        const Divider(),
      ],
      const Text(
        'This is a read-only snapshot, not permission to activate a school. No invitation token or administrator credentials are displayed.',
      ),
      const SizedBox(height: 8),
      Text('Checked (UTC): ${timestamp(data['checkedAt'])}'),
    ],
  );
}
