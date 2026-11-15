import 'package:flutter/material.dart';
import 'app_layout.dart';
import 'keyboard_scrolling.dart';

/// Keep selection inside a route's overlay so web platform views stack correctly.
class PageSelection extends StatefulWidget {
  const PageSelection({super.key, required this.child});
  final Widget child;

  @override
  State<PageSelection> createState() => _PageSelectionState();
}

class _PageSelectionState extends State<PageSelection> {
  final selection = StaticSelectionContainerDelegate();
  final selectionAreaKey = GlobalKey<SelectionAreaState>();
  bool routeCurrent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current != routeCurrent) {
      if (!current) {
        selectionAreaKey.currentState?.selectableRegion.clearSelection();
      }
      routeCurrent = current;
    }
  }

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Shortcuts(
      shortcuts: AppLayoutScope.isMobile(context)
          ? const {}
          : pageKeyboardShortcuts,
      child: widget.child,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SelectionArea(
        key: selectionAreaKey,
        // Covered routes may receive background updates without layout. Keep
        // their text out of selection sorting, but preserve the form subtree.
        child: Builder(
          builder: (context) => routeCurrent
              ? SelectionContainer(
                  // Reattach explicitly: re-enabling a disabled container does
                  // not itself trigger an inherited registrar update.
                  registrar: SelectionContainer.maybeOf(context),
                  delegate: selection,
                  child: content,
                )
              : SelectionContainer.disabled(child: content),
        ),
      ),
    );
  }
}
