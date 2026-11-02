import 'dart:math';
import 'package:flutter/material.dart';
import 'platform_backups_page.dart';
import 'design_tokens.dart';
import 'it_workspace_visuals.dart';
import 'platform_form_dialog.dart';

class PlatformBackupRequests extends StatefulWidget {
  const PlatformBackupRequests({
    super.key,
    required this.request,
    required this.onAudit,
    this.showForm = showPlatformForm,
  });
  final PlatformFormPresenter showForm;
  final Future<dynamic> Function(String, Map<String, dynamic>?) request;
  final VoidCallback onAudit;
  @override
  State<PlatformBackupRequests> createState() => _PlatformBackupRequestsState();
}

class _PlatformBackupRequestsState extends State<PlatformBackupRequests> {
  List<dynamic> items = [];
  int page = 1, total = 0;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.request('/backups/requests?page=$page', null);
      if (mounted) {
        setState(() {
          items = data['items'] as List;
          total = data['total'] as int;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load restore requests. Try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final request = widget.request;
    final snapshot = TextEditingController();
    final reason = TextEditingController();
    final key = GlobalKey<FormState>();
    final random = Random.secure();
    final requestId = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    var saving = false;
    Map<String, dynamic>? submitted;
    String? failure;
    final saved = await widget.showForm(
      context,
      (context) => StatefulBuilder(
        builder: (context, change) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Request an isolated restore test'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'This records a request only. No restore is executed. Do not include passwords, storage URLs or learner records.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: snapshot,
                        enabled: !saving && submitted == null,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Snapshot reference',
                          hintText:
                              'Reference supplied by your backup operator',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 3
                            ? 'Enter a snapshot reference'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reason,
                        enabled: !saving && submitted == null,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Reason and test scope',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 10
                            ? 'Describe the reason and scope'
                            : null,
                      ),
                      if (failure != null)
                        Text(
                          failure!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (submitted == null && !key.currentState!.validate())
                          return;
                        change(() {
                          submitted ??= Map<String, dynamic>.unmodifiable({
                            'requestId': requestId,
                            'snapshot': snapshot.text.trim(),
                            'reason': reason.text.trim(),
                          });
                          saving = true;
                          failure = null;
                        });
                        try {
                          await request('/backups/requests', submitted!);
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (_) {
                          if (context.mounted) {
                            change(() {
                              saving = false;
                              failure =
                                  'Save could not be confirmed. Your details are retained and locked. Retry to confirm the same request. Before creating a different request, cancel and check request history.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Record request'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    snapshot.dispose();
    reason.dispose();
    if (saved == true && mounted) {
      page = 1;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request recorded. No restore has been executed.'),
        ),
      );
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => PlatformBackupsPage(
    onAudit: widget.onAudit,
    onRequest: create,
    requests: Container(
      decoration: AfaqDesign.panelDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Restore test requests',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recorded requests, not completed tests. A backup operator must review and execute an isolated test separately.',
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (!loading && error == null && items.isEmpty)
            const Text('No restore tests requested yet.'),
          for (final item in items) ...[
            const Divider(height: 28),
            ItRecordDetails(
              values: {
                'Snapshot reference': '${item['metadata']['snapshot']}',
                'Status': 'Requested - not executed',
                'Requested (UTC)': itTimestamp(item['createdAt']),
                'Reason and scope': '${item['metadata']['reason']}',
              },
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Page $page / ${max(1, (total / 20).ceil())}'),
              TextButton(
                onPressed: loading || page == 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: loading || page * 20 >= total
                    ? null
                    : () {
                        page++;
                        load();
                      },
                child: const Text('Next'),
              ),
              TextButton(
                onPressed: loading ? null : load,
                child: const Text('Check requests'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
