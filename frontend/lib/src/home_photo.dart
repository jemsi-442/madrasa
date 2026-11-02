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
        errorBuilder: (context, error, stack) => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Photo unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF405772), fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );
}
