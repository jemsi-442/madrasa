import 'package:flutter/material.dart';

const madrasaLocationLabels = {
  'country': 'Country',
  'region': 'Region / County / State',
  'district': 'District / Sub-county',
  'ward': 'Ward',
  'village': 'Village',
  'street': 'Street / Neighbourhood',
  'hamlet': 'Hamlet',
  'address': 'Address / Landmark',
};

String locationSummary(dynamic value, {String fallback = 'Not recorded'}) {
  if (value is! Map) return fallback;
  final parts = [
    for (final key in madrasaLocationLabels.keys)
      if (value[key] is String && (value[key] as String).trim().isNotEmpty)
        (value[key] as String).trim(),
  ];
  return parts.isEmpty ? fallback : parts.join(', ');
}

class MadrasaLocationFields extends LocationFields {
  const MadrasaLocationFields({
    super.key,
    required super.values,
    super.loadSuggestions,
  }) : super(
         requiredFields: const {'country', 'region', 'district', 'ward'},
         landmarkTitle: 'Finding the madrasa',
       );
}

class LocationFields extends StatefulWidget {
  const LocationFields({
    super.key,
    required this.values,
    this.loadSuggestions,
    this.requiredFields = const {},
    this.title = 'Location',
    this.landmarkTitle = 'Address details',
  });
  final Map<String, String> values;
  final Future<dynamic> Function(String)? loadSuggestions;
  final Set<String> requiredFields;
  final String title, landmarkTitle;

  @override
  State<LocationFields> createState() => _MadrasaLocationFieldsState();
}

class _MadrasaLocationFieldsState extends State<LocationFields> {
  late final controllers = {
    for (final key in madrasaLocationLabels.keys)
      key: TextEditingController(text: widget.values[key]),
  };
  final nodes = {
    for (final key in madrasaLocationLabels.keys) key: FocusNode(),
  };
  final requests = <String, int>{};
  final suggestions = <String, List<String>>{};
  final feedback = <String, String>{};
  final needsRefresh = <String>{};
  TextEditingController get country => controllers['country']!;

  List<String> parentsFor(String key) => switch (key) {
    'country' || 'address' => [],
    'region' => ['country'],
    'district' => ['country', 'region'],
    'ward' => ['country', 'region', 'district'],
    _ => ['country', 'region', 'district', 'ward'],
  };

  void updateValue(String key, String value) {
    if (widget.values[key] == value) return;
    widget.values[key] = value;
    // Cancel descendants even if a parent changes away and then back while
    // a request is pending. Comparing parent strings alone misses that race.
    for (final child in controllers.keys) {
      if (!parentsFor(child).contains(key)) continue;
      requests[child] = (requests[child] ?? 0) + 1;
      suggestions.remove(child);
      feedback.remove(child);
      needsRefresh.add(child);
    }
  }

  @override
  void initState() {
    super.initState();
    for (final entry in nodes.entries) {
      entry.value.addListener(() {
        if (!mounted) return;
        if (entry.value.hasFocus && needsRefresh.contains(entry.key)) {
          suggest(entry.key, controllers[entry.key]!.text);
        } else {
          setState(() {});
        }
      });
    }
  }

  Future<void> suggest(String key, String text) async {
    needsRefresh.remove(key);
    final request = (requests[key] ?? 0) + 1;
    requests[key] = request;
    suggestions.remove(key);
    feedback.remove(key);
    if (key == 'address' ||
        text.trim().isEmpty ||
        widget.loadSuggestions == null) {
      setState(() {});
      return;
    }
    final parentKeys = parentsFor(key);
    final missing = parentKeys.where(
      (parent) => (widget.values[parent] ?? '').isEmpty,
    );
    if (missing.isNotEmpty) {
      setState(
        () => feedback[key] =
            'Enter ${label(missing.first).toLowerCase()} first.',
      );
      return;
    }
    final parents = {
      for (final parent in parentKeys) parent: widget.values[parent]!,
    };
    setState(() => feedback[key] = 'Finding suggestions...');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    bool current() =>
        mounted &&
        requests[key] == request &&
        parents.entries.every(
          (entry) => widget.values[entry.key] == entry.value,
        );
    if (!current()) return;
    try {
      final result = await widget.loadSuggestions!(
        '/location-suggestions?${Uri(queryParameters: {'field': key, 'q': text.trim(), ...parents}).query}',
      );
      if (!current()) return;
      final items = ((result as Map)['items'] as List)
          .whereType<String>()
          .toList();
      setState(() {
        suggestions[key] = items;
        feedback[key] = items.isEmpty
            ? 'No suggestions found. You can enter the area manually.'
            : 'Choose an area below.';
      });
    } catch (_) {
      if (current()) {
        setState(
          () => feedback[key] =
              'Suggestions unavailable. You can still enter the area.',
        );
      }
    }
  }

