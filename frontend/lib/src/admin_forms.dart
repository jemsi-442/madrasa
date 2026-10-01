import 'dart:math';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';

typedef PageSubmitter =
    Future<dynamic> Function(String path, Map<String, dynamic> body);

String submissionId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class AdminField {
  const AdminField(
    this.name,
    this.label, {
    this.required = true,
    this.kind = 'text',
    this.options,
    this.lookupPath,
    this.lookupLabel = 'fullName',
    this.initial,
  });
  final String name, label, kind, lookupLabel;
  final bool required;
  final Map<String, String>? options;
  final String? lookupPath, initial;
}

Future<bool> showAdminForm(
  BuildContext context, {
  required String title,
  required List<AdminField> fields,
  required Future<void> Function(Map<String, dynamic>) onSave,
  PageLoader? load,
  String saveLabel = 'Save',
  String? note,
  String? conflictMessage,
  String? Function(Object)? errorMessage,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminForm(
        title: title,
        fields: fields,
        onSave: onSave,
        load: load,
        saveLabel: saveLabel,
        note: note,
        conflictMessage: conflictMessage,
        errorMessage: errorMessage,
      ),
    ) ??
    false;

class _AdminForm extends StatefulWidget {
  const _AdminForm({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.load,
    required this.saveLabel,
    this.note,
    this.conflictMessage,
    this.errorMessage,
  });
  final String title, saveLabel;
  final String? note, conflictMessage;
  final String? Function(Object)? errorMessage;
  final List<AdminField> fields;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final PageLoader? load;
  @override
  State<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<_AdminForm> {
  final formKey = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields)
      f.name: TextEditingController(text: f.initial),
  };
  final values = <String, String>{};
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave({
        for (final f in widget.fields)
          if ((values[f.name] ?? controllers[f.name]!.text).trim().isNotEmpty)
            f.name: f.kind == 'password'
                ? controllers[f.name]!.text
                : (values[f.name] ?? controllers[f.name]!.text).trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error =
              widget.errorMessage?.call(e) ??
              switch (e) {
                ApiException(statusCode: 409) =>
                  widget.conflictMessage ??
                      'This entry conflicts with an existing record. Check your details before trying again.',
                ApiException(statusCode: 422) =>
                  'Please check the details and dates, then try again.',
                ApiException(statusCode: 404) =>
                  'A selected record is no longer available. Please select it again.',
                _ =>
                  'We could not confirm the save. Please try again with the same details.',
              };
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(AdminField f) async {
    if (f.lookupPath != null) {
      final picked = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _RecordPicker(load: widget.load!, field: f),
      );
      if (picked != null && mounted) {
        setState(() {
          values[f.name] = picked['id'].toString();
          controllers[f.name]!.text = recordText(picked[f.lookupLabel]);
        });
      }
      return;
    }
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    DateTime selected = day;
    if (f.kind == 'datetime') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null || !mounted) return;
      selected = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
    setState(() {
      values[f.name] = f.kind == 'datetime'
          ? selected.toUtc().toIso8601String()
          : selected.toIso8601String().substring(0, 10);
      controllers[f.name]!.text =
          '${MaterialLocalizations.of(context).formatMediumDate(selected)}${f.kind == 'datetime' ? ' ${TimeOfDay.fromDateTime(selected).format(context)}' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          primary: true,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      widget.note!,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: f.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue: f.initial,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: f.label),
                            items: [
                              for (final option in f.options!.entries)
                                DropdownMenuItem(
                                  value: option.key,
                                  child: Text(option.value),
                                ),
                            ],
                            onChanged: busy
                                ? null
                                : (v) {
                                    if (v != null) {
                                      values[f.name] = v;
                                      controllers[f.name]!.text = v;
                                    }
                                  },
                            validator: (v) => f.required && v == null
                                ? 'Choose ${f.label.toLowerCase()}'
                                : null,
                          )
                        : TextFormField(
                            controller: controllers[f.name],
                            enabled: !busy,
                            obscureText: f.kind == 'password',
                            readOnly:
                                f.lookupPath != null ||
                                f.kind == 'date' ||
                                f.kind == 'datetime',
                            onTap:
                                f.lookupPath != null ||
                                    f.kind == 'date' ||
                                    f.kind == 'datetime'
                                ? () => pick(f)
                                : null,
                            keyboardType: f.kind == 'money'
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : f.kind == 'email'
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            maxLines: f.kind == 'notes' ? 3 : 1,
                            decoration: InputDecoration(
                              labelText:
                                  '${f.label}${f.required ? '' : ' (optional)'}',
                              suffixIcon: f.lookupPath != null
                                  ? const Icon(Icons.expand_more)
                                  : f.kind.startsWith('date')
                                  ? const Icon(Icons.calendar_today_outlined)
                                  : null,
                            ),
                            validator: (raw) {
                              final v = (raw ?? '').trim();
                              if (f.required && v.isEmpty) {
                                return 'Enter ${f.label.toLowerCase()}';
                              }
                              if (v.isEmpty) return null;
                              if (f.kind == 'integer' &&
                                  (!RegExp(r'^[1-9]\d*$').hasMatch(v) ||
                                      int.tryParse(v) == null)) {
                                return 'Enter a whole number greater than zero';
                              }
                              if (f.kind == 'email' &&
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v)) {
                                return 'Enter a valid email address';
                              }
                              if (f.kind == 'password' && v.length < 8) {
                                return 'Use at least 8 characters';
                              }
                              if (f.kind == 'money' &&
                                  (!RegExp(
                                        r'^\d{1,10}(\.\d{1,2})?$',
                                      ).hasMatch(v) ||
                                      (num.tryParse(v) ?? 0) <= 0)) {
                                return 'Enter an amount greater than zero';
                              }
                              return null;
                            },
                          ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saveLabel),
        ),
      ],
    ),
  );
}

