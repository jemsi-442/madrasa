import 'package:flutter/material.dart';

import 'foundation_ui.dart';
import 'public_shell.dart';
import 'media_player_preview.dart';

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
  });
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final String roleLabel;
  final bool collapsed;
  final bool primary;
  final Map<int, String> groups;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF011F3D), Color(0xFF163449)],
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
                  : const PublicBrand(compact: true),
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
                          fontSize: 10,
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
                            fontSize: 10,
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
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: ValueKey('nav-$index'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onSelect(index),
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
                                            fontSize: 14,
                                            fontWeight: selected == index
                                                ? FontWeight.w700
                                                : FontWeight.w400,
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
            if (!collapsed)
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
                        fontSize: 12,
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
    required this.collapsed,
  });
  final String fullName;
  final String roleLabel;
  final String pageTitle;
  final IconData pageIcon;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final bool collapsed;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            onPressed: onToggle,
            icon: const Icon(Icons.menu_rounded, color: ink),
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
          IconButton(
            tooltip: 'Refresh page',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: ink),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'media-preview') {
                openMediaPlayerPreview(context);
              } else if (value == 'sign-out') {
                onSignOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'media-preview',
                child: Text('Try media player'),
              ),
              PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFF3EBD8),
                    child: Text(
                      fullName.trim().isEmpty
                          ? '?'
                          : fullName.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          roleLabel,
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: ink),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
