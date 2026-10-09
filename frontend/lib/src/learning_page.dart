import 'package:flutter/material.dart';
import 'foundation_ui.dart';
import 'page_selection.dart';

/// An ordinary in-app page, not an overlay on another learning window.
class LearningPage extends StatelessWidget {
  const LearningPage({
    super.key,
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.child,
  });

  final String title, backLabel;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => PageSelection(
    child: Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: line)),
        leading: IconButton(
          tooltip: backLabel,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 700)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'LEARNING SPACE',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          primary: true,
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}
