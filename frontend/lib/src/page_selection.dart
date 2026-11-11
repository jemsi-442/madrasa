import 'package:flutter/material.dart';
import 'app_layout.dart';
import 'keyboard_scrolling.dart';

/// Keep selection inside a route's overlay so web platform views stack correctly.
class PageSelection extends StatelessWidget {
  const PageSelection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Initial deep links can build a covered route without laying it out.
    // Register selectable content only once its route participates in layout.
    builder: (context, constraints) => SelectionArea(
      child: Shortcuts(
        shortcuts: AppLayoutScope.isMobile(context)
            ? const {}
            : pageKeyboardShortcuts,
        child: child,
      ),
    ),
  );
}
