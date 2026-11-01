import 'dart:async';

import 'package:flutter/material.dart';
import 'workspace_details_dialog.dart';

class RefreshableOnboardingProgress extends StatefulWidget {
  const RefreshableOnboardingProgress({
    super.key,
    required this.initialData,
    required this.load,
    required this.sessionIsCurrent,
    this.now,
    this.sendInvitation,
  });

  final Map<String, dynamic> initialData;
  final Future<Map<String, dynamic>> Function() load;
  final bool Function() sessionIsCurrent;
  final DateTime Function()? now;
  final Future<String> Function()? sendInvitation;

  @override
  State<RefreshableOnboardingProgress> createState() =>
      _RefreshableOnboardingProgressState();
}

class _RefreshableOnboardingProgressState
    extends State<RefreshableOnboardingProgress> {
  Map<String, dynamic>? data;
  bool busy = false;
  bool failed = false;
  bool confirmed = false;
  String? deliveryMessage;
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
      confirmed = false;
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

  Future<void> sendInvitation() async {
    if (busy ||
        !confirmed ||
        !snapshotIsCurrent ||
        !widget.sessionIsCurrent()) {
      return;
    }
    setState(() {
      busy = true;
      deliveryMessage = null;
    });
    try {
      final status = await widget.sendInvitation!();
      if (!mounted || !widget.sessionIsCurrent()) return;
      setState(
        () => deliveryMessage = switch (status) {
          'SMTP_ACCEPTED' =>
            'Email accepted by the mail server. Inbox delivery is not yet confirmed.',
          'REJECTED' =>
            'The mail server rejected this invitation. Check the administrator email before retrying.',
          _ =>
            'Delivery could not be confirmed. Check the inbox before resending.',
        },
      );
    } catch (_) {
      if (mounted && widget.sessionIsCurrent()) {
        setState(
          () => deliveryMessage =
              'Delivery could not be confirmed. Check email configuration and the inbox before retrying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          confirmed = false;
        });
      }
    }
    if (mounted && widget.sessionIsCurrent()) await refresh();
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
        if (deliveryMessage != null)
          Semantics(liveRegion: true, child: Text(deliveryMessage!)),
        if (data?['canSendInvitation'] == true &&
            snapshotIsCurrent &&
            widget.sendInvitation != null) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: confirmed,
            onChanged: busy
                ? null
                : (value) => setState(() => confirmed = value ?? false),
            title: const Text('Send to the approved administrator email'),
            subtitle: const Text(
              'Resending replaces the previous invitation code. Check the inbox first.',
            ),
          ),
          FilledButton.icon(
            onPressed: busy || !confirmed ? null : sendInvitation,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Send invitation email'),
          ),
          const SizedBox(height: 16),
        ],
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

  String get stageLabel => switch (data['stage']) {
    'PROVISIONING_PENDING' => 'Awaiting IT setup',
    'INVITATION_PENDING' => 'Invitation needed',
    'INVITATION_EXPIRED' => 'Invitation expired',
    'ACCEPTANCE_PENDING' => 'Awaiting administrator',
    'ACTIVATION_REVIEW_PENDING' =>
      data['nextResponsibility'] == 'OFFICE_APPROVAL'
          ? 'Awaiting office activation'
          : 'Awaiting IT review',
    'ACTIVE' => 'Active',
    _ => 'Review required',
  };

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
      WorkspaceDetailsSection(
        title: 'Madrasa onboarding',
        icon: Icons.account_balance_outlined,
        child: WorkspaceRecordDetails(
          fields: [
            ('Madrasa', '${data['schoolName']}'),
            ('Afaq code', '${data['requestedCode'] ?? 'Not recorded'}'),
            ('Current stage', stageLabel),
          ],
        ),
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
            Text('Next step', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(switch (data['stage']) {
              'ACTIVE' =>
                'Onboarding is complete. The administrator can manage daily madrasa operations.',
              'ACTIVATION_REVIEW_PENDING'
                  when data['nextResponsibility'] == 'OFFICE_APPROVAL' =>
                'Waiting for independent office approval. The original requester cannot give final approval. Activation is not available in this screen.',
              'PROVISIONING_PENDING' =>
                'IT must create the inactive madrasa. This does not enable school access.',
              'INVITATION_PENDING' =>
                'IT must send the invitation to the approved administrator email.',
              'INVITATION_EXPIRED' =>
                'IT must send a replacement invitation. The old code has expired.',
              'ACCEPTANCE_PENDING' =>
                'Waiting for admin acceptance. An invitation record does not confirm email delivery.',
              'ACTIVATION_REVIEW_PENDING' =>
                'Waiting for IT to complete preparation before office approval. School access remains disabled.',
              _ =>
                'Ask IT to investigate the current state. Do not bypass onboarding checks.',
            }),
            if (invitationDeliveryBlocked) ...[
              const SizedBox(height: 8),
              const Text(
                'Delivery setup pending: Email delivery is not connected. Configure SMTP before sending or requesting acceptance.',
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      WorkspaceDetailsSection(
        title: 'Setup checklist',
        icon: Icons.checklist_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((data['steps'] as List? ?? []).isEmpty)
              const Text(
                'Checklist unavailable. Refresh progress to check again.',
              ),
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
                          Text(
                            '${step['label']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
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
          ],
        ),
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
        Text(
          data['deliveryConfigured'] == true
              ? 'Activation is not available here. IT review and independent activation are still required after invitation acceptance.'
              : 'Activation is not available here. Email delivery and the live invitation acceptance workflow are not connected. Passing these checks does not grant school access.',
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
