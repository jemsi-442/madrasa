import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

class FamilyMessagesPage extends StatefulWidget {
  const FamilyMessagesPage({
    super.key,
    required this.load,
    required this.submit,
    required this.userId,
    this.teacherMode = false,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String userId;
  final bool teacherMode;
  final int refreshToken;
  @override
  State<FamilyMessagesPage> createState() => FamilyMessagesPageState();
}

class FamilyMessagesPageState extends State<FamilyMessagesPage> {
  static const base = '/api/family-messages';
  final composer = TextEditingController();
  final searchController = TextEditingController();
  String search = '';
  String? selectedId, before, error, readError;
  Future<dynamic>? history;
  Map<String, dynamic>? pending;
  int inboxPage = 1, inboxRefresh = 0;
  bool sending = false, opening = false;
  String? scheduledRead;

  @override
  void dispose() {
    composer.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FamilyMessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      inboxRefresh++;
      if (selectedId != null) reloadHistory();
    }
  }

  Future<bool> confirmLeave() async {
    if (sending || opening) return false;
    if (composer.text.trim().isEmpty && pending == null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this message?'),
        content: Text(
          pending == null
              ? 'Your unsent draft will be discarded.'
              : 'Delivery has not been confirmed. The message may have reached the server. Refresh this conversation before composing it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() {
        composer.clear();
        pending = null;
        error = null;
      });
    }
    return leave == true;
  }

  void reloadHistory({String? olderThan}) {
    before = olderThan;
    scheduledRead = null;
    readError = null;
    history = Future.sync(
      () => widget.load(
        '$base/conversations/$selectedId${before == null ? '' : '?before=$before'}',
      ),
    );
    // Observe immediate errors until the next frame attaches the error view.
    history!.ignore();
  }

  Future<void> selectThread(String id) async {
    if (selectedId == id || !await confirmLeave() || !mounted) return;
    setState(() {
      selectedId = id;
      error = null;
      reloadHistory();
    });
  }

