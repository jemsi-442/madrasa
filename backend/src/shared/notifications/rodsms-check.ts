import { smsConfig } from './sms-provider';

export async function checkRodSms(env: NodeJS.ProcessEnv, request: typeof fetch = fetch) {
  const config = smsConfig(env);
  if (!config || config.provider !== 'rodsms') {
    return { ok: false, reason: 'Set SMS_PROVIDER=rodsms and valid RodSMS credentials/base URL.' };
  }
  const read = async (path: string): Promise<unknown> => {
    const response = await request(`${config.baseUrl}/${path}`, {
      method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { Authorization: `Bearer ${config.apiKey}`, Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(response.status === 403
      ? 'Access denied: this check requires sms:read permission; sending permission is separate.'
      : `RodSMS check failed (HTTP ${response.status}).`);
    const body = await response.json() as { success?: unknown; data?: unknown };
    if (body.success !== true) throw new Error('Unexpected RodSMS response.');
    return body.data;
  };
  try {
    const balance = await read('balance') as { sms_credits?: unknown } | null;
    const senders = await read('sender-ids');
    if (typeof balance?.sms_credits !== 'number' || !Number.isFinite(balance.sms_credits)
      || balance.sms_credits < 0 || !Array.isArray(senders)) {
      return { ok: false, reason: 'Unexpected RodSMS response.' };
    }
    const approved = senders.some(row => row && row.sender_id === config.senderId);
    return { ok: approved && balance.sms_credits > 0, credits: balance.sms_credits,
      senderApproved: approved, reason: !approved ? 'Configured sender is not in the approved active sender list.'
        : balance.sms_credits === 0 ? 'Top up SMS credits before sending.'
        : 'Connection, balance and sender checks passed. sms:send permission is not tested. No SMS sent.' };
  } catch (error) {
    // Never expose provider bodies, network URLs or authorization headers.
    const reason = error instanceof Error && /^(Access denied:|RodSMS check failed \(HTTP \d+\)\.$|Unexpected RodSMS response\.$)/.test(error.message)
      ? error.message : 'Could not complete RodSMS check. Check connectivity and credentials.';
    return { ok: false, reason };
  }
}
