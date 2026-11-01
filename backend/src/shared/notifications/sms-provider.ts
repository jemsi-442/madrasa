import { randomUUID } from 'node:crypto';
import { sendMesejiSms, type MesejiConfig, type SmsResult } from './meseji-sms';

export type SmsConfig = MesejiConfig & { provider?: 'meseji' | 'rodsms'; baseUrl?: string; idempotencyKey?: string };

const rodsmsBaseUrl = 'https://www.rodsms.com/api/v1';
function normalizeRodSmsUrl(value: string): string | null {
  const normalized = value.trim().replace(/\/+$/, '');
  // Do not forward the API key to an accidental or untrusted host.
  return normalized === rodsmsBaseUrl ? normalized : null;
}

export function smsConfig(env: NodeJS.ProcessEnv = process.env): SmsConfig | null {
  const provider = env.SMS_PROVIDER;
  if (provider !== 'meseji' && provider !== 'rodsms') return null;
  const prefix = provider === 'rodsms' ? 'RODSMS' : 'MESEJI';
  const apiKey = env[`${prefix}_API_KEY`]?.trim();
  const senderId = env[`${prefix}_SENDER_ID`]?.trim();
  if (!apiKey || !senderId || !/^[A-Za-z0-9]{1,11}$/.test(senderId)) return null;
  if (provider === 'rodsms') {
    const baseUrl = normalizeRodSmsUrl(env.RODSMS_BASE_URL ?? rodsmsBaseUrl);
    if (!baseUrl) return null;
    return { provider, apiKey, senderId, baseUrl };
  }
  return { provider, apiKey, senderId };
}

export async function sendSms(config: SmsConfig, phone: string, message: string,
  request: typeof fetch = fetch): Promise<SmsResult> {
  if (!config.provider || config.provider === 'meseji') return sendMesejiSms(config, phone, message, request);
  const baseUrl = normalizeRodSmsUrl(config.baseUrl ?? rodsmsBaseUrl);
  if (!baseUrl) return { status: 'FAILED', reason: 'INVALID_CONFIGURATION' };
  try {
    const response = await request(`${baseUrl}/messages`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.apiKey}`,
        'Idempotency-Key': config.idempotencyKey ?? `afaq-${randomUUID()}` },
      body: JSON.stringify({ sender_id: config.senderId, recipient: phone, message }),
    });
    if ([400, 401, 402, 403, 404, 422, 429].includes(response.status)) {
      return { status: 'FAILED', reason: `HTTP_${response.status}` };
    }
    if (!response.ok) return { status: 'UNKNOWN', reason: 'PROVIDER_UNCERTAIN' };
    const body = await response.json() as { success?: unknown; data?: { id?: unknown; submission_status?: unknown } };
    if (body.success !== true || body.data?.submission_status !== 'queued'
      || typeof body.data.id !== 'string' || !body.data.id || body.data.id.length > 150) {
      return { status: 'UNKNOWN', reason: 'UNEXPECTED_RESPONSE' };
    }
    return { status: 'ACCEPTED', batchId: body.data.id };
  } catch {
    // Never switch provider or retry an uncertain send: the phone may already receive it.
    return { status: 'UNKNOWN', reason: 'NETWORK_UNCERTAIN' };
  }
}
