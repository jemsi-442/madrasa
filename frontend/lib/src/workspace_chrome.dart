import 'package:flutter/material.dart';
import 'design_tokens.dart';

import 'foundation_ui.dart';
import 'public_shell.dart';
import 'media_player_preview.dart';

enum SidebarControl { open, close, expand, collapse }

class WorkspaceAccountMenu extends StatelessWidget {
  const WorkspaceAccountMenu({
    super.key,
    required this.fullName,
    required this.roleLabel,
    required this.onSignOut,
    this.email,
    this.phone,
    this.onChangePassword,
    this.onSignOutAll,
    this.onSessions,
    this.onMediaPreview,
    this.compact = false,
    this.enabled = true,
  });

  final String fullName, roleLabel;
  final String? email, phone;
  final VoidCallback onSignOut;
  final VoidCallback? onChangePassword,
      onSignOutAll,
      onSessions,
      onMediaPreview;
  final bool compact, enabled;

  @override
  Widget build(BuildContext context) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final initials = parts
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 320.0);
    Widget info(IconData icon, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AfaqDesign.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AfaqDesign.ink),
            ),
          ),
        ],
      ),
    );
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        elevation: const WidgetStatePropertyAll(12),
        alignment: Alignment.bottomRight,
      ),
      builder: (context, controller, _) {
        return Tooltip(
          message: 'Account menu',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: !enabled
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xfff8f0da),
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: AfaqDesign.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AfaqDesign.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AfaqDesign.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Builder(
              builder: (menuContext) {
                Widget action(
                  String label,
                  IconData icon,
                  VoidCallback callback,
                ) => MenuItemButton(
                  onPressed: callback,
                  leadingIcon: Icon(icon, size: 20),
                  child: Text(label),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'User info',
                      style: TextStyle(
                        color: AfaqDesign.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    info(Icons.person_outline, fullName),
                    if (email?.trim().isNotEmpty == true)
                      info(Icons.mail_outline, email!),
                    if (phone?.trim().isNotEmpty == true)
                      info(Icons.phone_outlined, phone!),
                    info(Icons.badge_outlined, roleLabel),
                    const Divider(height: 24),
                    if (onSessions != null) ...[
                      const Text(
                        'Activity',
                        style: TextStyle(color: AfaqDesign.muted),
                      ),
                      action(
                        'My sessions',
                        Icons.devices_outlined,
                        onSessions!,
                      ),
                      const Divider(height: 16),
                    ],
                    const Text(
                      'Actions',
                      style: TextStyle(color: AfaqDesign.muted),
                    ),
                    const SizedBox(height: 8),
                    if (onChangePassword != null)
                      action(
                        'Change password',
                        Icons.lock_outline,
                        onChangePassword!,
                      ),
                    if (onMediaPreview != null)
                      action(
                        'Try media player',
                        Icons.play_circle_outline,
                        onMediaPreview!,
                      ),
                    action('Sign out', Icons.logout, onSignOut),
                    if (onSignOutAll != null)
                      action(
                        'Sign out all sessions',
                        Icons.exit_to_app,
                        onSignOutAll!,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared by every authenticated workspace, outside individual page content.
class WorkspaceFooter extends StatelessWidget {
  const WorkspaceFooter({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: AfaqDesign.canvas,
    child: SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('workspace-footer'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffe2e7eb))),
        ),
        child: Text(
          '\u00a9 ${DateTime.now().year} Afaq. All rights reserved.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AfaqDesign.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    ),
  );
}

class WorkspaceRefreshButton extends StatelessWidget {
  const WorkspaceRefreshButton({
    super.key,
    required this.onRefresh,
    this.loading = false,
    this.tooltip = 'Refresh page',
    this.label,
  });
  final VoidCallback onRefresh;
  final bool loading;
  final String tooltip;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final icon = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Refreshing',
              color: ink,
            ),
          )
        : const Icon(Icons.refresh_rounded, color: ink);
    if (label != null) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onRefresh,
        icon: icon,
        label: Text(label!),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onRefresh,
      icon: icon,
    );
  }
}

/// Both school and platform shells resize content using the same rail geometry.
class WorkspaceDesktopSidebar extends StatelessWidget {
  const WorkspaceDesktopSidebar({
    super.key,
    required this.collapsed,
    required this.child,
  });
  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: collapsed ? AfaqDesign.sidebarRailWidth : AfaqDesign.sidebarWidth,
    child: child,
  );
}

