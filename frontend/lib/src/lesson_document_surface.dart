import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'lesson_media_delivery.dart';
import 'pdf_reading_frame.dart';

class LessonDocumentSurface extends StatefulWidget {
  const LessonDocumentSurface({
    super.key,
    required this.delivery,
    required this.onReady,
    required this.onError,
    this.fullScreen = false,
    this.initialPage = 1,
    this.onPageChanged,
    this.onMinimize,
  });
  final LessonMediaDelivery delivery;
  final VoidCallback onReady, onError;
  final bool fullScreen;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onMinimize;

  @override
  State<LessonDocumentSurface> createState() => _LessonDocumentSurfaceState();
}

class _LessonDocumentSurfaceState extends State<LessonDocumentSurface> {
  final pdf = PdfViewerController();
  final zoom = TransformationController();
  final client = http.Client();
  int page = 1, pages = 0;
  bool notified = false;
  bool textFailed = false;
  String? text;
  bool expanded = false;
  bool openingFullScreen = false;
  OverlayEntry? fullscreenOverlay;
  LocalHistoryEntry? fullscreenHistory;
  ModalRoute<dynamic>? fullscreenRoute;
  final fullscreenFocus = FocusScopeNode(debugLabel: 'Lesson PDF fullscreen');
  double textOffset = 0;
  double textSize = 18;

  void resizeText(double size) {
    setState(() => textSize = size.clamp(14, 28));
    fullscreenOverlay?.markNeedsBuild();
  }

