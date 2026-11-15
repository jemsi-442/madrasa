import 'package:flutter/material.dart';
import 'admin_forms.dart' show shortDate;
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_ui.dart';

String schoolUpdateStatus(Map<String, dynamic> row, DateTime now) {
  final publish = DateTime.tryParse('${row['publishAt']}');
  final expiry = DateTime.tryParse('${row['expiresAt']}');
  if (expiry != null && expiry.isBefore(now)) return 'Expired';
  if (publish != null && publish.isAfter(now)) return 'Scheduled';
  return publish == null ? 'Unknown' : 'Published';
}

class SchoolUpdatesPage extends StatefulWidget {
  const SchoolUpdatesPage({
    super.key,
    required this.load,
    this.refreshToken = 0,
  });
  final PageLoader load;
  final int refreshToken;

  @override
  State<SchoolUpdatesPage> createState() => _SchoolUpdatesPageState();
}

class _SchoolUpdatesPageState extends State<SchoolUpdatesPage> {
  String query = '', audience = '', status = '';
  int page = 0, refresh = 0;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String audienceLabel(Map<String, dynamic> row) =>
      row['audience'] == 'TEACHERS' ? 'Teacher audience only' : 'School-wide';

  void open(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recordText(row['title'])),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TeacherTag(audienceLabel(row), color: blue),
                const SizedBox(height: 12),
                Text(
                  '${schoolUpdateStatus(row, DateTime.now()) == 'Scheduled' ? 'Scheduled for' : 'Published'}: ${shortDate(row['publishAt'])}',
                  style: const TextStyle(color: muted),
                ),
                if (row['expiresAt'] != null)
                  Text(
                    'Expires: ${shortDate(row['expiresAt'])}',
                    style: const TextStyle(color: muted),
                  ),
                const Divider(height: 32),
                SelectableText(
                  recordText(row['message']),
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TeacherData(
    load: widget.load,
    path: '/api/announcements',
    refreshToken: widget.refreshToken + refresh,
    builder: (data) {
      final rows = recordList(data);
      final now = DateTime.now();
      final filtered = rows
          .where(
            (r) =>
                (audience.isEmpty || r['audience'] == audience) &&
                (status.isEmpty || schoolUpdateStatus(r, now) == status) &&
                '${r['title']} ${r['message']}'.toLowerCase().contains(query),
          )
          .toList();
      final pages = (filtered.length / 10).ceil().clamp(1, 1000000);
      final current = page.clamp(0, pages - 1);
      final visible = filtered.skip(current * 10).take(10).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'School Updates',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Notices and announcements shared by your school office.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 1000
                  ? 4
                  : bounds.maxWidth >= 540
                  ? 2
                  : 1;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final (label, icon, color) in [
                    ('Total updates', Icons.campaign_outlined, blue),
                    ('Published', Icons.check_circle_outline, forest),
                    ('Scheduled', Icons.schedule, gold),
                    (
                      'Expired',
                      Icons.inventory_2_outlined,
                      const Color(0xFFB64A56),
                    ),
                  ])
                    SizedBox(
                      width: (bounds.maxWidth - 14 * (columns - 1)) / columns,
                      child: TeacherMetric(
                        label,
                        '${label == 'Total updates' ? rows.length : rows.where((r) => schoolUpdateStatus(r, now) == label).length}',
                        'Updates available to you',
                        icon,
                        color,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: bounds.maxWidth < 380 ? bounds.maxWidth : 380,
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      hintText: 'Search updates...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() {
                      query = value.trim().toLowerCase();
                      page = 0;
                    }),
                  ),
                ),
                for (final isAudience in [true, false])
                  SizedBox(
                    width: bounds.maxWidth < 250 ? bounds.maxWidth : 250,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: isAudience ? audience : status,
                      decoration: InputDecoration(
                        labelText: isAudience ? 'Audience' : 'Status',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            isAudience
                                ? 'All available audiences'
                                : 'All statuses',
                          ),
                        ),
                        if (isAudience) ...[
                          const DropdownMenuItem(
                            value: 'TEACHERS',
                            child: Text('Teachers'),
                          ),
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text('School-wide'),
                          ),
                        ] else
                          for (final value in [
                            'Published',
                            'Scheduled',
                            'Expired',
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) => setState(() {
                        if (isAudience) {
                          audience = value ?? '';
                        } else {
                          status = value ?? '';
                        }
                        page = 0;
                      }),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => refresh++),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (visible.isEmpty)
            const SurfacePanel(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.campaign_outlined, size: 48, color: blue),
                    SizedBox(height: 14),
                    Text(
                      'No updates match these filters.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try another search or audience.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                for (final row in visible)
                  SizedBox(
                    width: bounds.maxWidth >= 900
                        ? (bounds.maxWidth - 16) / 2
                        : bounds.maxWidth,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => open(row),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.campaign_outlined,
                                color: blue,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recordText(row['title']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      audienceLabel(row),
                                      style: const TextStyle(color: muted),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        TeacherTag(
                                          schoolUpdateStatus(row, now),
                                          color:
                                              schoolUpdateStatus(row, now) ==
                                                  'Published'
                                              ? forest
                                              : gold,
                                        ),
                                        Text(
                                          shortDate(row['publishAt']),
                                          style: const TextStyle(color: muted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: blue),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${filtered.length} updates | Page ${current + 1} of $pages',
              ),
              OutlinedButton(
                onPressed: current == 0
                    ? null
                    : () => setState(() => page = current - 1),
                child: const Text('Previous'),
              ),
              OutlinedButton(
                onPressed: current + 1 >= pages
                    ? null
                    : () => setState(() => page = current + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
