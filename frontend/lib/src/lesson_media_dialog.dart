import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'lesson_media_delivery.dart';
import 'lesson_document_surface.dart';
import 'teacher_ui.dart';
import 'platform/lesson_media_native.dart'
    if (dart.library.js_interop) 'platform/lesson_media_web.dart'
    as platform;

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
  });
  final String assetId, apiBaseUrl;
  final PageLoader load;
  final LessonMediaBuilder? surfaceBuilder;
  @override
  State<LessonMediaDialog> createState() => _LessonMediaDialogState();
}

class _LessonMediaDialogState extends State<LessonMediaDialog> {
  LessonMediaDelivery? delivery;
  bool loading = false, ready = false;
  String? error;
  int generation = 0;
  Timer? timeout;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (loading) return;
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
                'This resource is taking longer to load. Check your connection and try Reload player.',
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
            'This resource could not be displayed. Check your connection and reload. If it still fails, ask your teacher to check the file format and media hosting permissions.',
      );
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
                            ? 90
                            : ['PDF', 'IMAGE', 'TEXT'].contains(source.kind)
                            ? MediaQuery.sizeOf(context).height * .52
                            : (size.maxWidth * 9 / 16).clamp(200, 480),
                        child: KeyedSubtree(
                          key: ValueKey(generation),
                          child: widget.surfaceBuilder != null
                              ? widget.surfaceBuilder!(source, onReady, onError)
                              : ['PDF', 'IMAGE', 'TEXT'].contains(source.kind)
                              ? LessonDocumentSurface(
                                  delivery: source,
                                  onReady: onReady,
                                  onError: onError,
                                )
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
                          ? 'Use the embedded player controls without leaving your lesson.'
                          : ready
                          ? source.kind == 'PDF'
                                ? 'Scroll through the pages or use the page and zoom controls.'
                                : source.kind == 'IMAGE'
                                ? 'Pinch or scroll to zoom. Drag to move around the image.'
                                : source.kind == 'TEXT'
                                ? 'Read your lesson resource here.'
                                : 'Use the player controls to play, pause and seek.'
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
                        onPressed: loading ? null : reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload player'),
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