  Future<void> newConversation() async {
    if (sending || opening) return;
    final pair = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _ContactPicker(load: widget.load, teacherMode: widget.teacherMode),
    );
    if (pair == null || !mounted || !await confirmLeave() || !mounted) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final result = recordMap(
        await widget.submit('$base/conversations', {
          'studentId': '${recordMap(pair['student'])['id']}',
          'contactId': '${recordMap(pair['contact'])['id']}',
        }),
      );
      if (!mounted) return;
      setState(() {
        selectedId = '${result['id']}';
        inboxRefresh++;
        reloadHistory();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This conversation could not be opened. Refresh contacts and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> send() async {
    if (sending || selectedId == null) return;
    final body = composer.text.trim();
    if (pending == null && (body.isEmpty || body.length > 2000)) {
      setState(() => error = 'Enter a message of 1 to 2,000 characters.');
      return;
    }
    // Keep exactly this payload until the server confirms, including after a lost response.
    pending ??= {'body': body, 'clientId': submissionId()};
    final id = selectedId!;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.submit('$base/conversations/$id/messages', Map.of(pending!));
      if (!mounted) return;
      setState(() {
        pending = null;
        composer.clear();
        inboxRefresh++;
        reloadHistory();
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        if (failure is ApiException && failure.statusCode == 422) {
          pending = null;
          error =
              'The message was not accepted. Check its length and try again.';
        } else {
          error =
              'Delivery not confirmed. Keep this page open and retry the same message. If access changed, contact the office.';
        }
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void acknowledgeVisible(Map<String, dynamic> result) {
    final messages = recordList(result['messages']);
    if (messages.isEmpty) return;
    final through = '${messages.last['id']}', id = '${result['id']}';
    if ((BigInt.tryParse(through) ?? BigInt.zero) <=
        (BigInt.tryParse('${result['readThrough']}') ?? BigInt.zero)) {
      return;
    }
    final key = '$id:$through';
    if (scheduledRead == key) return;
    scheduledRead = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || selectedId != id || scheduledRead != key) return;
      try {
        await widget.submit('$base/conversations/$id/read', {
          'throughId': through,
        });
        if (mounted && selectedId == id && scheduledRead == key) {
          setState(() {
            readError = null;
            inboxRefresh++;
          });
        }
      } catch (_) {
        if (mounted && selectedId == id) {
          setState(
            () => readError = 'Read status was not saved. Refresh to retry.',
          );
        }
      }
    });
  }

  Widget refreshButton() => OutlinedButton.icon(
    onPressed: sending || opening
        ? null
        : () => setState(() {
            inboxRefresh++;
            if (selectedId != null) reloadHistory();
          }),
    icon: const Icon(Icons.refresh, size: 18),
    label: const Text('Refresh messages'),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: sending || opening ? null : newConversation,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(opening ? 'Opening...' : 'New message'),
          ),
          refreshButton(),
          if (selectedId != null)
            OutlinedButton(
              onPressed: sending || opening
                  ? null
                  : () async {
                      if (await confirmLeave() && mounted) {
                        setState(() {
                          selectedId = null;
                          history = null;
                        });
                      }
                    },
              child: const Text('Close conversation'),
            ),
        ],
      ),
      const SizedBox(height: 18),
      if (error != null) ...[
        TeacherNotice(error!, warning: true),
        const SizedBox(height: 16),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 800;
          final chat = selectedId == null
              ? const SurfacePanel(
                  child: EmptyRecords(
                    'Select a conversation or start a new message.',
                  ),
                )
              : PageResult(
                  key: ValueKey('$selectedId-$before'),
                  future: history!,
                  onRetry: () => setState(() => reloadHistory()),
                  builder: (value) {
                    final result = recordMap(value);
                    acknowledgeVisible(result);
                    final conversation = chatPanel(result, narrow);
                    if (constraints.maxWidth < 1150) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          conversation,
                          const SizedBox(height: 16),
                          contextPanel(result),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: conversation),
                        const SizedBox(width: 16),
                        SizedBox(width: 245, child: contextPanel(result)),
                      ],
                    );
                  },
                );
          if (narrow) return selectedId == null ? inbox() : chat;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 270, child: inbox()),
              const SizedBox(width: 16),
              Expanded(child: chat),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      const TeacherNotice(
        'Private in-app communication only. SMS, WhatsApp and attachments are not sent here. Refresh to check for new messages; drafts are not stored offline.',
      ),
    ],
  );

  Widget inbox() => SurfacePanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelHeading('Inbox'),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search name or child...',
            prefixIcon: Icon(Icons.search),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => setState(() {
            search = value.trim();
            inboxPage = 1;
          }),
        ),
        const SizedBox(height: 16),
        TeacherData(
          load: widget.load,
          path:
              '$base/conversations?page=$inboxPage&search=${Uri.encodeQueryComponent(search)}',
          refreshToken: inboxRefresh,
          builder: (value) {
            final result = recordMap(value),
                items = recordList(result['items']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  const EmptyRecords(
                    'No conversations found. Start a message with an authorised contact.',
                  ),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selectedId == '${item['id']}'
                          ? const Color(0xFFF8F0DE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: sending || opening
                            ? null
                            : () => selectThread('${item['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      recordText(
                                        recordMap(item['contact'])['fullName'],
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                  if (recordNumber(item['unread']) > 0)
                                    TeacherTag(
                                      '${item['unread']}',
                                      color: gold,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                recordText(
                                  recordMap(item['student'])['fullName'],
                                ),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                recordText(
                                  recordMap(item['latestMessage'])['body'],
                                  'No messages yet',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                _MessagePagination(
                  page: inboxPage,
                  totalPages: recordNumber(
                    recordMap(result['meta'])['totalPages'],
                  ).toInt(),
                  onPage: (page) => setState(() => inboxPage = page),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.teacherMode
                      ? 'Only verified parents of students in your assigned classes.'
                      : 'Only your linked children and their current class teachers.',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget chatPanel(Map<String, dynamic> result, bool narrow) {
    final messages = recordList(result['messages']);
    return SurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrow)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  if (await confirmLeave() && mounted) {
                    setState(() {
                      selectedId = null;
                      history = null;
                    });
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to inbox'),
              ),
            ),
          StudentIdentity(
            recordMap(result['contact']),
            subtitle:
                '${widget.teacherMode ? 'Parent of' : 'Teacher for'} ${recordMap(result['student'])['fullName']}',
          ),
          const SizedBox(height: 16),
          const Divider(color: line),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (result['hasOlder'] == true)
                TextButton(
                  onPressed: sending
                      ? null
                      : () => setState(
                          () => reloadHistory(
                            olderThan: '${result['nextBefore']}',
                          ),
                        ),
                  child: const Text('Older messages'),
                ),
              if (before != null)
                TextButton(
                  onPressed: sending
                      ? null
                      : () => setState(() => reloadHistory()),
                  child: const Text('Latest messages'),
                ),
            ],
          ),
          SizedBox(
            height: narrow ? 370 : 460,
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start your conversation.',
                      style: TextStyle(color: muted),
                    ),
                  )
                : ListView(
                    key: ValueKey('messages-$selectedId-$before'),
                    reverse: true,
                    children: [
                      for (final message in messages.reversed)
                        messageBubble(message, result),
                    ],
                  ),
          ),
          if (readError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                readError!,
                style: const TextStyle(color: gold, fontSize: 12),
              ),
            ),
          const Divider(color: line),
          TextField(
            key: const ValueKey('message-composer'),
            controller: composer,
            readOnly: sending || pending != null,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: pending == null
                  ? 'Write a message...'
                  : 'Retry to confirm this message',
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: sending ? null : send,
              icon: Icon(
                sending ? Icons.hourglass_top : Icons.send_outlined,
                size: 18,
              ),
              label: Text(
                sending
                    ? 'Sending...'
                    : pending == null
                    ? 'Send'
                    : 'Retry send',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget messageBubble(
    Map<String, dynamic> message,
    Map<String, dynamic> conversation,
  ) {
    final mine = '${message['senderId']}' == widget.userId;
    final read =
        (BigInt.tryParse('${conversation['otherReadThrough']}') ??
            BigInt.zero) >=
        (BigInt.tryParse('${message['id']}') ?? BigInt.one);
    final time = DateTime.tryParse('${message['createdAt']}')?.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .92,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFF8F0DE) : const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                recordText(message['body']),
                style: const TextStyle(color: ink, height: 1.6),
              ),
              const SizedBox(height: 9),
              Text(
                '${mine ? 'You' : recordMap(conversation['contact'])['fullName']} | ${shortDate(message['createdAt'])}${time == null ? '' : ' ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'}${mine
                    ? read
                          ? ' | Read'
                          : ' | Sent'
                    : ''}',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget contextPanel(Map<String, dynamic> result) => SurfacePanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelHeading('Student context'),
        StudentIdentity(recordMap(result['student'])),
        const SizedBox(height: 18),
        Text(
          recordText(
            recordMap(recordMap(result['student'])['currentClass'])['name'],
          ),
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        const Divider(color: line),
        const SizedBox(height: 12),
        const Icon(Icons.lock_outline, color: gold),
        const SizedBox(height: 12),
        const Text(
          'This conversation is private to this guardian and the assigned teacher. Other guardians have separate conversations.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 12),
        ),
        const SizedBox(height: 16),
        const Text(
          'For urgent matters, contact the school office directly.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.load, required this.teacherMode});
  final PageLoader load;
  final bool teacherMode;
  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String search = '';
  int page = 1;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeading(
              'New message',
              subtitle: widget.teacherMode
                  ? 'Choose a verified parent and student.'
                  : 'Choose your child and their assigned teacher.',
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => setState(() {
                search = value.trim();
                page = 1;
              }),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: TeacherData(
                  load: widget.load,
                  path:
                      '${FamilyMessagesPageState.base}/contacts?page=$page&search=${Uri.encodeQueryComponent(search)}',
                  builder: (value) {
                    final result = recordMap(value),
                        items = recordList(result['items']);
                    return Column(
                      children: [
                        if (items.isEmpty)
                          const EmptyRecords(
                            'No authorised contacts found. Contact the office about assignments or guardian links.',
                          ),
                        for (final pair in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              recordText(
                                recordMap(pair['contact'])['fullName'],
                              ),
                            ),
                            subtitle: Text(
                              '${recordMap(pair['student'])['fullName']} | ${recordMap(pair['student'])['admissionNo']}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, pair),
                          ),
                        _MessagePagination(
                          page: page,
                          totalPages: recordNumber(
                            recordMap(result['meta'])['totalPages'],
                          ).toInt(),
                          onPage: (value) => setState(() => page = value),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessagePagination extends StatelessWidget {
  const _MessagePagination({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });
  final int page, totalPages;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: 'Previous page',
        onPressed: page > 1 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Page $page', style: const TextStyle(color: muted, fontSize: 12)),
      IconButton(
        tooltip: 'Next page',
        onPressed: page < totalPages ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
