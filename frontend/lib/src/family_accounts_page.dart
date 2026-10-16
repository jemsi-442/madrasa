import 'package:flutter/material.dart';
import 'workspace_form_dialog.dart';
import 'workspace_details_dialog.dart';
import 'package:flutter/services.dart';

import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'family_applications_panel.dart';

class FamilyAccountsPage extends StatefulWidget {
  const FamilyAccountsPage({
    super.key,
    required this.load,
    required this.submit,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final int refreshToken;

  @override
  State<FamilyAccountsPage> createState() => _FamilyAccountsPageState();
}

class _FamilyAccountsPageState extends State<FamilyAccountsPage> {
  late Future<dynamic> future = fetch();
  final issued = <String, String>{};
  String search = '';
  String stage = 'All';
  static const stages = [
    'All',
    'Needs guardian',
    'Awaiting number',
    'Number issued',
    'Disabled',
  ];
  String? familyNumber(Map<String, dynamic> row) {
    final value = issued['${row['id']}'] ?? row['familyLoginId'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String familyStage(Map<String, dynamic> row) {
    if (row['status'] != 'ACTIVE') return 'Disabled';
    if (recordMap(row['guardianProfile']).isEmpty) return 'Needs guardian';
    return familyNumber(row) == null ? 'Awaiting number' : 'Number issued';
  }

  bool creating = false;
  bool applications = false;
  Future<void> resetPassword(Map<String, dynamic> account) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => WorkspaceDetailsDialog(
        title: 'Verify the family first',
        icon: Icons.verified_user_outlined,
        fields: [('Family account', '${account['fullName']}')],
        sections: [
          (
            'Identity verification',
            'Confirm that the office has independently verified ${account['fullName']}. This resets the password and signs out all devices. Never rely only on a supplied name or admission number.',
          ),
        ],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Identity verified'),
          ),
        ],
      ),
    );
    if (verified != true || !mounted) return;
    final saved = await showAdminForm(
      context,
      title: 'Reset family password',
      saveLabel: 'Reset password',
      note:
          'Share the new password privately. No email is sent. The family number remains unchanged.',
      fields: const [
        AdminField('password', 'New password', kind: 'password'),
        AdminField('confirmPassword', 'Confirm new password', kind: 'password'),
      ],
      onSave: (body) async {
        if (body['password'] != body['confirmPassword']) {
          throw const FormatException('Passwords do not match');
        }
        await widget.submit(
          '/api/users/${account['id']}/reset-family-password',
          {...body, 'verified': true},
        );
      },
      errorMessage: (error) => error is FormatException
          ? 'Passwords do not match.'
          : 'Could not reset the password. Check your access and connection.',
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset. Share privately; no email has been sent.',
          ),
        ),
      );
    }
  }

  Future<dynamic> fetch() => widget.load('/api/users?role=PARENT');
  void reload() => setState(() {
    future = fetch();
  });

  @override
  void didUpdateWidget(covariant FamilyAccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = fetch();
  }

  Future<void> issue(Map<String, dynamic> account) async {
    final number = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _IssueFamilyNumber(account: account, submit: widget.submit),
    );
    if (!mounted || number == null) return;
    setState(() {
      issued['${account['id']}'] = number;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Family number issued: $number. Share it privately; no email has been sent.',
        ),
        action: SnackBarAction(
          label: 'Show issued',
          onPressed: () {
            if (mounted) {
              setState(() {
                stage = 'Number issued';
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> createAccount() async {
    if (creating) return;
    setState(() {
      creating = true;
    });
    String? createdId;
    try {
      final saved = await showAdminForm(
        context,
        title: 'Create parent account',
        saveLabel: 'Create account',
        load: widget.load,
        note:
            'Step 1 of 2: create the parent account. Find a verified guardian by name, phone, child name or admission number. Check the linked children before selecting. Share the initial password privately; no email is sent. Next, review the family and issue its sign-in number.',
        fields: const [
          AdminField(
            'guardianId',
            'Guardian',
            lookupPath: '/api/users/family-guardians',
            lookupLabel: 'contactLabel',
            lookupSubtitle: 'childrenSummary',
          ),
          AdminField('fullName', 'Account holder name'),
          AdminField('email', 'Email address', kind: 'email'),
          AdminField('password', 'Initial password', kind: 'password'),
        ],
        onSave: (body) async {
          final result = recordMap(
            await widget.submit('/api/users', {...body, 'role': 'PARENT'}),
          );
          createdId = result['id']?.toString();
        },
      );
      if (!mounted || !saved) return;
      final refreshed = fetch();
      setState(() {
        future = refreshed;
      });
      try {
        final accounts = recordList(await refreshed);
        if (!mounted) return;
        final matches = accounts.where(
          (row) =>
              row['id']?.toString() == createdId && row['role'] == 'PARENT',
        );
        if (createdId == null || matches.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Refresh the family list to continue. Do not create the account again.',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Next, issue the family number. You can also finish this later.',
            ),
          ),
        );
        await issue(matches.first);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created, but the family list could not refresh. Use Try again to reload; do not create another account.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          creating = false;
        });
      }
    }
  }

  void showSignInInstructions(String number) {
    final instructions =
        'Afaq family account\n\n'
        '1. Open the Afaq sign-in page provided by your madrasa.\n'
        '2. Enter your family number: $number\n'
        '3. Enter your existing password, or the initial password shared privately by your madrasa. The family number is not your password.\n'
        '4. Once signed in, select a child to view their records and progress.\n\n'
        'This account is shared by your family. If a child is missing or you cannot sign in, contact your madrasa administrator. Do not share your password outside your family.';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Family sign-in instructions'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: SelectableText(instructions)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => copy(
              instructions,
              successMessage:
                  'Sign-in instructions copied. Share privately; no email has been sent.',
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy instructions'),
          ),
        ],
      ),
    );
  }

  Future<void> copy(
    String number, {
    String successMessage = 'Family number copied',
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: number));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy. Select the number to copy it manually.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Family accounts'),
            selected: !applications,
            onSelected: creating
                ? null
                : (_) => setState(() => applications = false),
          ),
          ChoiceChip(
            label: const Text('Registration requests'),
            selected: applications,
            onSelected: creating
                ? null
                : (_) => setState(() => applications = true),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (applications)
        FamilyApplicationsPanel(
          load: widget.load,
          submit: widget.submit,
          onApproved: reload,
        )
      else
        accountsView(),
    ],
  );

  Widget accountsView() => PageResult(
    future: future,
    onRetry: reload,
    builder: (data) {
      final accounts = recordList(
        data,
      ).where((row) => row['role'] == 'PARENT').toList();
      final filtered = accounts
          .where(
            (row) =>
                (stage == 'All' || familyStage(row) == stage) &&
                [
                      row['fullName'],
                      row['email'],
                      row['phone'],
                      familyNumber(row),
                      recordMap(row['guardianProfile'])['fullName'],
                      for (final child in recordList(
                        recordMap(row['guardianProfile'])['children'],
                      )) ...[child['fullName'], child['admissionNo']],
                    ]
                    .whereType<String>()
                    .join(' ')
                    .toLowerCase()
                    .contains(search.toLowerCase()),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: creating ? null : createAccount,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Create parent account'),
            ),
          ),
          const SizedBox(height: 16),
          const SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelHeading(
                  'One family, one account',
                  subtitle: 'Children keep their own records and progress.',
                ),
                Text(
                  'Confirm the guardian link, issue a family number, then share it privately with the family. Their existing password stays unchanged.',
                ),
                SizedBox(height: 8),
                Text(
                  'Numbers are not sent by email automatically. This page manages existing parent accounts.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in stages)
                ChoiceChip(
                  label: Text(
                    '$label (${label == 'All' ? accounts.length : accounts.where((row) => familyStage(row) == label).length})',
                  ),
                  selected: stage == label,
                  onSelected: (_) => setState(() {
                    stage = label;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search families',
              hintText: 'Parent, child, admission or family number',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() {
              search = value.trim();
            }),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const EmptyRecords(
              'No parent accounts match. Parent accounts must first be linked to a guardian record.',
            ),
          for (final account in filtered) ...[
            SurfacePanel(
              child: Builder(
                builder: (_) {
                  final number = familyNumber(account);
                  final guardian = recordMap(account['guardianProfile']);
                  final eligible =
                      account['status'] == 'ACTIVE' && guardian.isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recordText(account['fullName']),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        familyStage(account),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recordText(
                          account['email'],
                          recordText(
                            account['phone'],
                            'No contact information',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guardian.isEmpty
                            ? 'Guardian link required'
                            : 'Guardian: ${recordText(guardian['fullName'])}',
                      ),
                      const SizedBox(height: 12),
                      _FamilyChildren(guardian: guardian),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(recordText(account['status'])),
                          if (eligible)
                            TextButton.icon(
                              onPressed: () => resetPassword(account),
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('Reset password'),
                            ),
                          if (number != null) ...[
                            SelectableText(
                              number,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => copy(number),
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy number'),
                            ),
                            if (eligible)
                              OutlinedButton.icon(
                                onPressed: () => showSignInInstructions(number),
                                icon: const Icon(Icons.help_outline),
                                label: const Text('Sign-in instructions'),
                              ),
                          ] else
                            FilledButton.icon(
                              onPressed: eligible ? () => issue(account) : null,
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Issue family number'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    },
  );
}

class _IssueFamilyNumber extends StatefulWidget {
  const _IssueFamilyNumber({required this.account, required this.submit});
  final Map<String, dynamic> account;
  final PageSubmitter submit;
  @override
  State<_IssueFamilyNumber> createState() => _IssueFamilyNumberState();
}

class _IssueFamilyNumberState extends State<_IssueFamilyNumber> {
  final form = GlobalKey<FormState>();
  final region = TextEditingController();
  bool busy = false, confirmed = false;
  String? error;
  @override
  void dispose() {
    region.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !confirmed || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = recordMap(
        await widget.submit(
          '/api/users/${widget.account['id']}/family-registration',
          {'regionCode': region.text.trim().toUpperCase()},
        ),
      );
      final number = result['familyLoginId'];
      if (number is! String || number.isEmpty) {
        throw StateError('Missing family number');
      }
      if (mounted) Navigator.pop(context, number);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not issue the number. Check your access and connection, then try again. Retrying will not create a second number.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: WorkspaceFormDialog(
      title: const Text('Issue family number'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordText(widget.account['fullName']),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'One number covers this family account, not an individual child. Issuing it does not change the password or add child access.',
                ),
                const SizedBox(height: 16),
                _FamilyChildren(
                  guardian: recordMap(widget.account['guardianProfile']),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: region,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Region code',
                    helperText: 'For example, DSM for Dar es Salaam',
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[A-Z]{2,8}$',
                      ).hasMatch((value ?? '').trim().toUpperCase())
                      ? null
                      : 'Enter 2 to 8 letters.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          confirmed = value ?? false;
                        }),
                  title: const Text(
                    'I have verified this family and its guardian link.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || !confirmed ? null : save,
          child: Text(busy ? 'Issuing...' : 'Confirm and issue'),
        ),
      ],
    ),
  );
}

class _FamilyChildren extends StatelessWidget {
  const _FamilyChildren({required this.guardian});
  final Map<String, dynamic> guardian;

  @override
  Widget build(BuildContext context) {
    final children = recordList(guardian['children']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Linked children in your scope',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (children.isEmpty)
          const Text(
            'No linked children are visible in your school or branch. Check the student guardian records before proceeding.',
          )
        else
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${recordText(child['fullName'])} - ${recordText(child['admissionNo'])}',
              ),
            ),
      ],
    );
  }
}
