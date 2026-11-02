import 'package:flutter/material.dart';

/// Reserve the photograph's space before decoding so nearby content stays put.
class HomePhoto extends StatelessWidget {
  const HomePhoto({
    super.key,
    required this.asset,
    required this.description,
    required this.aspectRatio,
  });

  final String asset, description;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: ColoredBox(
      color: const Color(0xFFEAF0F5),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        semanticLabel: description,
        frameBuilder: (context, child, frame, synchronous) =>
            synchronous || frame != null
            ? child
            : _PhotoStatus(description: description, loading: true),
        errorBuilder: (context, error, stack) =>
            _PhotoStatus(description: description, loading: false),
      ),
    ),
  );
}

class _PhotoStatus extends StatelessWidget {
  const _PhotoStatus({required this.description, required this.loading});
  final String description;
  final bool loading;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${loading ? 'Loading photo' : 'Photo unavailable'}: $description',
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showText =
              constraints.maxWidth >= 180 && constraints.maxHeight >= 100;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      loading
                          ? Icons.photo_outlined
                          : Icons.hide_image_outlined,
                      size: 32,
                      color: const Color(0xFF405772),
                    ),
                    if (showText) ...[
                      const SizedBox(height: 10),
                      Text(
                        loading ? 'Loading photo' : 'Photo unavailable',
                        style: const TextStyle(
                          color: Color(0xFF405772),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
