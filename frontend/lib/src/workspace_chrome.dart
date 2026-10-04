import 'package:flutter/material.dart';

import 'foundation_ui.dart';
import 'public_shell.dart';

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
    this.onFindPage,
  });
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final String roleLabel;
  final bool collapsed;
  final bool primary;
  final Map<int, String> groups;
  final VoidCallback? onFindPage;

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
                  if (onFindPage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Tooltip(
                        message: 'Find a page',
                        child: InkWell(
                          onTap: onFindPage,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: collapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                if (!collapsed) ...[
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Find a page',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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

Future<int?> showWorkspacePageSearch(
  BuildContext context, {
  required List<(String, IconData)> items,
  List<String> descriptions = const [],
  int? selected,
}) => showDialog<int>(
  context: context,
  builder: (_) =>
      _PageSearch(items: items, descriptions: descriptions, selected: selected),
);

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.fullName,
    required this.roleLabel,
    required this.items,
    required this.onSelect,
    required this.onToggle,
    required this.onRefresh,
    required this.onSignOut,
    required this.collapsed,
    this.descriptions = const [],
    this.selected,
  });
  final String fullName;
  final String roleLabel;
  final List<(String, IconData)> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final bool collapsed;

  final List<String> descriptions;
  final int? selected;

  Future<void> findPage(BuildContext context) async {
    final result = await showWorkspacePageSearch(
      context,
      items: items,
      descriptions: descriptions,
      selected: selected,
    );
    if (result != null && context.mounted) onSelect(result);
  }

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
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Material(
                  color: const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => findPage(context),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: muted, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Find a page...',
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
            onSelected: (_) => onSignOut(),
            itemBuilder: (_) => const [
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

class _PageSearch extends StatefulWidget {
  const _PageSearch({
    required this.items,
    required this.descriptions,
    this.selected,
  });
  final List<(String, IconData)> items;
  final List<String> descriptions;
  final int? selected;
  @override
  State<_PageSearch> createState() => _PageSearchState();
}

class _PageSearchState extends State<_PageSearch> {
  String query = '';
  bool matches(int index) =>
      ('${widget.items[index].$1} ${index < widget.descriptions.length ? widget.descriptions[index] : ''}')
          .toLowerCase()
          .contains(query.trim());
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Find a page'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search a page or task',
            ),
            onChanged: (value) => setState(() => query = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              primary: true,
              child: Column(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    if (matches(i))
                      ListTile(
                        leading: Icon(widget.items[i].$2, color: gold),
                        title: Text(widget.items[i].$1),
                        subtitle: i < widget.descriptions.length
                            ? Text(widget.descriptions[i])
                            : null,
                        selected: widget.selected == i,
                        trailing: widget.selected == i
                            ? const Tooltip(
                                message: 'Current page',
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                ),
                              )
                            : const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.pop(context, i),
                      ),
                  if (!List.generate(
                    widget.items.length,
                    (i) => i,
                  ).any(matches))
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No matching pages.'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
