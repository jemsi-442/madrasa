import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'lesson_media_delivery.dart';
import 'lesson_document_surface.dart';
import 'media_player_samples.dart';
import 'lesson_playback_tools.dart';
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
  }) : previewSample = null,
       assert((position == null) == (total == null)),
       assert(position == null || (position > 0 && position <= (total ?? 0)));

  const LessonMediaViewer.preview({
    super.key,
    required MediaPlayerSample sample,
    this.position,
    this.total,
    this.onPrevious,
    this.onNext,
    this.onToggleFocus,
    this.focusView = false,
    this.surfaceBuilder,
  }) : previewSample = sample,
       assetId = '',
       apiBaseUrl = '',
       title = 'Player preview',
       load = null,
       onClose = null,
       assert((position == null) == (total == null)),
       assert(position == null || (position > 0 && position <= (total ?? 0)));
  final String assetId, apiBaseUrl, title;
  final PageLoader? load;
  final MediaPlayerSample? previewSample;
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
  ModalRoute<dynamic>? owningRoute;
  bool get playback => ['VIDEO', 'AUDIO'].contains(delivery?.kind);
  Color get secondary => playback ? playbackMuted : muted;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, owningRoute)) return;
    owningRoute = route;
    route.popped.then((_) {
      if (!mounted || !identical(route, owningRoute)) return;
      // Release streams immediately on Back, not after the outgoing route's
      // overlays/transition finish. Also invalidate any pending authorization.
      generation++;
      timeout?.cancel();
      setState(() {
        delivery = null;
        loading = false;
        ready = false;
        error = null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant LessonMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.apiBaseUrl != widget.apiBaseUrl ||
        oldWidget.previewSample != widget.previewSample) {
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
      final LessonMediaDelivery parsed;
      if (widget.previewSample case final sample?) {
        parsed = sample.delivery;
      } else {
        final raw = await widget.load!(
          '/api/learner/assets/${widget.assetId}/open',
        );
        parsed = LessonMediaDelivery.parse(
          recordMap(raw),
          apiBaseUrl: widget.apiBaseUrl,
          assetId: widget.assetId,
        );
      }
      if (!mounted || request != generation) return;
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
    setState(() {
      ready = false;
      error = widget.previewSample != null
          ? 'This sample could not be displayed. Try Reload player or choose another sample. Audio and video require a supported browser or mobile device.'
          : 'This resource could not be displayed. Check your connection and reload. If it still fails, ask your teacher to check the file format and media hosting permissions.';
    });
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  double videoHeight(BuildContext context, double width) {
    final toolbar = width < 640 ? 200.0 : 108.0;
    // Reserve desktop space for the title, resource navigation and transport
    // footer, so Focus view does not push playback controls below the screen.
    final limit = width >= 700
        ? (MediaQuery.sizeOf(context).height - 400).clamp(
            360.0,
            widget.focusView ? 900.0 : 620.0,
          )
        : (widget.focusView ? 600.0 : 520.0);
    return (width * 9 / 16 + toolbar).clamp(360.0, limit);
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
            ? 340
            : document
            ? (MediaQuery.sizeOf(context).height *
                      (widget.focusView ? .75 : .6))
                  .clamp(300.0, widget.focusView ? 900.0 : 680.0)
            : source.kind == 'VIDEO'
            ? videoHeight(context, box.maxWidth)
            : (box.maxWidth * 9 / 16).clamp(
                240.0,
                widget.focusView ? 900.0 : 620.0,
              ),
        child: ColoredBox(
          color: document ? const Color(0xFFF3F4F3) : const Color(0xFF0D0E10),
          child: Padding(
            padding: EdgeInsets.all(document ? 12 : 0),
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
                      onToggleFocus: widget.onToggleFocus,
                      focusView: widget.focusView,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: playback ? playbackPanel : Colors.white,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: playback ? Colors.white : ink,
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
                    color: playback
                        ? (error != null
                              ? playbackAccent
                              : const Color(0xFF7DDCB4))
                        : (error != null ? gold : forest),
                  ),
                  if (delivery != null)
                    Text(
                      delivery!.kind,
                      style: TextStyle(color: secondary, fontSize: 11),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: playback ? playbackAccent : ink,
                    ),
                    onPressed: loading ? null : reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload player'),
                  ),
                  if (widget.onToggleFocus != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: playback ? playbackAccent : ink,
                      ),
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
            decoration: BoxDecoration(
              color: playback ? const Color(0xFF191A1C) : paper,
              border: Border(
                top: BorderSide(color: playback ? Colors.white12 : line),
                bottom: BorderSide(color: playback ? Colors.white12 : line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.previewSample == null
                      ? 'Resource ${widget.position} of ${widget.total} available'
                      : 'Sample ${widget.position} of ${widget.total}',
                  style: TextStyle(color: secondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: playback
                          ? OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white30,
                              side: const BorderSide(color: Colors.white24),
                            )
                          : null,
                      key: const ValueKey('previous-resource'),
                      onPressed: widget.onPrevious,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Previous resource'),
                    ),
                    OutlinedButton.icon(
                      style: playback
                          ? OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white30,
                              side: const BorderSide(color: Colors.white24),
                            )
                          : null,
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
          surface(source),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              error != null
                  ? 'Playback needs attention. Reload the player or choose another resource.'
                  : source.kind == 'EMBED'
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
              style: TextStyle(color: secondary, fontSize: 12, height: 1.6),
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
                  style: TextButton.styleFrom(
                    foregroundColor: playback ? playbackAccent : ink,
                  ),
                  key: const ValueKey('return-to-lesson-text'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Back to lesson text'),
                ),
              Text(
                widget.previewSample == null
                    ? 'Opening media does not mark the lesson complete.'
                    : 'Sample only. No school records or learning progress are saved.',
                style: TextStyle(color: secondary, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
