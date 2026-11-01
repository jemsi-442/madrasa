import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_directory_export.dart';

void main() {
  test('exports every location level separately and retains branch addresses', () {
    final csv = madrasaDirectoryCsv([
      {
        'name': 'Synthetic Madrasa',
        'code': 'SYN',
        'location': {
          'country': 'Tanzania',
          'region': 'Synthetic Region',
          'district': 'Synthetic District',
          'ward': 'Synthetic Ward',
          'village': 'Synthetic Village',
          'street': 'Synthetic Street',
          'hamlet': 'Synthetic Hamlet',
          'address': 'Near the hall',
        },
        'locations': ['Legacy Area'],
        'admins': [],
        'students': 0,
        'teachers': null,
        'status': 'REQUESTED',
      },
    ]);
    final lines = csv.split('\r\n');
    expect(
      lines.first,
      contains(
        '"Village","Street / Neighbourhood","Hamlet","Address / Landmark","Branch locations"',
      ),
    );
    expect(
      lines.last,
      contains(
        '"Synthetic Village","Synthetic Street","Synthetic Hamlet","Near the hall","Legacy Area"',
      ),
    );
    expect(lines.last, endsWith('"","0","","REQUESTED"'));
    expect(csv, isNot(contains('null')));
  });

  test(
    'keeps legacy records and missing optional areas without inventing data',
    () {
      final csv = madrasaDirectoryCsv([
        {
          'name': 'Synthetic School',
          'locations': ['Old Area'],
        },
      ]);
      expect(csv, contains('"Old Area"'));
      expect(csv.split('\r\n').last.split(',').length, 15);
      expect(csv, isNot(contains('Location not recorded')));
    },
  );

  test(
    'escapes quotes commas and newlines while neutralizing spreadsheet formulas',
    () {
      for (final value in [
        '=1+1',
        '+1',
        '-1',
        '@SUM(A1)',
        '  =1',
        '\tvalue',
        '\rvalue',
        '\nvalue',
      ]) {
        final csv = madrasaDirectoryCsv([
          {
            'location': {'village': value},
          },
        ]);
        expect(csv, contains('"\'$value"'));
      }
      final csv = madrasaDirectoryCsv([
        {
          'location': {'address': 'Hall, "A"\nGate 2'},
        },
      ]);
      expect(csv, contains('"Hall, ""A""\nGate 2"'));
    },
  );

  test('empty results still export a header', () {
    final csv = madrasaDirectoryCsv([]);
    expect(csv, startsWith('"Madrasa","Code","Country"'));
    expect(csv, isNot(contains('\r\n')));
  });
}
