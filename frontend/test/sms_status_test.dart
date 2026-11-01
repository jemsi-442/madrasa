import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/sms_status.dart';

void main() {
  test('explains credits and permissions without exposing raw codes', () {
    expect(smsFailureGuidance('HTTP_402'), contains('Top up'));
    expect(smsFailureGuidance('HTTP_403'), contains('sender ID'));
    expect(smsFailureGuidance('HTTP_403'), contains('permissions'));
    expect(smsFailureGuidance(null), isNull);
  });
  test(
    'uncertain sends warn against duplicates rather than claiming delivery',
    () {
      for (final reason in [
        'NETWORK_UNCERTAIN',
        'WORKER_INTERRUPTED',
        'PROVIDER_UNCERTAIN',
        'UNEXPECTED_RESPONSE',
      ]) {
        expect(smsFailureGuidance(reason), contains('avoid duplicates'));
      }
    },
  );
  test('unknown provider reasons are not displayed verbatim', () {
    expect(
      smsFailureGuidance('private-provider-detail'),
      isNot(contains('private-provider-detail')),
    );
    expect(
      smsFailureGuidance('CONSENT_WITHDRAWN'),
      contains('no longer allows'),
    );
  });
}
