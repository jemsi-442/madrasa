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
    this.closeLabel = 'Close PDF viewer',
    this.closeIcon = Icons.close,
  });

  final String title;
  final Widget toolbar, child;
  final VoidCallback? onClose;
  final String closeLabel;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 520;
      return ClipRRect(
        borderRadius: BorderRadius.circular(onClose == null ? 16 : 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF3),
            border: Border.all(color: const Color(0xFFD9E1E9)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 18,
                  vertical: compact ? 8 : 16,
                ),
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
                      padding: EdgeInsets.all(compact ? 6 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB68A29),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Colors.white,
                        size: compact ? 22 : 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!compact)
                            const Text(
                              'PDF DOCUMENT',
                              style: TextStyle(
                                color: Color(0xFFE9C978),
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (!compact) const SizedBox(height: 5),
                          Text(
                            title,
                            maxLines: compact ? 1 : 2,
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
                        tooltip: closeLabel,
                        onPressed: onClose,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(closeIcon),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: compact ? 4 : 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFD9E1E9))),
                ),
                // On short screens keep controls in one horizontally scrollable
                // strip rather than consuming the document's reading height.
                child: compact
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: toolbar,
                      )
                    : toolbar,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    },
  );
}
