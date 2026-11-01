import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/sms_estimate.dart';

void main() {
  test('empty drafts and no recipients cost zero estimated credits', () {
    expect(estimateSms('  ', 5).credits, 0);
    expect(estimateSms('Hello', 0).credits, 0);
  });
  test('GSM multipart boundaries and recipient multiplication', () {
    expect(estimateSms('a' * 160, 3).credits, 3);
    expect(estimateSms('a' * 161, 3).credits, 6);
    expect(estimateSms('a' * 306, 1).parts, 2);
    expect(estimateSms('a' * 307, 1).parts, 3);
  });
  test('extension characters count as two GSM units', () {
    expect(estimateSms('^' * 80, 1).parts, 1);
    expect(estimateSms('^' * 81, 1).parts, 2);
    expect(estimateSms('\u00e9', 1).unicode, false);
  });
  test('Unicode and emoji use UTF-16 units and multipart capacity', () {
    expect(estimateSms('\u0627' * 70, 1).parts, 1);
    expect(estimateSms('\u0627' * 71, 1).parts, 2);
    expect(estimateSms('\u{1f600}' * 35, 1).units, 70);
    expect(estimateSms('\u{1f600}' * 36, 1).parts, 2);
    expect(estimateSms('\u0627' * 135, 1).parts, 3);
  });
}
