import { expect, it, vi } from 'vitest';
import { checkRodSms } from '../src/shared/notifications/rodsms-check';

const env = { SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: 'synthetic-key', RODSMS_SENDER_ID: 'AFAQ' };
const response = (data: unknown) => new Response(JSON.stringify({ success: true, data }));
it('checks balance and uppercase sender using GET only', async () => {
  const request = vi.fn().mockResolvedValueOnce(response({ sms_credits: 20 }))
    .mockResolvedValueOnce(response([{ sender_id: 'AFAQ', country: 'TZ' }]));
  expect(await checkRodSms(env, request)).toMatchObject({ ok: true, credits: 20, senderApproved: true });
  expect(request.mock.calls.map(call => call[0])).toEqual([
    'https://www.rodsms.com/api/v1/balance', 'https://www.rodsms.com/api/v1/sender-ids',
  ]);
  for (const call of request.mock.calls) expect(call[1].method).toBe('GET');
});
it.each([0, 10])('reports zero credits or an unapproved sender', async credits => {
  const request = vi.fn().mockResolvedValueOnce(response({ sms_credits: credits }))
    .mockResolvedValueOnce(response(credits ? [] : [{ sender_id: 'AFAQ' }]));
  expect((await checkRodSms(env, request)).ok).toBe(false);
});
it('does not contact RodSMS for missing config', async () => {
  const request = vi.fn();
  expect((await checkRodSms({}, request)).ok).toBe(false);
  expect(request).not.toHaveBeenCalled();
});
it('explains read permission without exposing response body', async () => {
  const request = vi.fn().mockResolvedValue(new Response('private-provider-body', { status: 403 }));
  const result = await checkRodSms(env, request);
  expect(result.reason).toContain('sms:read');
  expect(JSON.stringify(result)).not.toContain('private-provider-body');
});
it('redacts unexpected network errors', async () => {
  const request = vi.fn().mockRejectedValue(new Error('secret-network-details'));
  expect(JSON.stringify(await checkRodSms(env, request))).not.toContain('secret-network-details');
});
