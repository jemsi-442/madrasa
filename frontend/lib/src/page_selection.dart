import 'package:flutter/material.dart';
import 'app_layout.dart';
import 'keyboard_scrolling.dart';

/// Keep selection inside a route's overlay so web platform views stack correctly.
class PageSelection extends StatelessWidget {
  const PageSelection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Shortcuts(
      shortcuts: AppLayoutScope.isMobile(context)
          ? const {}
          : pageKeyboardShortcuts,
      child: child,
    ),
  );
}
