import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'lesson_media_delivery.dart';
import 'teacher_ui.dart';
import 'platform/lesson_media_stub.dart'
    if (dart.library.js_interop) 'platform/lesson_media_web.dart'
    as platform;

bool get inlineLessonMediaSupported => platform.inlineLessonMediaSupported;
typedef LessonMediaBuilder =
    Widget Function(
      LessonMediaDelivery delivery,
      VoidCallback onReady,
      VoidCallback onError,
    );

class LessonMediaDialog extends StatefulWidget {
  const LessonMediaDialog({
    super.key,
    required this.assetId,
    required this.load,
    required this.apiBaseUrl,
    this.surfaceBuilder,
    this.openResource,
  });
  final String assetId, apiBaseUrl;
  final PageLoader load;
  final LessonMediaBuilder? surfaceBuilder;
  final Future<bool> Function(Uri)? openResource;
  @override
  State<LessonMediaDialog> createState() => _LessonMediaDialogState();
}

class _LessonMediaDialogState extends State<LessonMediaDialog> {
  LessonMediaDelivery? delivery;
  bool loading = false, ready = false, opening = false;
  String? error;
  int generation = 0;
  Timer? timeout;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (loading || opening) return;
    timeout?.cancel();
    setState(() {
      loading = true;
      delivery = null;
      error = null;
      ready = false;
      generation++;
    });
    try {
      final raw = await widget.load(
        '/api/learner/assets/${widget.assetId}/open',
      );
      final parsed = LessonMediaDelivery.parse(
        recordMap(raw),
        apiBaseUrl: widget.apiBaseUrl,
        assetId: widget.assetId,
      );
      if (!mounted) return;
      setState(() => delivery = parsed);
      timeout = Timer(const Duration(seconds: 15), () {
        if (mounted && !ready) {
          setState(
            () => error =
                'The player is taking longer to load. Try Reload player or Open in browser.',
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : e is FormatException
              ? e.message.toString()
              : 'The media could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void onReady() {
    timeout?.cancel();
    if (mounted) {
      setState(() {
        ready = true;
        error = null;
      });
    }
  }

  void onError() {
    timeout?.cancel();
    if (mounted) {
      setState(
        () => error =
            'Playback failed or this format is not supported. Reload the player or open it in your browser.',
      );
    }
  }

  Future<void> open() async {
    final source = delivery;
    if (source == null || opening) return;
    if (!source.expiresAt.isAfter(DateTime.now())) {
      setState(
        () => error =
            'This media link expired. Reload the player to get a fresh link.',
      );
      return;
    }
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final opened =
          await (widget.openResource ??
              (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(
            source.uri,
          );
      if (mounted && !opened) {
        setState(
          () => error = 'Your browser blocked the resource. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The resource could not be opened. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 960,
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lesson media',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close player',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (delivery case final source?) ...[
                    Text(
                      source.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, size) => SizedBox(
                        height: source.kind == 'AUDIO'
                            ? 80
                            : (size.maxWidth * 9 / 16).clamp(200, 480),
                        child: KeyedSubtree(
                          key: ValueKey(generation),
                          child: widget.surfaceBuilder != null
                              ? widget.surfaceBuilder!(source, onReady, onError)
                              : platform.LessonMediaSurface(
                                  delivery: source,
                                  onReady: onReady,
                                  onError: onError,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      source.kind == 'EMBED'
                          ? 'Use the embedded player controls. If the provider blocks playback here, open it in your browser.'
                          : ready
                          ? 'Use the player controls to play, pause and seek.'
                          : 'Loading media controls...',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TeacherNotice(error!, warning: true),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: loading || opening ? null : reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload player'),
                      ),
                      if (delivery != null)
                        OutlinedButton.icon(
                          onPressed: opening ? null : open,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in browser'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const TeacherNotice(
                    'Playback does not mark the lesson complete. Return to the lesson reader and choose Mark complete when you finish.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
