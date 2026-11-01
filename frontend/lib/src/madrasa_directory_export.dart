const _locationColumns = {
  'country': 'Country',
  'region': 'Region / County / State',
  'district': 'District / Sub-county',
  'ward': 'Ward',
  'village': 'Village',
  'street': 'Street / Neighbourhood',
  'hamlet': 'Hamlet',
  'address': 'Address / Landmark',
};

String madrasaDirectoryCsv(List<dynamic> items) {
  String cell(dynamic value) {
    var text = value == null ? '' : '$value';
    // Spreadsheet applications can execute formulas even in quoted CSV cells.
    if (RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  String joined(dynamic value) =>
      value is List ? value.where((item) => item != null).join('; ') : '';

  final rows = <List<dynamic>>[
    [
      'Madrasa',
      'Code',
      ..._locationColumns.values,
      'Branch locations',
      'Assigned admins',
      'Learners',
      'Teachers',
      'Status',
    ],
    for (final item in items)
      [
        item['name'],
        item['code'],
        for (final key in _locationColumns.keys)
          item['location'] is Map ? item['location'][key] : null,
        joined(item['locations']),
        joined(item['admins']),
        item['students'],
        item['teachers'],
        item['status'],
      ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}
