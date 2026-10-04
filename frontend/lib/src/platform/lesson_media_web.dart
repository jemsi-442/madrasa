import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../lesson_media_delivery.dart';
import '../lesson_playback_tools.dart';

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

class _LessonMediaSurfaceState extends State<LessonMediaSurface> {
  web.HTMLElement? element;
  bool mediaReady = false;
  double speed = 1;
  late final JSFunction ready = ((web.Event event) {
    if (!mounted) return;
    if (!embedded) setState(() => mediaReady = true);
    widget.onReady();
  }).toJS;
  late final JSFunction failed = ((web.Event event) {
    if (!mounted) return;
    if (!embedded) setState(() => mediaReady = false);
    widget.onError();
  }).toJS;
  late final JSFunction settingsChanged = ((web.Event event) {
    if (mounted) setState(() => speed = media?.playbackRate ?? 1);
  }).toJS;
  bool get embedded => widget.delivery.kind == 'EMBED';
  web.HTMLMediaElement? get media =>
      embedded || element == null ? null : element as web.HTMLMediaElement;
  bool get canSeek =>
      mediaReady && media!.duration.isFinite && media!.duration > 0;

  void seekBy(int seconds) {
    final node = media;
    if (node == null || !canSeek) return;
    try {
      node.currentTime = (node.currentTime + seconds)
          .clamp(0, node.duration)
          .toDouble();
    } catch (_) {
      widget.onError();
    }
  }

  void changeSpeed(double value) {
    final node = media;
    if (node == null || !mediaReady) return;
    try {
      node.playbackRate = value;
      setState(() => speed = node.playbackRate);
    } catch (_) {
      widget.onError();
    }
  }

  void attach(Object value) {
    final node = value as web.HTMLElement;
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
      node.addEventListener('ratechange', settingsChanged);
      node.addEventListener('durationchange', settingsChanged);
      media
        ..controls = true
        ..autoplay = false
        ..preload = 'metadata';
      node.style.backgroundColor = widget.delivery.kind == 'AUDIO'
          ? '#ffffff'
          : '#10263a';
      node.setAttribute('playsinline', '');
      if (!widget.delivery.downloadAllowed) {
        // A browser UI hint only; source redirects are not DRM.
        node.setAttribute('controlslist', 'nodownload');
      }
      media.src = widget.delivery.uri.toString();
    }
  }

  @override
  void dispose() {
    final node = element;
    if (node != null) {
      node.removeEventListener(embedded ? 'load' : 'loadedmetadata', ready);
      node.removeEventListener('error', failed);
      if (embedded) {
        (node as web.HTMLIFrameElement).src = 'about:blank';
      } else {
        final media = node as web.HTMLMediaElement;
        node.removeEventListener('ratechange', settingsChanged);
        node.removeEventListener('durationchange', settingsChanged);
        media.pause();
        media.removeAttribute('src');
        media.load();
      }
      node.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = HtmlElementView.fromTagName(
      tagName: embedded
          ? 'iframe'
          : widget.delivery.kind == 'AUDIO'
          ? 'audio'
          : 'video',
      onElementCreated: attach,
    );
    if (embedded) return view;
    return Column(
      children: [
        Expanded(child: view),
        LessonPlaybackTools(
          speed: speed,
          onBackward: canSeek ? () => seekBy(-10) : null,
          onForward: canSeek ? () => seekBy(10) : null,
          onSpeed: mediaReady ? changeSpeed : null,
        ),
      ],
    );
  }
}
