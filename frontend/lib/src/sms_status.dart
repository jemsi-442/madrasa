String? smsFailureGuidance(dynamic reason) => switch (reason) {
  null || '' => null,
  'HTTP_400' || 'HTTP_422' => 'Check the phone number and message format.',
  'HTTP_401' =>
    'SMS credentials were rejected. Ask the system administrator to check the API key.',
  'HTTP_402' => 'SMS credits are insufficient. Top up the provider account.',
  'HTTP_403' => 'Check the approved sender ID and API key permissions.',
  'HTTP_404' ||
  'INVALID_CONFIGURATION' => 'Check the SMS provider configuration.',
  'HTTP_429' =>
    'The provider request limit was reached. Sending was not retried automatically.',
  'CONSENT_WITHDRAWN' => 'This donor no longer allows these messages.',
  'PHONE_CHANGED' =>
    'The donor phone number changed. Review the recipient before composing a new message.',
  'PHONE_UNAVAILABLE' => 'A valid recipient phone number is missing.',
  'MADRASA_INACTIVE' => 'The madrasa is inactive. This message was skipped.',
  'SENDER_ACCESS_REVOKED' =>
    'The sender no longer has permission to send donor messages.',
  'STALE_NOTIFICATION' =>
    'This message expired before sending. Review whether it is still relevant.',
  'DONATION_VOIDED' => 'The donation is no longer recorded as received.',
  'MESSAGE_NOT_QUEUED' => 'This message is no longer queued for sending.',
  'WORKER_INTERRUPTED' ||
  'NETWORK_UNCERTAIN' ||
  'PROVIDER_UNCERTAIN' ||
  'UNEXPECTED_RESPONSE' =>
    'Sending could not be confirmed. Check the provider before sending again to avoid duplicates.',
  _ => 'Check this message with the system administrator before sending again.',
};
