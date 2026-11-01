import 'package:flutter/material.dart';
import 'api_client.dart';
import 'design_tokens.dart';
import 'sms_status.dart';
import 'sms_estimate.dart';

class DonorMessagingWorkspace extends StatefulWidget {
  const DonorMessagingWorkspace({
    super.key,
    required this.load,
    required this.onSessionExpired,
    this.post,
  });
  final Future<dynamic> Function(String) load;
  final Future<dynamic> Function(String, Map<String, dynamic>)? post;
  final VoidCallback onSessionExpired;
  @override
  State<DonorMessagingWorkspace> createState() => _MessagingState();
}

class _MessagingState extends State<DonorMessagingWorkspace> {
  Widget estimatePanel(String body, int recipients) {
    final estimate = estimateSms(body, recipients);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sending estimate',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('$recipients recipients'),
              Text('${estimate.parts} SMS parts per recipient'),
              Text('${estimate.credits} estimated credits'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${estimate.unicode ? 'Unicode' : 'GSM-7'} encoding. Estimate at 1 credit per SMS part per recipient (RodSMS). Provider calculation is final; this is not a balance check.',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          if (body.contains('{'))
            const Text(
              'Personalized placeholders may change the final SMS length and credits.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String statusLabel(dynamic status) => switch (status) {
    'DRAFT' => 'Draft',
    'PENDING' => 'Queued',
    'SENDING' => 'Sending',
    'ACCEPTED' => 'Accepted by SMS provider',
    'FAILED' => 'Sending failed',
    'SKIPPED' => 'Skipped',
    _ => 'Sending unconfirmed',
  };
  String displayDate(dynamic raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return 'Time unavailable';
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatShortDate(date)} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  final message = TextEditingController(), search = TextEditingController();
  final selected = <String, Map>{};
  List donors = [], records = [];
  String tab = 'Compose';
  String consentFilter = 'all';
  String? draftId, error;
  int revision = 1, donorPage = 1, historyPage = 1;
  bool reviewing = false;
  bool busy = false,
      initialized = false,
      ready = false,
      moreDonors = false,
      moreHistory = false;
  @override
  void dispose() {
    message.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) widget.onSessionExpired();
      error = e is ApiException && e.statusCode == 409
          ? 'The draft or recipient details changed. Reload and review them again.'
          : e is ApiException && e.statusCode == 503
          ? 'Sending is unavailable. Your saved draft is kept.'
          : 'The request could not be completed. Refresh to check its status before trying again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadDonors() async {
    final result =
        await widget.load(
              '/funds/messaging/recipients?q=${Uri.encodeQueryComponent(search.text.trim())}&page=$donorPage&consent=$consentFilter',
            )
            as Map;
    if (!mounted) return;
    donors = result['items'] as List;
    moreDonors = result['hasMore'] == true;
  }

  Future<void> loadHistory() async {
    final result =
        await widget.load(
              '/funds/messaging?tab=${tab == 'Sent messages' ? 'sent' : 'drafts'}&page=$historyPage',
            )
            as Map;
    if (!mounted) return;
    records = result['items'] as List;
    moreHistory = result['hasMore'] == true;
    ready = result['ready'] == true;
  }

  Future<Map> save() async {
    final result =
        await widget.post!('/funds/messaging/drafts', {
              if (draftId != null) 'id': draftId,
              if (draftId != null) 'revision': revision,
              'body': message.text.trim(),
              'donorIds': selected.keys.toList(),
            })
            as Map;
    if (mounted) {
      draftId = result['id'] as String;
      revision = result['revision'] as int;
    }
    return result;
  }

  Future<void> review() => run(() async {
    final draft = await save();
    if (!mounted) return;
    final recipients = draft['recipients'] as List;
    setState(() => reviewing = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review message'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                estimatePanel('${draft['body']}', recipients.length),
                const SizedBox(height: 16),
                SelectableText('${draft['body']}'),
                const Divider(height: 32),
                for (final recipient in recipients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${recipient['donorName']}\n${recipient['phone']} · ${recipient['madrasaName']}',
                    ),
                  ),
                if (!ready)
                  const Text(
                    'Connect an SMS provider to send. This draft has been saved.',
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back to draft'),
          ),
          FilledButton.icon(
            onPressed: ready && recipients.isNotEmpty
                ? () => Navigator.pop(context, true)
                : null,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Confirm send'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => reviewing = false);
    if (confirmed != true) return;
    await widget.post!('/funds/messaging/${draft['id']}/send', {
      'revision': draft['revision'],
    });
    if (!mounted) return;
    message.clear();
    selected.clear();
    draftId = null;
    tab = 'Sent messages';
    historyPage = 1;
    await loadHistory();
  });
  Future<void> consent(Map donor) async {
    final note = TextEditingController();
    final optIn = donor['consent'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(optIn ? 'Record donor consent' : 'Withdraw SMS consent'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                optIn
                    ? 'Record this only after ${donor['name']} has agreed to receive donation messages. Selecting a donor is not consent.'
                    : 'Stop future manual messages to ${donor['name']}. Messages already accepted by the SMS provider cannot be recalled.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Consent source / reason',
                  hintText: 'How and when the donor agreed or withdrew',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (note.text.trim().length >= 5) Navigator.pop(context, true);
            },
            child: const Text('Save consent'),
          ),
        ],
      ),
    );
    final reason = note.text.trim();
    note.dispose();
    if (confirmed != true || !mounted) return;
    await run(() async {
      await widget.post!('/funds/messaging/recipients/${donor['id']}/consent', {
        'optedIn': optIn,
        'note': reason,
      });
      if (!optIn) selected.remove('${donor['id']}');
      await loadDonors();
    });
  }