class WorkspaceSidebarToggle extends StatelessWidget {
  const WorkspaceSidebarToggle({
    super.key,
    required this.control,
    required this.onPressed,
  });
  final SidebarControl control;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: switch (control) {
      SidebarControl.open => 'Open navigation',
      SidebarControl.close => 'Close navigation',
      SidebarControl.expand => 'Expand sidebar',
      SidebarControl.collapse => 'Collapse sidebar',
    },
    onPressed: onPressed,
    icon: Icon(switch (control) {
      SidebarControl.open => Icons.menu_rounded,
      SidebarControl.close => Icons.close_rounded,
      SidebarControl.expand => Icons.menu_rounded,
      SidebarControl.collapse => Icons.menu_rounded,
    }, color: ink),
  );
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.roleLabel,
    this.collapsed = false,
    this.primary = false,
    this.groups = const {},
    this.enabled = true,
    this.onClose,
  });
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final String roleLabel;
  final bool collapsed;
  final bool primary;
  final bool enabled;
  final VoidCallback? onClose;
  final Map<int, String> groups;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AfaqDesign.ink, AfaqDesign.sidebarEnd],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 76,
              color: Colors.white,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 24),
              child: collapsed
                  ? const Tooltip(
                      message: publicBrandName,
                      child: Icon(Icons.school_outlined, color: ink, size: 28),
                    )
                  : Row(
                      children: [
                        const Expanded(child: PublicBrand(compact: true)),
                        if (onClose != null)
                          WorkspaceSidebarToggle(
                            control: SidebarControl.close,
                            onPressed: onClose!,
                          ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView(
                primary: primary,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 12,
                ),
                children: [
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: Text(
                        roleLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF99ADBF),
                          fontSize: AfaqDesign.secondarySize,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  for (var index = 0; index < items.length; index++) ...[
                    if (!collapsed && groups.containsKey(index))
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          index == 0 ? 0 : 16,
                          12,
                          10,
                        ),
                        child: Text(
                          groups[index]!.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF99ADBF),
                            fontSize: AfaqDesign.secondarySize,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tooltip(
                        message: collapsed ? items[index].$1 : '',
                        child: Semantics(
                          selected: selected == index,
                          child: Material(
                            color: selected == index
                                ? gold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AfaqDesign.controlRadius,
                            ),
                            child: InkWell(
                              key: ValueKey('nav-$index'),
                              borderRadius: BorderRadius.circular(
                                AfaqDesign.controlRadius,
                              ),
                              onTap: enabled ? () => onSelect(index) : null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: collapsed ? 8 : 16,
                                  vertical: 15,
                                ),
                                child: Row(
                                  mainAxisAlignment: collapsed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      items[index].$2,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    if (!collapsed) ...[
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Text(
                                          items[index].$1,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: AfaqDesign.bodySize,
                                            fontWeight: selected == index
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!collapsed && MediaQuery.sizeOf(context).height >= 640)
              const Padding(
                padding: EdgeInsets.fromLTRB(26, 0, 26, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: Color(0xFF425B70)),
                    SizedBox(height: 18),
                    Icon(
                      Icons.auto_stories_outlined,
                      color: Color(0xFFDFC184),
                      size: 26,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Knowledge today.\nBrighter tomorrows.',
                      style: TextStyle(
                        color: Color(0xFFD2DDE6),
                        fontSize: AfaqDesign.secondarySize,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Shared header surface; each role supplies only its content and actions.
class WorkspaceHeaderSurface extends StatelessWidget {
  const WorkspaceHeaderSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: AfaqDesign.headerHeight),
    padding: padding,
    decoration: const BoxDecoration(
      color: AfaqDesign.surface,
      border: Border(bottom: BorderSide(color: AfaqDesign.border)),
    ),
    child: child,
  );
}

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.fullName,
    required this.roleLabel,
    required this.pageTitle,
    required this.pageIcon,
    required this.onToggle,
    required this.onRefresh,
    required this.onSignOut,
    this.onChangePassword,
    required this.collapsed,
  });
  final String fullName;
  final String roleLabel;
  final String pageTitle;
  final IconData pageIcon;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final VoidCallback? onChangePassword;
  final bool collapsed;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: WorkspaceHeaderSurface(
      child: Row(
        children: [
          WorkspaceSidebarToggle(
            control: collapsed
                ? SidebarControl.expand
                : SidebarControl.collapse,
            onPressed: onToggle,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Icon(pageIcon, color: gold, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pageTitle,
                    key: const ValueKey('workspace-page-label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          WorkspaceRefreshButton(onRefresh: onRefresh),
          const SizedBox(width: 12),
          WorkspaceAccountMenu(
            fullName: fullName,
            roleLabel: roleLabel,
            onSignOut: onSignOut,
            onChangePassword: onChangePassword,
            onMediaPreview: () => openMediaPlayerPreview(context),
          ),
        ],
      ),
    ),
  );
}
