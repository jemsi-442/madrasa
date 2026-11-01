export type SmsResult = { status: 'ACCEPTED' | 'FAILED' | 'UNKNOWN'; batchId?: string; reason?: string };
export type MesejiConfig = { apiKey: string; senderId: string };

export function smsPhone(raw: string | null): string | null {
  const phone = (raw ?? '').replace(/[\s()-]/g, '').replace(/^\+/, '');
  // Local TZ numbers are normalized; international numbers must include country code.
  const normalized = /^0[67]\d{8}$/.test(phone) ? `255${phone.slice(1)}` : phone;
  return /^[1-9]\d{7,14}$/.test(normalized) ? normalized : null;
}

export async function sendMesejiSms(config: MesejiConfig, phone: string, message: string,
  request: typeof fetch = fetch): Promise<SmsResult> {
  try {
    const response = await request('https://meseji.co.tz/api/v1/sms/send', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/json', 'x-api-key': config.apiKey },
      body: JSON.stringify({ sender_id: config.senderId, contacts: phone, message }),
    });
    if ([400, 401, 403, 422, 429].includes(response.status)) {
      return { status: 'FAILED', reason: `HTTP_${response.status}` };
    }
    if (!response.ok) return { status: 'UNKNOWN', reason: 'PROVIDER_UNCERTAIN' };
    const body = await response.json() as { status?: unknown; batch_id?: unknown };
    if (body.status !== 'queued' || typeof body.batch_id !== 'string' || !body.batch_id || body.batch_id.length > 150) {
      return { status: 'UNKNOWN', reason: 'UNEXPECTED_RESPONSE' };
    }
    // Accepted into the provider queue is not proof of handset delivery.
    return { status: 'ACCEPTED', batchId: body.batch_id };
  } catch {
    return { status: 'UNKNOWN', reason: 'NETWORK_UNCERTAIN' };
  }
}
