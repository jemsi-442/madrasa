import { describe, expect, it, vi } from 'vitest';
import { sendSms, smsConfig } from '../src/shared/notifications/sms-provider';

const config = { provider: 'rodsms' as const, apiKey: 'synthetic-test-key', senderId: 'AFAQ' };
describe('SMS provider selection', () => {
  it('requires credentials for the selected provider only', () => {
    expect(smsConfig({ SMS_PROVIDER: 'rodsms', MESEJI_API_KEY: 'test', MESEJI_SENDER_ID: 'AFAQ' })).toBeNull();
    expect(smsConfig({ SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: config.apiKey, RODSMS_SENDER_ID: 'AFAQ', RODSMS_BASE_URL: 'https://www.rodsms.com/api/v1/' })).toEqual({ ...config, baseUrl: 'https://www.rodsms.com/api/v1' });
    expect(smsConfig({ SMS_PROVIDER: 'other' })).toBeNull();
  });
  it('rejects an untrusted base URL without sending credentials', async () => {
    const request = vi.fn();
    expect(smsConfig({ SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: config.apiKey, RODSMS_SENDER_ID: 'AFAQ', RODSMS_BASE_URL: 'https://example.test/api/v1' })).toBeNull();
    expect(await sendSms({ ...config, baseUrl: 'https://example.test/api/v1' }, '255700000001', 'Test', request)).toEqual({ status: 'FAILED', reason: 'INVALID_CONFIGURATION' });
    expect(request).not.toHaveBeenCalled();
  });
  it('sends the approved uppercase sender and accepts queued, not delivered', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ success: true, data: { id: 'msg_42', submission_status: 'queued' } }), { status: 202 }));
    expect(await sendSms(config, '255700000001', 'Synthetic test', request)).toEqual({ status: 'ACCEPTED', batchId: 'msg_42' });
    expect(request).toHaveBeenCalledWith('https://www.rodsms.com/api/v1/messages', expect.objectContaining({
      headers: expect.objectContaining({ 'Content-Type': 'application/json', Authorization: 'Bearer synthetic-test-key', 'Idempotency-Key': expect.stringMatching(/^afaq-/) }),
      body: JSON.stringify({ sender_id: 'AFAQ', recipient: '255700000001', message: 'Synthetic test' }),
    }));
  });
  it('preserves a stable job key across repeated provider requests', async () => {
    const request = vi.fn().mockResolvedValue(new Response('{}', { status: 503 }));
    const job = { ...config, idempotencyKey: 'afaq-manual-synthetic-1' };
    await sendSms(job, '255700000001', 'Test', request);
    await sendSms(job, '255700000001', 'Test', request);
    for (const call of request.mock.calls) {
      expect(call[1].headers['Idempotency-Key']).toBe(job.idempotencyKey);
    }
  });
  it.each([401, 402, 403, 422, 429])('records rejected HTTP %s without retry', async status => {
    const request = vi.fn().mockResolvedValue(new Response('{}', { status }));
    expect(await sendSms(config, '255700000001', 'Test', request)).toEqual({ status: 'FAILED', reason: `HTTP_${status}` });
    expect(request).toHaveBeenCalledTimes(1);
  });
  it.each(['network', 'server', 'malformed'])('never falls back on %s uncertainty', async scenario => {
    const request = vi.fn();
    if (scenario === 'network') request.mockRejectedValue(new Error('timeout'));
    else request.mockResolvedValue(new Response('{}', { status: scenario === 'server' ? 503 : 202 }));
    expect((await sendSms(config, '255700000001', 'Test', request)).status).toBe('UNKNOWN');
    expect(request).toHaveBeenCalledTimes(1);
  });
});
