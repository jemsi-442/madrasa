import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../lesson_media_delivery.dart';

class LessonMediaSurface extends StatefulWidget {
  const LessonMediaSurface({
    super.key,
    required this.delivery,
    required this.onReady,
    required this.onError,
  });
  final LessonMediaDelivery delivery;
  final VoidCallback onReady, onError;
  @override
  State<LessonMediaSurface> createState() => _LessonMediaSurfaceState();
}

class _LessonMediaSurfaceState extends State<LessonMediaSurface>
    with WidgetsBindingObserver {
  VideoPlayerController? player;
  WebViewController? embed;
  bool failed = false;
  bool get supported => [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initialize());
  }

  Future<void> initialize() async {
    try {
      if (!supported) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onError();
        });
        return;
      }
      if (widget.delivery.kind == 'EMBED') {
        final controller = WebViewController();
        embed = controller;
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        await controller.setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) =>
                lessonEmbedNavigationAllowed(
                  request.url,
                  widget.delivery.uri,
                  isMainFrame: request.isMainFrame,
                )
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
            onPageFinished: (_) {
              if (mounted) widget.onReady();
            },
            onWebResourceError: (error) {
              if (mounted && error.isForMainFrame == true) widget.onError();
            },
          ),
        );
        if (!mounted) return;
        await controller.loadRequest(widget.delivery.uri);
        if (mounted) setState(() {});
      } else {
        final controller = VideoPlayerController.networkUrl(
          widget.delivery.uri,
        );
        player = controller;
        controller.addListener(changed);
        await controller.initialize();
        if (mounted) {
          setState(() {});
          widget.onReady();
        }
      }
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  void changed() {
    if (!mounted) return;
    if (player!.value.hasError && !failed) {
      failed = true;
      widget.onError();
    }
    setState(() {});
  }

  Future<void> control(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final controller = player;
      if (controller != null) unawaited(control(controller.pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = player;
    if (controller != null) {
      controller.removeListener(changed);
      unawaited(controller.dispose());
    }
    // Tear down embedded playback too, rather than leave a hidden stream running.
    unawaited(
      embed?.loadRequest(Uri.parse('about:blank')).catchError((_) {}) ??
          Future<void>.value(),
    );
    super.dispose();
  }

  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!supported) {
      return const Center(
        child: Text(
          'Media playback is not supported on this desktop platform yet.',
        ),
      );
    }
    if (widget.delivery.kind == 'EMBED') {
      return embed == null
          ? const SizedBox.shrink()
          : WebViewWidget(controller: embed!);
    }
    final controller = player;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Loading player...'));
    }
    final value = controller.value;
    return Column(
      children: [
        if (widget.delivery.kind == 'VIDEO')
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        if (value.isBuffering) const LinearProgressIndicator(),
        Row(
          children: [
            IconButton(
              tooltip: value.isPlaying ? 'Pause' : 'Play',
              onPressed: () =>
                  control(value.isPlaying ? controller.pause : controller.play),
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: VideoProgressIndicator(controller, allowScrubbing: true),
            ),
            const SizedBox(width: 8),
            Text('${time(value.position)} / ${time(value.duration)}'),
          ],
        ),
      ],
    );
  }
}