  void select(String key, String value) {
    setState(() {
      requests[key] = (requests[key] ?? 0) + 1;
      controllers[key]!.text = value;
      updateValue(key, value);
      suggestions.remove(key);
      feedback.remove(key);
    });
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String label(String key) {
    final name = country.text.trim().toLowerCase();
    if (key == 'region') {
      if (name == 'tanzania') return 'Region';
      if (name == 'kenya') return 'County';
    }
    if (key == 'district') {
      if (name == 'tanzania') return 'District';
      if (name == 'kenya') return 'Sub-county';
    }
    return madrasaLocationLabels[key]!;
  }

  Widget field(String key) => TextFieldTapRegion(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('madrasa-location-$key'),
          controller: controllers[key],
          focusNode: nodes[key],
          onFieldSubmitted: (_) {
            final items = suggestions[key] ?? [];
            if (items.isNotEmpty) select(key, items.first);
          },
          maxLength: key == 'address'
              ? 255
              : key == 'street'
              ? 150
              : 100,
          minLines: key == 'address' ? 2 : 1,
          maxLines: key == 'address' ? 3 : 1,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText:
                '${label(key)}${widget.requiredFields.contains(key) ? ' *' : ' (optional)'}',
            hintText: key == 'country' ? 'Start typing, e.g. Tan' : null,
            helperText: nodes[key]!.hasFocus ? feedback[key] : null,
            helperMaxLines: 2,
          ),
          validator: (value) =>
              (widget.requiredFields.contains(key) ||
                      ([
                            'country',
                            'region',
                            'district',
                            'ward',
                          ].contains(key) &&
                          (value?.trim().isNotEmpty ?? false))) &&
                  (value?.trim().length ?? 0) < 2
              ? 'Enter ${label(key).toLowerCase()}.'
              : null,
          onChanged: (value) {
            updateValue(key, value.trim());
            suggest(key, value);
          },
        ),
        // Inline options keep web text-field semantics from intercepting clicks
        // on a floating overlay. They remain inside the form's scroll area.
        if (nodes[key]!.hasFocus && (suggestions[key]?.isNotEmpty ?? false))
          Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in suggestions[key]!)
                    ListTile(
                      title: Text(option),
                      dense: true,
                      onTap: () => select(key, option),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget group(BuildContext context, String title, List<String> keys) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 480
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final key in keys) SizedBox(width: width, child: field(key)),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        widget.requiredFields.isEmpty
            ? 'Optional. Choose a suggestion or enter the area manually.'
            : 'Country, region/county, district and ward are required. Choose a suggestion or enter the area manually.',
      ),
      const SizedBox(height: 16),
      field('country'),
      Wrap(
        spacing: 8,
        children: [
          for (final name in ['Tanzania', 'Kenya'])
            ActionChip(
              label: Text(name),
              onPressed: () => select('country', name),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Changing country keeps your entries. Check that the areas below match the selected country.',
      ),
      const SizedBox(height: 20),
      group(context, 'Administrative area', ['region', 'district', 'ward']),
      group(context, 'Local area', ['village', 'street', 'hamlet']),
      Text(widget.landmarkTitle, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      field('address'),
    ],
  );
}