class _RecordPicker extends StatefulWidget {
  const _RecordPicker({required this.load, required this.field});
  final PageLoader load;
  final AdminField field;
  @override
  State<_RecordPicker> createState() => _RecordPickerState();
}

class _RecordPickerState extends State<_RecordPicker> {
  String search = '';
  int page = 1;
  late Future<dynamic> future = fetch();
  Future<dynamic> fetch() => widget.load(
    '${widget.field.lookupPath}?${Uri(queryParameters: {'page': '$page', 'pageSize': '10', 'search': search}).query}',
  );
  void reload() {
    setState(() {
      future = fetch();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Choose ${widget.field.label.toLowerCase()}'),
    content: SizedBox(
      width: 450,
      height: 430,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              search = value.trim();
              page = 1;
              reload();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              primary: true,
              child: PageResult(
                future: future,
                onRetry: reload,
                builder: (data) {
                  final map = recordMap(data), items = recordList(map['items']);
                  return Column(
                    children: [
                      if (items.isEmpty)
                        const EmptyRecords('No matching records.'),
                      for (final row in items)
                        ListTile(
                          title: Text(
                            recordText(row[widget.field.lookupLabel]),
                          ),
                          onTap: () => Navigator.pop(context, row),
                        ),
                      DirectoryPager(
                        meta: recordMap(map['meta']),
                        onPage: (p) {
                          page = p;
                          reload();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class DirectoryPager extends StatelessWidget {
  const DirectoryPager({super.key, required this.meta, required this.onPage});
  final Map<String, dynamic> meta;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final page = recordNumber(meta['page']).toInt(),
        pages = recordNumber(meta['totalPages']).toInt();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${recordText(meta['totalItems'], '0')} records',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${pages == 0 ? 0 : page} / $pages',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

String moneyText(dynamic value) {
  final fixed = recordNumber(value).toStringAsFixed(2).split('.');
  final whole = fixed.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return fixed.last == '00' ? whole : '$whole.${fixed.last}';
}

String shortDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '-';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
