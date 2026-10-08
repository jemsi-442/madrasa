import 'dart:async';

import 'package:flutter/material.dart';

class RefreshableOnboardingProgress extends StatefulWidget {
  const RefreshableOnboardingProgress({
    super.key,
    required this.initialData,
    required this.load,
    required this.sessionIsCurrent,
    this.now,
  });

  final Map<String, dynamic> initialData;
  final Future<Map<String, dynamic>> Function() load;
  final bool Function() sessionIsCurrent;
  final DateTime Function()? now;

  @override
  State<RefreshableOnboardingProgress> createState() =>
      _RefreshableOnboardingProgressState();
}

class _RefreshableOnboardingProgressState
    extends State<RefreshableOnboardingProgress> {
  Map<String, dynamic>? data;
  bool busy = false;
  bool failed = false;
  Timer? freshnessTimer;

  bool get snapshotIsCurrent {
    final value = data?['checkedAt'];
    final checkedAt = value is String ? DateTime.tryParse(value) : null;
    if (checkedAt == null) return false;
    final age = (widget.now?.call() ?? DateTime.now()).difference(checkedAt);
    return !age.isNegative && age < const Duration(minutes: 1);
  }

  @override
  void initState() {
    super.initState();
    data = widget.initialData;
    freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    freshnessTimer?.cancel();
    super.dispose();
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
        if (data != null)
          if (snapshotIsCurrent)
            PlatformOnboardingProgress(data: data!)
          else
            Semantics(
              liveRegion: true,
              child: const Text(
                'Progress is outdated or its check time cannot be verified. Use Refresh progress to check the current handoff. No onboarding state was changed.',
              ),
            ),
      ],
    );
  }
}

class PlatformOnboardingProgress extends StatelessWidget {
  const PlatformOnboardingProgress({super.key, required this.data});
  final Map<String, dynamic> data;

  String get responsibleNext => switch (data['stage']) {
    'PROVISIONING_PENDING' => 'IT team',
    'INVITATION_PENDING' || 'INVITATION_EXPIRED' => 'IT team',
    'ACCEPTANCE_PENDING' =>
      data['deliveryConfigured'] == true
          ? 'Invited madrassa administrator'
          : 'IT team',
    'ACTIVATION_REVIEW_PENDING' =>
      data['nextResponsibility'] == 'OFFICE_APPROVAL'
          ? 'Independent office approver'
          : 'IT team',
    'ACTIVE' => 'Madrassa administrator',
    _ => 'IT team',
  };

  bool get invitationDeliveryBlocked =>
      data['deliveryConfigured'] != true &&
      const [
        'INVITATION_PENDING',
        'INVITATION_EXPIRED',
        'ACCEPTANCE_PENDING',
      ].contains(data['stage']);

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
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responsible next: $responsibleNext',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(switch (data['stage']) {
              'ACTIVE' =>
                'Onboarding is complete. The madrassa administrator manages daily school operations; IT handles technical support.',
              'ACTIVATION_REVIEW_PENDING'
                  when data['nextResponsibility'] == 'OFFICE_APPROVAL' =>
                'The original requester cannot give final approval. Office approval does not replace IT preparation.',
              'PROVISIONING_PENDING' =>
                'IT prepares the inactive school after office approval. Creating it does not enable school access.',
              'INVITATION_PENDING' ||
              'INVITATION_EXPIRED' ||
              'ACCEPTANCE_PENDING' =>
                'An invitation record is not proof of delivery. Do not ask the administrator to share a password or invitation token.',
              'ACTIVATION_REVIEW_PENDING' =>
                'Wait for IT preparation before independent office approval. School access remains disabled.',
              _ =>
                'Ask IT to investigate the current state. Office users should not attempt technical repairs or bypass approval.',
            }),
            if (invitationDeliveryBlocked) ...[
              const SizedBox(height: 8),
              const Text(
                'Delivery setup pending: email delivery is not connected. IT must complete the approved delivery workflow before asking the administrator to accept.',
              ),
            ],
          ],
        ),
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
          'WITHDRAWN' =>
            'IT sign-off was withdrawn. A new technical review is required before office approval.',
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
