import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

typedef LessonResourceOpener = Future<bool> Function(Uri uri);

Uri lessonResourceUri(String value, String apiBaseUrl) {
  if (value.trim().isEmpty) {
    throw const FormatException('Missing lesson resource link');
  }
  final uri = Uri.parse(apiBaseUrl).resolve(value);
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Unsupported lesson resource link');
  }
  return uri;
}

class LearnerLessonReader extends StatefulWidget {
  const LearnerLessonReader({
    super.key,
    required this.id,
    required this.load,
    required this.submit,
    required this.apiBaseUrl,
    this.openResource,
  });
  final String id, apiBaseUrl;
  final PageLoader load;
  final PageSubmitter submit;
  final LessonResourceOpener? openResource;
  @override
  State<LearnerLessonReader> createState() => _LearnerLessonReaderState();
}

class _LearnerLessonReaderState extends State<LearnerLessonReader> {
  late Future<dynamic> current = widget.load(
    '/api/learner/lessons/${widget.id}',
  );
  bool saving = false, preparing = false;
  Map<String, dynamic>? savedProgress;
  String? error;

  Future<void> complete() async {
    if (saving || preparing) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.submit(
        '/api/learner/lessons/${widget.id}/progress',
        {'progressPercent': 100, 'markCompleted': true},
      );
      if (mounted) setState(() => savedProgress = recordMap(result));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'Progress could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> resource(Map<String, dynamic> asset) async {
    if (preparing || saving) return;
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      final response = recordMap(
        await widget.load('/api/learner/assets/${asset['id']}/open'),
      );
      final delivery = recordMap(response['delivery']);
      if (delivery['status'] != 'READY' || delivery['inlineUrl'] == null) {
        if (mounted) {
          setState(
            () => error =
                'This resource is not connected yet. Please contact your teacher.',
          );
        }
        return;
      }
      final uri = lessonResourceUri(
        recordText(delivery['inlineUrl']),
        widget.apiBaseUrl,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ResourceDialog(
          title: recordText(asset['title'], 'Lesson resource'),
          uri: uri,
          expiresAt: DateTime.tryParse(recordText(delivery['expiresAt'])),
          openResource:
              widget.openResource ??
              (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'The resource could not be prepared. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !preparing,
    child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 960,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lesson reader',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close lesson',
                    onPressed: saving || preparing
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: PageResult(
                  future: current,
                  onRetry: () => setState(() {
                    current = widget.load('/api/learner/lessons/${widget.id}');
                    error = null;
                  }),
                  builder: (raw) {
                    final lesson = recordMap(recordMap(raw)['lesson']),
                        assets = recordList(lesson['assets']);
                    final progress =
                        savedProgress ?? recordMap(lesson['progress']);
                    final completed =
                        recordNumber(progress['progressPercent']) >= 100;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recordText(recordMap(lesson['course'])['title']),
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          recordText(lesson['title']),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (lesson['summary'] != null)
                          Text(
                            recordText(lesson['summary']),
                            style: const TextStyle(color: muted),
                          ),
                        const SizedBox(height: 18),
                        SurfacePanel(
                          child:
                              lesson['contentText'] == null ||
                                  recordText(
                                    lesson['contentText'],
                                  ).trim().isEmpty
                              ? const Text(
                                  'This lesson has no reading text. Check its resources below.',
                                )
                              : SelectableText(
                                  recordText(lesson['contentText']),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.8,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 22),
                        const PanelHeading(
                          'Lesson resources',
                          subtitle:
                              'Open resources in a browser tab or your device viewer.',
                        ),
                        if (assets.isEmpty)
                          const EmptyRecords(
                            'No resources attached to this lesson.',
                          ),
                        for (final asset in assets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SurfacePanel(
                              child: Wrap(
                                spacing: 14,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    asset['assetType'] == 'VIDEO'
                                        ? Icons.play_circle_outline
                                        : asset['assetType'] == 'AUDIO'
                                        ? Icons.headphones_outlined
                                        : Icons.description_outlined,
                                    color: gold,
                                  ),
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      recordText(
                                        asset['title'],
                                        'Lesson resource',
                                      ),
                                    ),
                                  ),
                                  TeacherTag(recordText(asset['assetType'])),
                                  OutlinedButton.icon(
                                    onPressed:
                                        !preparing &&
                                            !saving &&
                                            [
                                              'OPEN',
                                              'PREVIEW',
                                            ].contains(asset['accessState']) &&
                                            asset['sourceReady'] == true
                                        ? () => resource(asset)
                                        : null,
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 16,
                                    ),
                                    label: Text(
                                      ![
                                            'OPEN',
                                            'PREVIEW',
                                          ].contains(asset['accessState'])
                                          ? 'Access required'
                                          : asset['sourceReady'] != true
                                          ? 'Not connected'
                                          : 'Open resource',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: TeacherNotice(error!, warning: true),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 14,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TeacherTag(
                              completed
                                  ? 'Completed'
                                  : '${progress['progressPercent'] ?? 0}% recorded',
                              color: forest,
                            ),
                            FilledButton.icon(
                              onPressed: saving || preparing || completed
                                  ? null
                                  : complete,
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(
                                saving
                                    ? 'Saving...'
                                    : completed
                                    ? 'Lesson completed'
                                    : 'Mark complete',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const TeacherNotice(
                          'Mark complete when you finish this lesson. Your saved completion appears in course progress.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResourceDialog extends StatefulWidget {
  const _ResourceDialog({
    required this.title,
    required this.uri,
    required this.openResource,
    this.expiresAt,
  });
  final String title;
  final Uri uri;
  final DateTime? expiresAt;
  final LessonResourceOpener openResource;
  @override
  State<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends State<_ResourceDialog> {
  String? error;
  bool opening = false;
  Future<void> open() async {
    if (widget.expiresAt != null &&
        !DateTime.now().isBefore(widget.expiresAt!)) {
      setState(
        () => error =
            'This link expired. Close this window and open the resource again.',
      );
      return;
    }
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final opened = await widget.openResource(widget.uri);
      if (mounted) {
        if (opened) {
          Navigator.pop(context);
        } else {
          setState(
            () => error =
                'Your browser or device blocked this resource. Please try again.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to open the resource. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your resource is ready. Open it in a new browser tab or your device viewer.',
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: opening ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: opening ? null : open,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open in browser'),
      ),
    ],
  );
}
