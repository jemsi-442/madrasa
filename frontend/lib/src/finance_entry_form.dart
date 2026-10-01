import 'package:flutter/material.dart';

import 'accountant_components.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'foundation_ui.dart';

enum FinanceEntryOutcome { saved, checkRegister }

Future<FinanceEntryOutcome?> showFinanceEntry(
  BuildContext context, {
  required bool expense,
  required PageSubmitter submit,
}) => showDialog<FinanceEntryOutcome>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _FinanceEntry(expense: expense, submit: submit),
);

class _FinanceEntry extends StatefulWidget {
  const _FinanceEntry({required this.expense, required this.submit});
  final bool expense;
  final PageSubmitter submit;
  @override
  State<_FinanceEntry> createState() => _FinanceEntryState();
}

class _FinanceEntryState extends State<_FinanceEntry> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  final date = TextEditingController();
  String cycle = 'TERMLY';
  bool active = true,
      busy = false,
      dirty = false,
      closing = false,
      uncertain = false;
  String? error;

  @override
  void dispose() {
    for (final c in [name, amount, note, date]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> close() async {
    if (busy || closing) return;
    if (dirty && !uncertain) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this entry?'),
          content: const Text('Your unsaved details will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => closing = true);
    Navigator.pop(
      context,
      uncertain ? FinanceEntryOutcome.checkRegister : null,
    );
  }

  Future<void> save() async {
    if (busy || uncertain || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget
          .submit(widget.expense ? '/api/expenses' : '/api/fee-structures', {
            widget.expense ? 'title' : 'name': name.text.trim(),
            'amount': amount.text.trim(),
            if (widget.expense) ...{
              'currency': 'TZS',
              'expenseDate': date.text,
              if (note.text.trim().isNotEmpty) 'description': note.text.trim(),
            } else ...{
              'billingCycle': cycle,
              'isActive': active,
            },
          })
          .timeout(const Duration(seconds: 30));
      if (result is! Map || result['id'] == null) {
        throw StateError('Missing saved record');
      }
      if (!mounted) return;
      setState(() {
        closing = true;
        busy = false;
      });
      Navigator.pop(context, FinanceEntryOutcome.saved);
    } catch (e) {
      if (!mounted) return;
      final rejected =
          e is ApiException &&
          [400, 401, 403, 404, 409, 422, 429].contains(e.statusCode);
      setState(() {
        busy = false;
        uncertain = !rejected;
        error = uncertain
            ? 'The save could not be confirmed. It may have reached the school. Check the register before creating another entry to avoid duplicates.'
            : e is ApiException && e.statusCode == 403
            ? 'You do not have permission to save this record in this scope.'
            : 'The entry was not accepted. Check your details and account access, then try again.';
      });
    }
  }

  Future<void> pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(date.text) ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      date.text = picked.toIso8601String().substring(0, 10);
      dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing || (!busy && !dirty && !uncertain),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(
        widget.expense ? 'Record an expense' : 'Create a fee structure',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            onChanged: () {
              if (!dirty) setState(() => dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FinanceNotice(
                  'This entry uses your account\'s branch scope. If no branch is assigned, it is school-wide. No money is transferred.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: name,
                  enabled: !busy && !uncertain,
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: widget.expense ? 'Expense title' : 'Fee name',
                  ),
                  validator: (v) => (v ?? '').trim().length < 2
                      ? 'Use at least two characters.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amount,
                  enabled: !busy && !uncertain,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (TZS)',
                    hintText: 'For example, 25000.00',
                  ),
                  validator: (v) {
                    final raw = (v ?? '').trim(),
                        units = financeMinorUnits((v ?? '').trim());
                    return !RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(raw) ||
                            units == null ||
                            units <= BigInt.zero
                        ? 'Enter a positive amount with up to two decimals.'
                        : null;
                  },
                ),
                const SizedBox(height: 18),
                if (widget.expense) ...[
                  TextFormField(
                    controller: date,
                    enabled: !busy && !uncertain,
                    readOnly: true,
                    onTap: pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Expense date',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    validator: (v) => DateTime.tryParse(v ?? '') == null
                        ? 'Choose the expense date.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: note,
                    enabled: !busy && !uncertain,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: cycle,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Billing cycle',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ONE_TIME',
                        child: Text('One time'),
                      ),
                      DropdownMenuItem(
                        value: 'MONTHLY',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(value: 'TERMLY', child: Text('Termly')),
                    ],
                    onChanged: busy || uncertain
                        ? null
                        : (v) => setState(() {
                            cycle = v!;
                            dirty = true;
                          }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active for billing'),
                    value: active,
                    onChanged: busy || uncertain
                        ? null
                        : (v) => setState(() {
                            active = v;
                            dirty = true;
                          }),
                  ),
                  const Text(
                    'A fee structure is a rate template. It does not create invoices automatically.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFAF3844)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : close,
          child: Text(uncertain ? 'Check register' : 'Cancel'),
        ),
        FilledButton(
          onPressed: busy || uncertain ? null : save,
          child: Text(busy ? 'Saving...' : 'Save entry'),
        ),
      ],
    ),
  );
}
