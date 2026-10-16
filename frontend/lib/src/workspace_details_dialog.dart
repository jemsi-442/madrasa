import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';
import 'workspace_form_dialog.dart';

/// Shared page/dialog section, not tied to a popup or a particular role.
class WorkspaceDetailsSection extends StatelessWidget {
  const WorkspaceDetailsSection({
    super.key,
    required this.title,
    required this.child,
    this.icon = Icons.info_outline,
  });
  final String title;
  final Widget child;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AfaqDesign.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AfaqDesign.actionGold.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AfaqDesign.actionGold, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        child,
      ],
    ),
  );
}

class WorkspaceRecordHeading extends StatelessWidget {
  const WorkspaceRecordHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final compact =
          bounds.maxWidth < 640 ||
          MediaQuery.textScalerOf(context).scale(15) > 22;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AfaqDesign.bodyFont,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AfaqDesign.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: AfaqDesign.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (compact && trailing != null) ...[
            const SizedBox(height: 14),
            trailing!,
          ],
        ],
      );
      if (compact || trailing == null) return heading;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 24),
          trailing!,
        ],
      );
    },
  );
}

/// Consistent read-only record presentation, also usable inside action forms.
class WorkspaceRecordDetails extends StatelessWidget {
  const WorkspaceRecordDetails({
    super.key,
    required this.fields,
    this.statusFields = const {},
  });
  final List<(String, String)> fields;
  final Set<String> statusFields;

  Widget status(String value) {
    final (color, icon) = switch (value) {
      'ACTIVE' => (AfaqDesign.green, Icons.check_circle_outline),
      'DISABLED' ||
      'SUSPENDED' => (const Color(0xffb42336), Icons.block_outlined),
      'PENDING_ACTIVATION' ||
      'TRIAL' => (AfaqDesign.actionGold, Icons.schedule_outlined),
      _ => (AfaqDesign.muted, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: SelectableText(
              value.trim().isEmpty
                  ? 'Not recorded'
                  : value.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final largeText = MediaQuery.textScalerOf(context).scale(15) > 22;
      final columns = largeText
          ? 1
          : bounds.maxWidth >= 1000
          ? 3
          : bounds.maxWidth >= 480
          ? 2
          : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final field in fields)
            SizedBox(
              width: (bounds.maxWidth - (columns - 1) * 12) / columns,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fc),
                  border: Border.all(color: const Color(0xffe2e7ed)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AfaqDesign.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (statusFields.contains(field.$1))
                      status(field.$2)
                    else
                      SelectableText(
                        field.$2.trim().isEmpty ? 'Not recorded' : field.$2,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AfaqDesign.ink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class WorkspaceDetailsDialog extends StatelessWidget {
  const WorkspaceDetailsDialog({
    super.key,
    required this.title,
    required this.fields,
    this.sections = const [],
    this.actions,
    this.icon = Icons.badge_outlined,
    this.statusFields = const {},
  });
  final String title;
  final List<(String, String)> fields;
  final List<(String, String)> sections;
  final List<Widget>? actions;
  final IconData icon;
  final Set<String> statusFields;

  Future<void> copyDetails(BuildContext context) async {
    final text = [
      title,
      for (final field in fields) '${field.$1}: ${field.$2}',
      for (final section in sections) '\n${section.$1}\n${section.$2}',
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details copied. Share only with authorised people.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy details. Select the text to copy it manually.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceFormDialog(
    title: Text(title),
    eyebrow: 'AFAQ / RECORD DETAILS',
    icon: icon,
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 17,
                    color: AfaqDesign.muted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Read-only details',
                      style: TextStyle(fontSize: 13, color: AfaqDesign.muted),
                    ),
                  ),
                ],
              ),
            ),
            WorkspaceRecordDetails(fields: fields, statusFields: statusFields),
            for (final section in sections) ...[
              const SizedBox(height: 24),
              WorkspaceDetailsSection(
                title: section.$1,
                child: SelectableText(
                  section.$2,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AfaqDesign.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions:
        actions ??
        [
          TextButton.icon(
            onPressed: () => copyDetails(context),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copy details'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
  );
}
