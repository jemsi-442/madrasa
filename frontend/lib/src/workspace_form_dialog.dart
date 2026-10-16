import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Shared form framing; callers retain validation, scrolling and submit logic.
class WorkspaceFormDialog extends StatelessWidget {
  const WorkspaceFormDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.icon = Icons.edit_note_rounded,
    this.eyebrow = 'AFAQ / WORKSPACE',
  });
  final Widget title, content;
  final List<Widget>? actions;
  final IconData icon;
  final String eyebrow;

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    titlePadding: EdgeInsets.zero,
    contentPadding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
      24,
      MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
      20,
    ),
    actionsPadding: EdgeInsets.zero,
    actionsOverflowButtonSpacing: 10,
    title: Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 16 : 24),
      decoration: const BoxDecoration(
        color: Color(0xfff3f6fa),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xffdde4eb))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff5ecd7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AfaqDesign.actionGold, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: AfaqDesign.actionGold,
                  ),
                ),
                const SizedBox(height: 8),
                title,
              ],
            ),
          ),
        ],
      ),
    ),
    content: content,
    actions: actions == null
        ? null
        : [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xfff7f9fc),
                border: Border(top: BorderSide(color: Color(0xffdde4eb))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: actions!,
              ),
            ),
          ],
  );
}

class WorkspaceFormSection extends StatelessWidget {
  const WorkspaceFormSection({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AfaqDesign.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AfaqDesign.muted,
          ),
        ),
      ],
    ),
  );
}

class WorkspaceFormNotice extends StatelessWidget {
  const WorkspaceFormNotice({
    super.key,
    required this.message,
    this.isError = false,
  });
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: isError,
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xfffff0f0) : const Color(0xffeef4fb),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: isError ? const Color(0xffb42318) : AfaqDesign.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isError ? const Color(0xffb42318) : AfaqDesign.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
