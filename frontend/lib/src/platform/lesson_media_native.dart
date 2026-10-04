import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../lesson_media_delivery.dart';
import '../lesson_playback_tools.dart';
import '../lesson_playback_frame.dart';

class LessonMediaSurface extends StatefulWidget {
  const LessonMediaSurface({
    super.key,
    required this.delivery,
    required this.onReady,
    required this.onError,
    this.onToggleFocus,
    this.focusView = false,
  });
  final LessonMediaDelivery delivery;
  final VoidCallback onReady, onError;
  final VoidCallback? onToggleFocus;
  final bool focusView;
  @override
  State<LessonMediaSurface> createState() => _LessonMediaSurfaceState();
}

class _LessonMediaSurfaceState extends State<LessonMediaSurface>
    with WidgetsBindingObserver {
  VideoPlayerController? player;
  WebViewController? embed;
  bool failed = false, changingSpeed = false;
  double previousVolume = 1;
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
        final asset = widget.delivery.assetPath;
        final controller = asset == null
            ? VideoPlayerController.networkUrl(widget.delivery.uri)
            : VideoPlayerController.asset(asset);
        player = controller;
        controller.addListener(changed);
        await controller.initialize();
        if (mounted) {
          setState(() {});
          widget.onReady();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => failed = true);
        widget.onError();
      }
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

  Future<void> changeSpeed(double speed) async {
    final controller = player;
    if (controller == null || changingSpeed) return;
    final previous = controller.value.playbackSpeed;
    setState(() => changingSpeed = true);
    try {
      await controller.setPlaybackSpeed(speed);
    } catch (_) {
      if (!mounted) return;
      await control(() => controller.setPlaybackSpeed(previous));
      if (mounted) widget.onError();
    } finally {
      if (mounted) setState(() => changingSpeed = false);
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

  Future<void> stop() async {
    final controller = player;
    if (controller == null) return;
    await control(() async {
      await controller.pause();
      await controller.seekTo(Duration.zero);
    });
  }

  void mute() {
    final controller = player;
    if (controller == null) return;
    final volume = controller.value.volume;
    if (volume > 0) previousVolume = volume;
    unawaited(
      control(() => controller.setVolume(volume > 0 ? 0 : previousVolume)),
    );
  }

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
    final value = controller?.value;
    final ready = value?.isInitialized == true && !failed;
    final canSeek = ready && value!.duration > Duration.zero;
    final play = ready
        ? () => control(value!.isPlaying ? controller!.pause : controller!.play)
        : null;
    final backward = canSeek
        ? () => control(
            () => controller!.seekTo(
              controller.value.position - const Duration(seconds: 10),
            ),
          )
        : null;
    final forward = canSeek
        ? () => control(
            () => controller!.seekTo(
              controller.value.position + const Duration(seconds: 10),
            ),
          )
        : null;
    return LessonPlaybackFrame(
      ready: ready,
      failed: failed,
      audio: widget.delivery.kind == 'AUDIO',
      playing: value?.isPlaying ?? false,
      buffering: value?.isBuffering ?? false,
      onPlay: play,
      onBackward: backward,
      onForward: forward,
      onMute: ready ? mute : null,
      controls: LessonPlaybackTools(
        speed: value?.playbackSpeed ?? 1,
        position: value?.position ?? Duration.zero,
        duration: value?.duration ?? Duration.zero,
        playing: value?.isPlaying ?? false,
        volume: value?.volume ?? 1,
        looping: value?.isLooping ?? false,
        onPlay: play,
        onStop: ready ? stop : null,
        onBackward: backward,
        onForward: forward,
        onSeek: canSeek ? (v) => control(() => controller!.seekTo(v)) : null,
        onSpeed: ready && !changingSpeed ? changeSpeed : null,
        onVolume: ready ? (v) => control(() => controller!.setVolume(v)) : null,
        onMute: ready ? mute : null,
        onLoop: ready
            ? () => control(() => controller!.setLooping(!value!.isLooping))
            : null,
        onFocus: widget.onToggleFocus,
        focusView: widget.focusView,
      ),
      child: ready && widget.delivery.kind == 'VIDEO'
          ? Center(
              child: AspectRatio(
                aspectRatio: value!.aspectRatio > 0
                    ? value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller!),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
