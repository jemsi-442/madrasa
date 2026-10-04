import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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

class _LessonMediaSurfaceState extends State<LessonMediaSurface> {
  web.HTMLElement? element;
  ModalRoute<dynamic>? owningRoute;
  bool closed = false;
  bool mediaReady = false, hasError = false, buffering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, owningRoute)) return;
    owningRoute = route;
    route.popped.then((_) {
      if (!mounted || !identical(route, owningRoute)) return;
      // HTML platform views may survive the outgoing Flutter overlay briefly.
      // Stop the DOM stream itself rather than waiting for widget disposal.
      release();
      setState(() {});
    });
  }

  late final JSFunction ready = ((web.Event event) {
    if (!mounted || closed) return;
    if (!embedded) {
      element?.style.visibility = 'visible';
      setState(() {
        mediaReady = true;
        hasError = false;
      });
    }
    widget.onReady();
  }).toJS;
  late final JSFunction failed = ((web.Event event) {
    if (!mounted || closed) return;
    if (!embedded) {
      media?.pause();
      element?.style.visibility = 'hidden';
      setState(() {
        hasError = true;
        mediaReady = false;
        buffering = false;
      });
    }
    widget.onError();
  }).toJS;
  late final JSFunction settingsChanged = ((web.Event event) {
    if (!mounted || closed) return;
    setState(() {
      if (event.type == 'waiting' || event.type == 'seeking') buffering = true;
      if ([
        'canplay',
        'playing',
        'seeked',
        'pause',
        'ended',
      ].contains(event.type)) {
        buffering = false;
      }
    });
  }).toJS;
  static const events = [
    'timeupdate',
    'durationchange',
    'ratechange',
    'volumechange',
    'play',
    'pause',
    'ended',
    'waiting',
    'playing',
    'canplay',
    'seeking',
    'seeked',
  ];
  bool get embedded => widget.delivery.kind == 'EMBED';
  web.HTMLMediaElement? get media =>
      embedded || element == null ? null : element as web.HTMLMediaElement;
  bool get canSeek =>
      !closed &&
      media != null &&
      mediaReady &&
      !hasError &&
      media!.duration.isFinite &&
      media!.duration > 0;

  void control(void Function(web.HTMLMediaElement) action) {
    final node = media;
    if (node == null || !mediaReady || hasError) return;
    try {
      action(node);
      if (mounted) setState(() {});
    } catch (_) {
      widget.onError();
    }
  }

  Future<void> togglePlayback() async {
    final node = media;
    if (node == null || !mediaReady || hasError) return;
    try {
      if (node.paused) {
        await node.play().toDart;
      } else {
        node.pause();
      }
    } catch (_) {
      // play() can reject even without a media error event (e.g. permissions).
      if (mounted) widget.onError();
    }
  }

  void seek(Duration value) {
    if (!canSeek) return;
    control(
      (node) => node.currentTime = (value.inMilliseconds / 1000).clamp(
        0.0,
        node.duration,
      ),
    );
  }

  void stop() => control((node) {
    node.pause();
    if (canSeek) node.currentTime = 0;
  });

  void seekBy(int seconds) {
    if (canSeek) {
      seek(
        Duration(milliseconds: ((media!.currentTime + seconds) * 1000).round()),
      );
    }
  }

  void changeSpeed(double value) {
    control((node) => node.playbackRate = value);
  }

  void attach(Object value) {
    final node = value as web.HTMLElement;
    if (!mounted || closed) {
      node.remove();
      return;
    }
    element = node;
    node.style
      ..width = '100%'
      ..height = '100%'
      ..border = '0';
    node.setAttribute('aria-label', widget.delivery.title);
    node.addEventListener(embedded ? 'load' : 'loadedmetadata', ready);
    node.addEventListener('error', failed);
    if (embedded) {
      final frame = node as web.HTMLIFrameElement;
      frame
        ..title = widget.delivery.title
        ..referrerPolicy = 'strict-origin'
        ..allow = 'fullscreen; picture-in-picture; encrypted-media';
      frame.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-presentation',
      );
      frame.setAttribute('allowfullscreen', '');
      frame.src = widget.delivery.uri.toString();
    } else {
      final media = node as web.HTMLMediaElement;
      for (final event in events) {
        node.addEventListener(event, settingsChanged);
      }
      media
        ..controls = false
        ..autoplay = false
        ..preload = 'metadata';
      node.style
        ..backgroundColor = '#0d0e10'
        ..objectFit = 'contain'
        ..pointerEvents = 'none';
      node.tabIndex = -1;
      node.setAttribute('aria-hidden', 'true');
      node.setAttribute('playsinline', '');
      if (!widget.delivery.downloadAllowed) {
        // A browser UI hint only; source redirects are not DRM.
        node.setAttribute('controlslist', 'nodownload');
      }
      final asset = widget.delivery.assetPath;
      media.src = asset == null
          ? widget.delivery.uri.toString()
          : ui_web.assetManager.getAssetUrl(asset);
    }
  }

  void release() {
    closed = true;
    final node = element;
    element = null;
    if (node != null) {
      node.removeEventListener(embedded ? 'load' : 'loadedmetadata', ready);
      node.removeEventListener('error', failed);
      if (embedded) {
        (node as web.HTMLIFrameElement).src = 'about:blank';
      } else {
        final media = node as web.HTMLMediaElement;
        for (final event in events) {
          node.removeEventListener(event, settingsChanged);
        }
        media.pause();
        media.removeAttribute('src');
        media.load();
      }
      node.remove();
    }
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (closed) return const SizedBox.shrink();
    final view = HtmlElementView.fromTagName(
      tagName: embedded
          ? 'iframe'
          : widget.delivery.kind == 'AUDIO'
          ? 'audio'
          : 'video',
      onElementCreated: attach,
    );
    if (embedded) return view;
    final node = media;
    final enabled = mediaReady && !hasError;
    final play = enabled ? () => unawaited(togglePlayback()) : null;
    final backward = canSeek ? () => seekBy(-10) : null;
    final forward = canSeek ? () => seekBy(10) : null;
    final mute = enabled
        ? () => control((m) {
            if (!m.muted && m.volume == 0) {
              m.volume = 1;
            } else {
              m.muted = !m.muted;
            }
          })
        : null;
    return LessonPlaybackFrame(
      ready: mediaReady,
      failed: hasError,
      audio: widget.delivery.kind == 'AUDIO',
      playing: node != null && !node.paused,
      buffering: buffering,
      onPlay: play,
      onBackward: backward,
      onForward: forward,
      onMute: mute,
      controls: LessonPlaybackTools(
        speed: node?.playbackRate ?? 1,
        position: Duration(
          milliseconds: ((node?.currentTime ?? 0) * 1000).round(),
        ),
        duration: canSeek
            ? Duration(milliseconds: (node!.duration * 1000).round())
            : Duration.zero,
        playing: node != null && !node.paused,
        volume: node == null || node.muted ? 0 : node.volume,
        looping: node?.loop ?? false,
        onPlay: play,
        onStop: enabled ? stop : null,
        onBackward: backward,
        onForward: forward,
        onSeek: canSeek ? seek : null,
        onSpeed: enabled ? changeSpeed : null,
        onVolume: enabled
            ? (value) => control((m) {
                m.volume = value;
                m.muted = false;
              })
            : null,
        onMute: mute,
        onLoop: enabled ? () => control((m) => m.loop = !m.loop) : null,
        onFocus: widget.onToggleFocus,
        focusView: widget.focusView,
      ),
      child: view,
    );
  }
}
