import 'package:flutter/material.dart';

import 'api_client.dart';
import 'platform_onboarding_progress.dart';

class PlatformProvisioningPanel extends StatefulWidget {
  const PlatformProvisioningPanel({
    super.key,
    required this.call,
    required this.sessionIsCurrent,
  });
  final Future<dynamic> Function(String, {Map<String, dynamic>? body}) call;
  final bool Function() sessionIsCurrent;

  @override
  State<PlatformProvisioningPanel> createState() =>
      _PlatformProvisioningPanelState();
}

class _PlatformProvisioningPanelState extends State<PlatformProvisioningPanel> {
  bool busy = false;
  int page = 1;
  final searchController = TextEditingController();
  String search = '';
  String setup = '';
  List<Map<String, dynamic>> records = [];
  Map<String, dynamic>? selected;
  Map<String, dynamic>? progress;
  Map<String, dynamic>? progressRecord;
  String? message;
  bool get current => mounted && widget.sessionIsCurrent();

  @override
  void initState() {
    super.initState();
    load(1);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load(int target, {String? query, String? setupFilter}) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      records = [];
      selected = null;
      progress = null;
      progressRecord = null;
      message = null;
      page = target;
      if (query != null) search = query.trim();
      if (setupFilter != null) setup = setupFilter;
    });
    try {
      final data = await widget.call(
        '/provisioning-queue?page=$target&pageSize=20${search.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(search)}'}${setup.isEmpty ? '' : '&setup=$setup'}',
      );
      if (!current) return;
      setState(() {
        records = (data as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (_) {
      if (current) {
        setState(() {
          message =
              'Unable to load approved applications. Use Refresh to try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> viewProgress(Map<String, dynamic> record) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      message = null;
      progress = null;
      progressRecord = record;
    });
    try {
      final result = await widget.call(
        '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/onboarding-progress',
      );
      if (current) {
        setState(() {
          progress = Map<String, dynamic>.from(result as Map);
        });
      }
    } catch (_) {
      if (current) {
        setState(() {
          message =
              'Progress could not be loaded. No onboarding state was changed.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> inspect(Map<String, dynamic> record) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      selected = null;
      message = null;
    });
    try {
      final result = await widget.call(
        '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/provisioning-preflight',
      );
      if (!current) return;
      if (result['alreadyProvisioned'] == true) {
        setState(() {
          records = [];
          message =
              'This application already has a madrassa. Refresh to see its status.';
        });
      } else if (result['prerequisitesPassed'] != true) {
        setState(() {
          message =
              'Setup is blocked: independent approval or school code availability needs review. Contact Super Admin.';
        });
      } else {
        setState(() {
          selected = record;
        });
      }
    } catch (_) {
      if (current) {
        setState(() {
          message =
              'Setup checks failed. No creation request was sent. Refresh and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> provision() async {
    final record = selected;
    if (busy || !current || record == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await widget.call(
        '/tenant-applications/${Uri.encodeComponent(record['id'] as String)}/provision',
        body: {},
      );
      if (!current) return;
      setState(() {
        records = [];
        selected = null;
        message = result['created'] == true
            ? 'Inactive madrassa created. No admin invitation has been sent. Refresh to view its status.'
            : 'This application was already provisioned. No duplicate was created. Refresh to view its status.';
      });
    } catch (error) {
      if (!current) return;
      setState(() {
        selected = null;
        records = [];
        message = error is ApiException && error.statusCode < 500
            ? 'Creation could not proceed. Refresh the queue and review the application before trying again.'
            : 'We could not confirm whether the madrassa was created. Refresh the queue before trying again; do not create a new application.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => !widget.sessionIsCurrent()
      ? const Text(
          'Session changed or expired. Close this window and sign in again.',
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Approved applications only. Creation keeps the madrassa inactive. Admin invitations and activation are not available yet.',
            ),
            const SizedBox(height: 12),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(message!)),
              ),
            if (progress != null) ...[
              const SizedBox(height: 16),
              RefreshableOnboardingProgress(
                initialData: progress!,
                sessionIsCurrent: widget.sessionIsCurrent,
                load: () async => Map<String, dynamic>.from(
                  await widget.call(
                        '/tenant-applications/${Uri.encodeComponent(progressRecord!['id'] as String)}/onboarding-progress',
                      )
                      as Map,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  progress = null;
                }),
                child: const Text('Back to queue'),
              ),
            ] else if (selected != null) ...[
              const SizedBox(height: 16),
              Text(
                'Confirm inactive madrassa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${selected!['schoolName']}\nCode: ${selected!['requestedCode']}',
              ),
              const SizedBox(height: 12),
              const Text(
                'This reserves the school code and records your action in the audit trail. It does not create a school admin or grant school access.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            selected = null;
                          }),
                    child: const Text('Cancel setup'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : provision,
                    child: const Text('Create inactive madrassa'),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in const {
                    '': 'All approved',
                    'pending': 'Awaiting setup',
                    'created': 'Created madrassas',
                  }.entries)
                    ChoiceChip(
                      label: Text(filter.value),
                      selected: setup == filter.key,
                      onSelected: busy
                          ? null
                          : (_) => load(1, setupFilter: filter.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                enabled: !busy,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search madrassa name or code',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (value) => load(1, query: value),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => load(1, query: searchController.text),
                    child: const Text('Search madrassas'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            searchController.clear();
                            load(1, query: '');
                          },
                    child: const Text('Clear search'),
                  ),
                ],
              ),
              if (search.isNotEmpty) Text('Results for "$search"'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : () => load(page),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh queue'),
                ),
              ),
              if (!busy && records.isEmpty && message == null)
                Text(
                  setup.isNotEmpty
                      ? 'No approved madrassas match these filters on this page.'
                      : search.isEmpty
                      ? 'No approved applications on this page.'
                      : 'No approved madrassas match this search on this page.',
                ),
              for (final record in records)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record['schoolName']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Code: ${record['requestedCode']}'),
                        TextButton(
                          onPressed: busy ? null : () => viewProgress(record),
                          child: const Text('Onboarding progress'),
                        ),
                        if (record['organization'] != null)
                          Text(
                            'School status: ${record['organization']['status']}',
                          )
                        else
                          OutlinedButton(
                            onPressed: busy ? null : () => inspect(record),
                            child: const Text('Review setup'),
                          ),
                      ],
                    ),
                  ),
                ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: busy || page <= 1 ? null : () => load(page - 1),
                    child: const Text('Previous page'),
                  ),
                  Text('Page $page'),
                  TextButton(
                    onPressed: busy || records.length < 20 || page >= 10000
                        ? null
                        : () => load(page + 1),
                    child: const Text('Next page'),
                  ),
                ],
              ),
            ],
          ],
        );
}
