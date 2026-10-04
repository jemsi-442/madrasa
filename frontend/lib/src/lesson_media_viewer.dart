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

IconData lessonResourceIcon(String kind) => switch (kind) {
  'VIDEO' || 'EMBED' => Icons.play_circle_outline,
  'AUDIO' => Icons.headphones_outlined,
  'IMAGE' => Icons.image_outlined,
  'PDF' => Icons.picture_as_pdf_outlined,
  _ => Icons.description_outlined,
};

/// Authorized inline media, sharing the lesson's scroll area and navigation.
class LessonMediaViewer extends StatefulWidget {
  const LessonMediaViewer({
    super.key,
    required this.assetId,
    required this.load,
    required this.apiBaseUrl,
    this.title = 'Lesson resource',
    this.onClose,
    this.position,
    this.total,
    this.onPrevious,
    this.onNext,
    this.onToggleFocus,
    this.focusView = false,
    this.surfaceBuilder,
  }) : assert((position == null) == (total == null)),
       assert(position == null || (position > 0 && position <= (total ?? 0)));
  final String assetId, apiBaseUrl, title;
  final PageLoader load;
  final VoidCallback? onClose;
  final int? position, total;
  final VoidCallback? onPrevious, onNext, onToggleFocus;
  final bool focusView;
  final LessonMediaBuilder? surfaceBuilder;
  @override
  State<LessonMediaViewer> createState() => _LessonMediaViewerState();
}

class _LessonMediaViewerState extends State<LessonMediaViewer> {
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

  @override
  void didUpdateWidget(covariant LessonMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      loading = false;
      reload();
    }
  }

  Future<void> reload() async {
    if (loading) return;
    timeout?.cancel();
    final request = ++generation;
    setState(() {
      loading = true;
      delivery = null;
      error = null;
      ready = false;
    });
    try {
      final raw = await widget.load(
        '/api/learner/assets/${widget.assetId}/open',
      );
      if (!mounted || request != generation) return;
      final parsed = LessonMediaDelivery.parse(
        recordMap(raw),
        apiBaseUrl: widget.apiBaseUrl,
        assetId: widget.assetId,
      );
      setState(() => delivery = parsed);
      timeout = Timer(const Duration(seconds: 15), () {
        if (mounted && request == generation && !ready) {
          setState(
            () => error =
                'This resource is taking longer to load. Check your connection and try Reload player.',
          );
        }
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(
          () => error = e is ApiException
              ? e.message
              : e is FormatException
              ? e.message.toString()
              : 'The media could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void onReady(int request) {
    if (!mounted || request != generation) return;
    timeout?.cancel();
    setState(() {
      ready = true;
      error = null;
    });
  }

  void onError(int request) {
    if (!mounted || request != generation) return;
    timeout?.cancel();
    setState(
      () => error =
          'This resource could not be displayed. Check your connection and reload. If it still fails, ask your teacher to check the file format and media hosting permissions.',
    );
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  Widget surface(LessonMediaDelivery source) {
    final request = generation;
    final document = ['PDF', 'IMAGE', 'TEXT'].contains(source.kind);
    void onLoaded() => onReady(request);
    void onFailed() => onError(request);
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        key: const ValueKey('lesson-media-stage'),
        height: source.kind == 'AUDIO'
            ? 192
            : document
            ? (MediaQuery.sizeOf(context).height *
                      (widget.focusView ? .75 : .6))
                  .clamp(300.0, widget.focusView ? 900.0 : 680.0)
            : (box.maxWidth * 9 / 16).clamp(
                240.0,
                widget.focusView ? 900.0 : 620.0,
              ),
        child: ColoredBox(
          color: document
              ? const Color(0xFFF3F4F3)
              : source.kind == 'AUDIO'
              ? Colors.white
              : const Color(0xFF10263A),
          child: Padding(
            padding: EdgeInsets.all(
              document || source.kind == 'AUDIO' ? 12 : 0,
            ),
            child: KeyedSubtree(
              key: ValueKey(generation),
              child: widget.surfaceBuilder != null
                  ? widget.surfaceBuilder!(source, onLoaded, onFailed)
                  : document
                  ? LessonDocumentSurface(
                      delivery: source,
                      onReady: onLoaded,
                      onError: onFailed,
                    )
                  : platform.LessonMediaSurface(
                      delivery: source,
                      onReady: onLoaded,
                      onError: onFailed,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(lessonResourceIcon(delivery?.kind ?? ''), color: gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      delivery?.title ?? widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TeacherTag(
                    loading
                        ? 'Opening resource'
                        : error != null
                        ? 'Needs attention'
                        : ready
                        ? 'Ready'
                        : 'Loading controls',
                    color: error != null ? gold : forest,
                  ),
                  if (delivery != null)
                    Text(
                      delivery!.kind,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  TextButton.icon(
                    onPressed: loading ? null : reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload player'),
                  ),
                  if (widget.onToggleFocus != null)
                    TextButton.icon(
                      key: const ValueKey('media-focus-view'),
                      onPressed: widget.onToggleFocus,
                      icon: Icon(
                        widget.focusView
                            ? Icons.close_fullscreen
                            : Icons.open_in_full,
                        size: 18,
                      ),
                      label: Text(
                        widget.focusView ? 'Exit focus view' : 'Focus view',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (widget.position != null)
          Container(
            key: const ValueKey('media-resource-navigation'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: paper,
              border: Border(
                top: BorderSide(color: line),
                bottom: BorderSide(color: line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Resource ${widget.position} of ${widget.total} available',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('previous-resource'),
                      onPressed: widget.onPrevious,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Previous resource'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('next-resource'),
                      onPressed: widget.onNext,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: const Text('Next resource'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (loading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (delivery case final source?) ...[
          if (source.kind == 'AUDIO')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF4EDDC), Color(0xFFF4F8F6)],
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.headphones_outlined, size: 48, color: gold),
                  SizedBox(height: 12),
                  Text(
                    'Listen at your own pace',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          surface(source),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              source.kind == 'EMBED'
                  ? 'Use the embedded player controls without leaving your lesson.'
                  : ready
                  ? switch (source.kind) {
                      'PDF' =>
                        'Scroll through the pages or use the page and zoom controls.',
                      'IMAGE' =>
                        'Pinch or scroll to zoom. Drag to move around the image.',
                      'TEXT' => 'Read your lesson resource here.',
                      _ => 'Use the player controls to play, pause and seek.',
                    }
                  : 'Loading media controls...',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: TeacherNotice(error!, warning: true),
          ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onClose != null)
                TextButton.icon(
                  key: const ValueKey('return-to-lesson-text'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Back to lesson text'),
                ),
              const Text(
                'Opening media does not mark the lesson complete.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
