import 'package:flutter/material.dart';

class PdfControlGroup extends StatelessWidget {
  const PdfControlGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6F9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE1E7EE)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// Shared document presentation; PDF rendering stays with the reader itself.
class PdfReadingFrame extends StatelessWidget {
  const PdfReadingFrame({
    super.key,
    required this.title,
    required this.toolbar,
    required this.child,
    this.onClose,
  });

  final String title;
  final Widget toolbar, child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(onClose == null ? 16 : 0),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF3),
        border: Border.all(color: const Color(0xFFD9E1E9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF06243C), Color(0xFF193E53)],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFB68A29), width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB68A29),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PDF DOCUMENT',
                        style: TextStyle(
                          color: Color(0xFFE9C978),
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Close PDF viewer',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFD9E1E9))),
            ),
            child: toolbar,
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
