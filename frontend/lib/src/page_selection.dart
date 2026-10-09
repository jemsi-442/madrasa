import 'package:flutter/material.dart';
import 'app_layout.dart';
import 'keyboard_scrolling.dart';

/// Covers named routes, pushed lesson readers and dialogs with one copy region.
class PageSelection extends StatefulWidget {
  const PageSelection({super.key, required this.child});
  final Widget child;

  @override
  State<PageSelection> createState() => _PageSelectionState();
}

class _PageSelectionState extends State<PageSelection> {
  // MaterialApp.builder sits above Navigator's overlay. Selection handles and
  // the Copy menu need their own ancestor overlay at this shared level.
  late final entry = OverlayEntry(
    builder: (context) => SelectionArea(
      child: Shortcuts(
        shortcuts: AppLayoutScope.isMobile(context)
            ? const {}
            : pageKeyboardShortcuts,
        child: widget.child,
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant PageSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  @override
  void dispose() {
    entry.remove();
    entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [entry]);
}
