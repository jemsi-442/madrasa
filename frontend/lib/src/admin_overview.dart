import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'dashboard_components.dart';
import 'donations_page.dart' show AdminPanelGrid, monthName;
import 'foundation_ui.dart';

class AdminOverview extends StatelessWidget {
  const AdminOverview({
    super.key,
    required this.report,
    required this.onOpen,
    this.submit,
    this.onChanged,
  });
  final Map<String, dynamic> report;
  final ValueChanged<int> onOpen;
  final PageSubmitter? submit;
  final VoidCallback? onChanged;

  Future<void> addEvent(BuildContext context) async {
    if (submit == null) return;
    final saved = await showAdminForm(
      context,
      title: 'Add event',
      fields: const [
        AdminField('title', 'Event name'),
        AdminField('location', 'Location'),
        AdminField('startsAt', 'Starts', kind: 'datetime'),
        AdminField('endsAt', 'Ends', kind: 'datetime'),
      ],
      onSave: (body) async {
        await submit!('/api/admin/events', body);
      },
    );
    if (saved) onChanged?.call();
  }

  Future<void> cancelEvent(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    if (submit == null) return;
    final saved = await showAdminForm(
      context,
      title: 'Cancel event?',
      note: '${event['title']} will be removed from upcoming events.',
      fields: const [],
      saveLabel: 'Cancel event',
      onSave: (_) async {
        await submit!('/api/admin/events/${event['id']}/cancel', {});
      },
    );
    if (saved) onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final academic = recordMap(report['academic']);
    final funding = recordMap(report['fundraising']);
    final students = recordMap(report['students']);
    final hifdh = recordMap(report['hifdh']);
    final attendance = recordMap(report['attendance']);
    final assessed = recordNumber(academic['assessedStudents']);
    final activities = recordList(academic['activities']);
    final events = recordList(academic['events']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 1150
                ? 6
                : c.maxWidth >= 760
                ? 3
                : c.maxWidth >= 340
                ? 2
                : 1;
            final cards = [
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Total students',
                value: recordText(students['total'], '0'),
                icon: Icons.groups_outlined,
                accent: blue,
                note: 'Registered students',
              ),
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Classes',
                value: recordText(academic['classes'], '0'),
                icon: Icons.menu_book_outlined,
                accent: forest,
                note: 'Across academic years',
              ),
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Teachers',
                value: recordText(academic['teachers'], '0'),
                icon: Icons.person_outline,
                accent: gold,
                note: 'Active accounts',
              ),
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Attendance rate',
                value: recordNumber(attendance['totalRecords']) > 0
                    ? '${attendance['attendanceRate']}%'
                    : '-',
                icon: Icons.event_available_outlined,
                accent: const Color(0xFFBE4A5C),
                note: 'All saved records',
              ),
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Subjects',
                value: recordText(academic['subjects'], '0'),
                icon: Icons.layers_outlined,
                accent: lavender,
                note: 'Active in the catalog',
              ),
              DashboardMetric(
                dense: c.maxWidth >= 760,
                label: 'Donors',
                value: recordText(funding['totalDonors'], '0'),
                icon: Icons.volunteer_activism_outlined,
                accent: ink,
                note: 'Registered supporters',
              ),
            ];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: (c.maxWidth - (columns - 1) * 14) / columns,
                    child: card,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        AdminPanelGrid(
          children: [
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    'Student admissions',
                    subtitle: 'New registrations - last 6 months',
                  ),
                  ColumnChart(
                    height: 180,
                    items: [
                      for (final r in recordList(academic['admissions']))
                        ChartDatum(
                          monthName(r['month']),
                          recordNumber(r['count']),
                          ink,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading(
                    "Qur'an tracking",
                    subtitle: 'Students with recorded assessments',
                  ),
                  RingChart(
                    center: '$assessed',
                    caption: 'Assessed students',
                    items: [
                      ChartDatum('Assessed', assessed, forest),
                      ChartDatum(
                        'Not assessed',
                        (recordNumber(students['total']) - assessed).clamp(
                          0,
                          double.infinity,
                        ),
                        const Color(0xFFDCE2E8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Average memorization score: ${recordNumber(hifdh['totalAssessments']) == 0 ? '-' : '${recordText(hifdh['averageMemorizationScore'])}/100'}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading('Recent activity'),
                  if (activities.isEmpty)
                    const EmptyRecords('New activity will appear here.'),
                  for (final activity in activities)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: forest.withValues(alpha: .1),
                        child: Icon(
                          activity['page'] == 'Donations'
                              ? Icons.favorite_outline
                              : Icons.person_outline,
                          color: forest,
                          size: 19,
                        ),
                      ),
                      title: Text(
                        recordText(activity['title']),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        recordText(activity['detail']),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        shortDate(activity['at']),
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                      onTap: () => onOpen(
                        activity['page'] == 'Donations'
                            ? 6
                            : activity['page'] == 'Teachers'
                            ? 3
                            : 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AdminPanelGrid(
          children: [
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelHeading(
                    'Donations overview',
                    action: TextButton(
                      onPressed: () => onOpen(6),
                      child: const Text('View all'),
                    ),
                  ),
                  Text(
                    'TZS ${moneyText(funding['collectedAmount'])}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const Text(
                    'Total received, excluding voided entries',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ColumnChart(
                    height: 180,
                    items: [
                      for (final r in recordList(funding['trend']))
                        ChartDatum(
                          monthName(r['month']),
                          recordNumber(r['amount']),
                          gold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PanelHeading('Quick actions'),
                  for (final item in const [
                    (
                      1,
                      'Students',
                      'Admissions and guardian details',
                      Icons.person_add_alt,
                      blue,
                    ),
                    (
                      2,
                      'Classes',
                      'Class lists and assignments',
                      Icons.menu_book_outlined,
                      forest,
                    ),
                    (
                      5,
                      'Attendance',
                      'Daily attendance records',
                      Icons.event_available_outlined,
                      gold,
                    ),
                    (
                      6,
                      'Donations',
                      'Donors, campaigns and receipts',
                      Icons.favorite_outline,
                      lavender,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: item.$5.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(9),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          leading: Icon(item.$4, color: item.$5),
                          title: Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            item.$3,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => onOpen(item.$1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelHeading(
                    'Upcoming events',
                    action: submit == null
                        ? null
                        : IconButton(
                            tooltip: 'Add event',
                            onPressed: () => addEvent(context),
                            icon: const Icon(Icons.add, color: gold),
                          ),
                  ),
                  if (events.isEmpty) const EmptyRecords('No upcoming events.'),
                  for (final event in events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${DateTime.tryParse('${event['startsAt']}')?.toLocal().day ?? '-'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recordText(event['title']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shortDate(event['startsAt']),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                  ),
                                ),
                                if (DateTime.tryParse('${event['startsAt']}') !=
                                    null)
                                  Text(
                                    TimeOfDay.fromDateTime(
                                      DateTime.parse(
                                        '${event['startsAt']}',
                                      ).toLocal(),
                                    ).format(context),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                Text(
                                  recordText(event['location']),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (submit != null)
                            PopupMenuButton<String>(
                              tooltip: 'Event actions',
                              onSelected: (_) => cancelEvent(context, event),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Cancel event'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
