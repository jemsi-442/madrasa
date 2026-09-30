import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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

class _LessonMediaSurfaceState extends State<LessonMediaSurface> {
  web.HTMLElement? element;
  late final JSFunction ready = ((web.Event event) {
    if (mounted) widget.onReady();
  }).toJS;
  late final JSFunction failed = ((web.Event event) {
    if (mounted) widget.onError();
  }).toJS;
  bool get embedded => widget.delivery.kind == 'EMBED';

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
        media.pause();
        media.removeAttribute('src');
        media.load();
      }
      node.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: embedded
        ? 'iframe'
        : widget.delivery.kind == 'AUDIO'
        ? 'audio'
        : 'video',
    onElementCreated: attach,
  );
}
