import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'lesson_media_delivery.dart';

class LessonDocumentSurface extends StatefulWidget {
  const LessonDocumentSurface({
    super.key,
    required this.delivery,
    required this.onReady,
    required this.onError,
  });
  final LessonMediaDelivery delivery;
  final VoidCallback onReady, onError;

  @override
  State<LessonDocumentSurface> createState() => _LessonDocumentSurfaceState();
}

class _LessonDocumentSurfaceState extends State<LessonDocumentSurface> {
  final pdf = PdfViewerController();
  final zoom = TransformationController();
  final client = http.Client();
  int page = 1, pages = 0;
  bool notified = false;
  String? text;

  @override
  void initState() {
    super.initState();
    if (widget.delivery.kind == 'TEXT') unawaited(loadText());
  }

  void notify(bool success) {
    if (notified) return;
    notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (success) {
          widget.onReady();
        } else {
          widget.onError();
        }
      }
    });
  }

  Future<void> loadText() async {
    try {
      // Keep text attachments bounded; never interpret them as HTML.
      final response = await client
          .send(http.Request('GET', widget.delivery.uri))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const FormatException();
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          throw const FormatException('Text attachment is too large');
        }
        bytes.addAll(chunk);
      }
      final value = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      setState(() => text = value);
      notify(true);
    } catch (_) {
      if (mounted) notify(false);
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    client.close();
    zoom.dispose();
    if (widget.delivery.kind == 'IMAGE') {
      unawaited(NetworkImage(widget.delivery.uri.toString()).evict());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.delivery.kind == 'TEXT') {
      return text == null
          ? const Center(child: Text('Loading text...'))
          : SingleChildScrollView(child: SelectableText(text!));
    }
    if (widget.delivery.kind == 'IMAGE') {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => zoom.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen),
              label: const Text('Reset zoom'),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              transformationController: zoom,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  widget.delivery.uri.toString(),
                  semanticLabel: widget.delivery.title,
                  fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, synchronous) {
                    if (frame != null) notify(true);
                    return child;
                  },
                  errorBuilder: (context, error, stack) {
                    notify(false);
                    return const Text('This image could not be displayed.');
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous PDF page',
              onPressed: pages > 0 && page > 1
                  ? () => pdf.goToPage(pageNumber: page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(pages == 0 ? 'Loading PDF...' : 'Page $page of $pages'),
            IconButton(
              tooltip: 'Next PDF page',
              onPressed: pages > 0 && page < pages
                  ? () => pdf.goToPage(pageNumber: page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Zoom out PDF',
              onPressed: pages > 0 ? () => pdf.zoomDown() : null,
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Zoom in PDF',
              onPressed: pages > 0 ? () => pdf.zoomUp() : null,
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
        Expanded(
          child: PdfViewer.uri(
            widget.delivery.uri,
            controller: pdf,
            useProgressiveLoading: false,
            params: PdfViewerParams(
              onViewerReady: (document, controller) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => pages = document.pages.length);
                });
                notify(true);
              },
              onPageChanged: (value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && value != null) setState(() => page = value);
                });
              },
              onDocumentLoadFinished: (document, succeeded) {
                if (!succeeded) notify(false);
              },
              errorBannerBuilder: (context, error, stack, document) =>
                  const Center(child: Text('This PDF could not be displayed.')),
              // Document links must never silently launch another app or tab.
              linkHandlerParams: PdfLinkHandlerParams(
                onLinkTap: (link) {
                  if (link.dest != null) {
                    pdf.goToDest(link.dest!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'External document links are not opened in the lesson viewer.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