  late final ScrollController textScroll =
      ScrollController(
        onAttach: (position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && textScroll.positions.contains(position)) {
              position.jumpTo(textOffset.clamp(0, position.maxScrollExtent));
            }
          });
        },
      )..addListener(() {
        if (textScroll.hasClients) textOffset = textScroll.offset;
      });

  void openFullScreen() {
    if (!mounted || expanded || widget.fullScreen) return;
    setState(() {
      openingFullScreen = false;
      expanded = true;
    });
    fullscreenHistory = LocalHistoryEntry(
      onRemove: () {
        fullscreenHistory = null;
        fullscreenRoute = null;
        if (!mounted) return;
        removeFullScreenOverlay();
        setState(() => expanded = false);
      },
    );
    fullscreenRoute = ModalRoute.of(context);
    fullscreenRoute?.addLocalHistoryEntry(fullscreenHistory!);
    fullscreenOverlay = OverlayEntry(
      builder: (_) => InheritedTheme.captureAll(context, buildFullScreen()),
    );
    Overlay.of(context, rootOverlay: true).insert(fullscreenOverlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && expanded) fullscreenFocus.requestFocus();
    });
  }

  void removeFullScreenOverlay() {
    final overlay = fullscreenOverlay;
    fullscreenOverlay = null;
    overlay?.remove();
    overlay?.dispose();
  }

  void minimize() {
    fullscreenHistory?.remove();
  }

  void fitPdfWidth() {
    if (!mounted || !pdf.isReady || pages == 0) return;
    final matrix = pdf.calcMatrixFitWidthForPage(
      pageNumber: page.clamp(1, pages),
    );
    if (matrix != null) {
      unawaited(pdf.goTo(matrix, duration: Duration.zero));
    }
  }

  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    if (widget.delivery.kind == 'TEXT') unawaited(loadText());
    if ((widget.delivery.kind == 'PDF' || widget.delivery.kind == 'TEXT') &&
        !widget.fullScreen) {
      openingFullScreen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => openFullScreen());
    }
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
      final asset = widget.delivery.assetPath;
      if (asset != null) {
        final value = await rootBundle.loadString(asset);
        if (!mounted) return;
        setState(() => text = value);
        fullscreenOverlay?.markNeedsBuild();
        notify(true);
        return;
      }
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
      fullscreenOverlay?.markNeedsBuild();
      notify(true);
    } catch (_) {
      if (mounted) {
        setState(() => textFailed = true);
        fullscreenOverlay?.markNeedsBuild();
        notify(false);
      }
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    removeFullScreenOverlay();
    final history = fullscreenHistory;
    final route = fullscreenRoute;
    fullscreenHistory = null;
    // Removing history can notify the route; do it outside widget teardown.
    if (history != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive ?? false) history.remove();
      });
    }
    client.close();
    fullscreenFocus.dispose();
    textScroll.dispose();
    zoom.dispose();
    if (widget.delivery.kind == 'IMAGE' && widget.delivery.assetPath == null) {
      unawaited(NetworkImage(widget.delivery.uri.toString()).evict());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildDocument(context);
  }

  Widget buildFullScreen() => Positioned.fill(
    child: BlockSemantics(
      child: SelectionContainer.disabled(
        child: Material(
          child: SafeArea(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): minimize,
              },
              child: FocusScope(
                node: fullscreenFocus,
                autofocus: true,
                child: widget.delivery.kind == 'TEXT'
                    ? buildTextReader(fullScreen: true)
                    : LessonDocumentSurface(
                        delivery: widget.delivery,
                        fullScreen: true,
                        initialPage: page,
                        onMinimize: minimize,
                        onPageChanged: (value) => page = value,
                        onReady: () => notify(true),
                        onError: () => notify(false),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget buildDocument(BuildContext context) {
    final asset = widget.delivery.assetPath;
    if (widget.delivery.kind == 'TEXT') {
      if (expanded || openingFullScreen) return const SizedBox.expand();
      return buildTextReader();
    }
    if (widget.delivery.kind == 'IMAGE') {
      return buildImage(asset);
    }
    return buildPdf(asset);
  }

  Widget buildTextReader({bool fullScreen = false}) => PdfReadingFrame(
    title: widget.delivery.title,
    documentLabel: 'TEXT DOCUMENT',
    documentIcon: Icons.article_outlined,
    onClose: fullScreen ? minimize : null,
    closeLabel: 'Minimize text',
    closeIcon: Icons.fullscreen_exit,
    toolbar: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.menu_book_outlined, size: 20),
        const Text('Reading view'),
        PdfControlGroup(
          children: [
            IconButton(
              tooltip: 'Smaller text',
              onPressed: textSize > 14 ? () => resizeText(textSize - 2) : null,
              icon: const Icon(Icons.text_decrease),
            ),
            Text('${textSize.toInt()} px'),
            IconButton(
              tooltip: 'Larger text',
              onPressed: textSize < 28 ? () => resizeText(textSize + 2) : null,
              icon: const Icon(Icons.text_increase),
            ),
            TextButton(
              onPressed: textSize != 18 ? () => resizeText(18) : null,
              child: const Text('Reset size'),
            ),
          ],
        ),
        if (!fullScreen) ...[
          OutlinedButton.icon(
            onPressed: openFullScreen,
            icon: const Icon(Icons.fullscreen),
            label: const Text('Full-screen text'),
          ),
        ],
      ],
    ),
    child: textFailed
        ? const Center(
            child: Text(
              'This text resource could not be loaded. Use Reload player to try again.',
            ),
          )
        : text == null
        ? const Center(child: Text('Loading text...'))
        : SingleChildScrollView(
            controller: textScroll,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 860),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  text!,
                  style: TextStyle(
                    fontSize: textSize,
                    height: 1.7,
                    color: Color(0xFF193E53),
                  ),
                ),
              ),
            ),
          ),
  );

  Widget buildImage(String? asset) {
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
              child: Image(
                image: asset != null
                    ? AssetImage(asset)
                    : NetworkImage(widget.delivery.uri.toString()),
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

  Widget buildPdf(String? asset) {
    if (expanded || openingFullScreen) return const SizedBox.expand();
    return PdfReadingFrame(
      title: widget.delivery.title,
      onClose: widget.fullScreen
          ? widget.onMinimize ?? () => Navigator.of(context).pop()
          : null,
      closeLabel: 'Minimize PDF',
      closeIcon: Icons.fullscreen_exit,
      toolbar: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!widget.fullScreen)
            OutlinedButton.icon(
              onPressed: openFullScreen,
              icon: const Icon(Icons.fullscreen),
              label: const Text('Full-screen PDF'),
            ),
          PdfControlGroup(
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
            ],
          ),
          PdfControlGroup(
            children: [
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
              TextButton.icon(
                onPressed: pages > 0 ? fitPdfWidth : null,
                icon: const Icon(Icons.fit_screen),
                label: const Text('Fit width'),
              ),
            ],
          ),
        ],
      ),
      child: PdfViewer(
        asset != null
            ? PdfDocumentRefAsset(asset, useProgressiveLoading: false)
            : PdfDocumentRefUri(
                widget.delivery.uri,
                useProgressiveLoading: false,
              ),
        controller: pdf,
        initialPageNumber: page,
        params: PdfViewerParams(
          backgroundColor: const Color(0xFFE9EEF3),
          margin: 18,
          // Start at the text, not the blank lower margin of the last page.
          pageAnchorEnd: PdfPageAnchor.top,
          onViewSizeChanged: (size, previousSize, controller) {
            if (previousSize == null || size == previousSize) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fitPdfWidth();
            });
          },
          onViewerReady: (document, controller) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => pages = document.pages.length);
            });
            notify(true);
          },
          onPageChanged: (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && value != null) {
                setState(() => page = value);
                widget.onPageChanged?.call(value);
              }
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
    );
  }
}
