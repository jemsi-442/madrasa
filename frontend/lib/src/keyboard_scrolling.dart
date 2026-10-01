import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Map<ShortcutActivator, Intent> get pageKeyboardShortcuts => {
  ...WidgetsApp.defaultShortcuts,
  const SingleActivator(LogicalKeyboardKey.home): const PageBoundaryIntent(
    false,
  ),
  const SingleActivator(LogicalKeyboardKey.end): const PageBoundaryIntent(true),
  const SingleActivator(LogicalKeyboardKey.home, control: true):
      const PageBoundaryIntent(false),
  const SingleActivator(LogicalKeyboardKey.end, control: true):
      const PageBoundaryIntent(true),
  const SingleActivator(LogicalKeyboardKey.space): const PrioritizedIntents(
    orderedIntents: [
      ActivateIntent(),
      ScrollIntent(
        direction: AxisDirection.down,
        type: ScrollIncrementType.page,
      ),
    ],
  ),
  const SingleActivator(
    LogicalKeyboardKey.space,
    shift: true,
  ): const PrioritizedIntents(
    orderedIntents: [
      ActivateIntent(),
      ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    ],
  ),
};

Map<Type, Action<Intent>> get pageKeyboardActions => {
  ...WidgetsApp.defaultActions,
  ScrollIntent: PageScrollAction(),
  PageBoundaryIntent: PageBoundaryAction(),
};

ScrollableState? _scrollTarget(BuildContext? context, Axis axis) {
  if (context == null) return null;
  bool canScroll(ScrollableState state) =>
      state.position.hasContentDimensions &&
      state.position.physics.shouldAcceptUserOffset(state.position);

  // A focused table/chart must not swallow vertical page scrolling.
  var scrollable = Scrollable.maybeOf(context, axis: axis);
  while (scrollable != null) {
    if (canScroll(scrollable)) return scrollable;
    scrollable = Scrollable.maybeOf(scrollable.context, axis: axis);
  }
  final primary = PrimaryScrollController.maybeOf(context);
  if (primary == null || primary.positions.length != 1) return null;
  final target = primary.position.context.notificationContext;
  if (target == null) return null;
  scrollable = Scrollable.maybeOf(target, axis: axis);
  return scrollable != null && canScroll(scrollable) ? scrollable : null;
}

void _move(ScrollableState target, double offset, BuildContext context) {
  target.position.moveTo(
    offset,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 100),
    curve: Curves.easeInOut,
  );
}

class PageScrollAction extends ContextAction<ScrollIntent> {
  @override
  bool isEnabled(ScrollIntent intent, [BuildContext? context]) =>
      _scrollTarget(context, axisDirectionToAxis(intent.direction)) != null;

  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    final target = _scrollTarget(
      context,
      axisDirectionToAxis(intent.direction),
    );
    if (target == null || context == null) return;
    _move(
      target,
      target.position.pixels +
          ScrollAction.getDirectionalIncrement(target, intent),
      context,
    );
  }
}

class PageBoundaryIntent extends Intent {
  const PageBoundaryIntent(this.end);
  final bool end;
}

class PageBoundaryAction extends ContextAction<PageBoundaryIntent> {
  @override
  bool isEnabled(PageBoundaryIntent intent, [BuildContext? context]) =>
      _scrollTarget(context, Axis.vertical) != null;

  @override
  void invoke(PageBoundaryIntent intent, [BuildContext? context]) {
    final target = _scrollTarget(context, Axis.vertical);
    if (target == null || context == null) return;
    final max = intent.end == (target.axisDirection == AxisDirection.down);
    _move(
      target,
      max ? target.position.maxScrollExtent : target.position.minScrollExtent,
      context,
    );
  }
}

class KeyboardScrollScope extends StatefulWidget {
  const KeyboardScrollScope({super.key, required this.child});
  final Widget child;

  @override
  State<KeyboardScrollScope> createState() => _KeyboardScrollScopeState();
}

class _KeyboardScrollScopeState extends State<KeyboardScrollScope> {
  final controller = ScrollController();
  final focus = FocusNode(debugLabel: 'Independent scroll content');

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: controller,
    child: Focus(
      focusNode: focus,
      autofocus: true,
      skipTraversal: true,
      child: widget.child,
    ),
  );
}