  Widget box(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xfff7f9fb),
      border: Border.all(color: const Color(0xffe3e9ed)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
  Widget title(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18,
      color: AfaqDesign.ink,
    ),
  );
  Future<void> openDraft(Map draft) async {
    if (message.text.isNotEmpty || selected.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current editor?'),
          content: const Text('Unsaved edits will be replaced by this draft.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open draft'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() {
      draftId = '${draft['id']}';
      revision = draft['revision'] as int;
      message.text = '${draft['body']}';
      selected.clear();
      for (final r in draft['recipients'] as List) {
        selected['${r['donorId']}'] = {
          'name': r['donorName'],
          'phone': r['phone'],
          'madrasa': r['madrasaName'],
        };
      }
      tab = 'Compose';
    });
  }

  Future<void> newMessage() async {
    if (message.text.isNotEmpty || selected.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new message?'),
          content: const Text(
            'Saved drafts are kept. Unsaved changes in this editor will be discarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      draftId = null;
      revision = 1;
      message.clear();
      selected.clear();
      tab = 'Compose';
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xffe1e7eb)),
    ),
    child: ExpansionTile(
      title: title('Donor messages'),
      subtitle: const Text(
        'Write, choose recipients and review before sending',
      ),
      leading: const Icon(Icons.sms_outlined),
      childrenPadding: const EdgeInsets.all(20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      onExpansionChanged: (open) {
        if (open && !initialized) {
          run(() async {
            await loadHistory();
            await loadDonors();
            initialized = true;
          });
        }
      },
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in ['Compose', 'Sent messages', 'Drafts'])
              ChoiceChip(
                label: Text(name),
                selected: tab == name,
                onSelected: busy
                    ? null
                    : (_) => run(() async {
                        tab = name;
                        historyPage = 1;
                        records = [];
                        await loadHistory();
                      }),
              ),
            if (initialized)
              OutlinedButton.icon(
                onPressed: busy ? null : newMessage,
                icon: const Icon(Icons.add),
                label: const Text('New message'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (busy && !reviewing) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xffa33c35)),
            ),
          ),
        if (!initialized && !busy)
          TextButton(
            onPressed: () => run(() async {
              await loadHistory();
              await loadDonors();
              initialized = true;
            }),
            child: const Text('Retry loading messages'),
          ),
        if (initialized && tab == 'Compose') ...[
          LayoutBuilder(
            builder: (context, bounds) {
              final composer = box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title('1. Write your message'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: message,
                      enabled: !busy,
                      maxLines: 7,
                      maxLength: 1000,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Write the message donors will receive',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    estimatePanel(message.text, selected.length),
                    const SizedBox(height: 16),
                    title('${selected.length} selected'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in selected.entries)
                          InputChip(
                            label: Text('${entry.value['name']}'),
                            onDeleted: busy
                                ? null
                                : () => setState(
                                    () => selected.remove(entry.key),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              busy ||
                                  widget.post == null ||
                                  message.text.trim().isEmpty
                              ? null
                              : () => run(() async {
                                  await save();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Draft saved.'),
                                      ),
                                    );
                                  }
                                }),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save draft'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              busy ||
                                  widget.post == null ||
                                  message.text.trim().isEmpty ||
                                  selected.isEmpty
                              ? null
                              : review,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Review & send'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              final recipients = box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title('2. Choose donors'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in const {
                          'all': 'All donors',
                          'granted': 'SMS consent given',
                          'missing': 'Consent needed',
                        }.entries)
                          ChoiceChip(
                            label: Text(option.value),
                            selected: consentFilter == option.key,
                            onSelected: busy
                                ? null
                                : (_) => run(() async {
                                    consentFilter = option.key;
                                    donorPage = 1;
                                    await loadDonors();
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Filters do not clear selected donors. A valid phone and consent are required to select a recipient.',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: search,
                      enabled: !busy,
                      onSubmitted: (_) => run(() async {
                        donorPage = 1;
                        await loadDonors();
                      }),
                      decoration: InputDecoration(
                        labelText: 'Search donor or madrasa',
                        suffixIcon: IconButton(
                          tooltip: 'Search donors',
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  donorPage = 1;
                                  await loadDonors();
                                }),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (donors.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No donors found.'),
                      ),
                    for (final donor in donors)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selected.containsKey('${donor['id']}'),
                            onChanged:
                                busy ||
                                    donor['phone'] == null ||
                                    donor['consent'] != true ||
                                    selected.length >= 100 &&
                                        !selected.containsKey('${donor['id']}')
                                ? null
                                : (value) => setState(() {
                                    if (value == true) {
                                      selected['${donor['id']}'] = donor as Map;
                                    } else {
                                      selected.remove('${donor['id']}');
                                    }
                                  }),
                            title: Text('${donor['name']}'),
                            subtitle: Text(
                              '${donor['phone'] ?? 'Valid phone required'}\n${donor['madrasa']}',
                            ),
                            isThreeLine: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy || widget.post == null
                                  ? null
                                  : () => consent(donor as Map),
                              child: Text(
                                donor['consent'] == true
                                    ? 'Withdraw consent'
                                    : 'Record consent',
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Previous donors',
                          onPressed: busy || donorPage == 1
                              ? null
                              : () => run(() async {
                                  donorPage--;
                                  await loadDonors();
                                }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $donorPage'),
                        IconButton(
                          tooltip: 'Next donors',
                          onPressed: busy || !moreDonors
                              ? null
                              : () => run(() async {
                                  donorPage++;
                                  await loadDonors();
                                }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              return bounds.maxWidth < 850
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        composer,
                        const SizedBox(height: 16),
                        recipients,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: composer),
                        const SizedBox(width: 20),
                        Expanded(child: recipients),
                      ],
                    );
            },
          ),
        ],
        if (initialized && tab != 'Compose') ...[
          Text(
            tab == 'Drafts'
                ? 'Your saved drafts'
                : 'Your sent and queued messages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty && !busy) const Text('No messages here yet.'),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${record['senderName']} · ${displayDate(record['queuedAt'] ?? record['updatedAt'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText('${record['body']}'),
                    const Divider(height: 28),
                    for (final recipient in record['recipients'] as List)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipient['donorName']} · ${recipient['phone']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text('${recipient['madrasaName']}'),
                            const SizedBox(height: 6),
                            Chip(
                              avatar: Icon(
                                recipient['status'] == 'ACCEPTED'
                                    ? Icons.cloud_done_outlined
                                    : recipient['status'] == 'FAILED' ||
                                          recipient['status'] == 'UNKNOWN'
                                    ? Icons.info_outline
                                    : Icons.schedule,
                                size: 18,
                              ),
                              label: Text(statusLabel(recipient['status'])),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (smsFailureGuidance(recipient['reason'])
                                case final String guidance)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  guidance,
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (recipient['batchId'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SelectableText(
                                  'Provider reference: ${recipient['batchId']}',
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (tab == 'Drafts')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => openDraft(record as Map),
                          child: const Text('Open draft'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Text(
            'ACCEPTED means queued by the SMS provider, not confirmed delivery to the phone.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous messages',
                onPressed: busy || historyPage == 1
                    ? null
                    : () => run(() async {
                        historyPage--;
                        await loadHistory();
                      }),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton(
                onPressed: busy ? null : () => run(loadHistory),
                child: const Text('Refresh messages'),
              ),
              IconButton(
                tooltip: 'Next messages',
                onPressed: busy || !moreHistory
                    ? null
                    : () => run(() async {
                        historyPage++;
                        await loadHistory();
                      }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
