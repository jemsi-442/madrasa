import { afterEach, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { sendMesejiSms, smsPhone } from '../src/shared/notifications/meseji-sms';
import { processDonationSms, startDonationSmsWorker } from '../src/jobs/donation-sms';
const config = { apiKey: 'synthetic-key', senderId: 'AFAQ' };
afterEach(() => vi.unstubAllEnvs());
it('normalizes phone numbers without accepting multi-recipient input', () => {
  expect(smsPhone('0712345678')).toBe('255712345678');
  expect(smsPhone('+254712345678')).toBe('254712345678');
  expect(smsPhone('255712345678,255712345679')).toBeNull();
  expect(smsPhone(null)).toBeNull();
});
it('sends the documented API contract and records acceptance, not delivery', async () => {
  const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ status: 'queued', batch_id: 'synthetic-batch' })));
  expect(await sendMesejiSms(config, '255700000000', 'Synthetic receipt', request)).toEqual({ status: 'ACCEPTED', batchId: 'synthetic-batch' });
  const options = request.mock.calls[0]![1];
  expect(options.headers['x-api-key']).toBe('synthetic-key');
  expect(JSON.parse(options.body)).toEqual({ sender_id: 'AFAQ', contacts: '255700000000', message: 'Synthetic receipt' });
});
for (const status of [401, 429, 500]) it(`handles provider HTTP ${status} without claiming delivery`, async () => {
  const request = vi.fn().mockResolvedValue(new Response('{}', { status }));
  expect((await sendMesejiSms(config, '255700000000', 'Synthetic', request)).status).toBe(status === 500 ? 'UNKNOWN' : 'FAILED');
  expect(request).toHaveBeenCalledTimes(1);
});
it('does not retry ambiguous timeouts', async () => {
  const request = vi.fn().mockRejectedValue(new Error('timeout'));
  expect((await sendMesejiSms(config, '255700000000', 'Synthetic', request)).status).toBe('UNKNOWN');
  expect(request).toHaveBeenCalledTimes(1);
});
function fixture(status = 'RECEIVED', orgStatus = 'ACTIVE', phone: string | null = '255700000000') {
  const db = {
    donationSms: {
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findMany: vi.fn().mockResolvedValue([{ id: 1n, donationId: 10n, createdAt: new Date() }]),
      update: vi.fn().mockResolvedValue({}),
    },
    donation: { findUnique: vi.fn().mockResolvedValue({ id: 10n, amount: new Prisma.Decimal('50.10'), currency: 'TZS', status, organization: { status: orgStatus }, donor: { phone } }) },
  };
  const send = vi.fn().mockResolvedValue({ status: 'ACCEPTED', batchId: 'test' });
  return { db, send, run: () => processDonationSms(db as unknown as PrismaClient, config, send) };
}
it('claims a queued receipt before sending and persists provider reference', async () => {
  const { db, send, run } = fixture();
  await run();
  expect(send).toHaveBeenCalledWith({ ...config, idempotencyKey: expect.stringMatching(/^afaq-receipt-1-\d+$/) }, '255700000000', expect.stringContaining('TZS 50.10'));
  expect(db.donationSms.update).toHaveBeenCalledWith({ where: { id: 1n }, data: { status: 'ACCEPTED', batchId: 'test', reason: null } });
});
it('a competing worker cannot send the same claimed job', async () => {
  const { db, send, run } = fixture();
  db.donationSms.updateMany.mockResolvedValue({ count: 0 });
  await run();
  expect(send).not.toHaveBeenCalled();
});
for (const [status, org, phone] of [['VOIDED', 'ACTIVE', '255700000000'], ['RECEIVED', 'SUSPENDED', '255700000000'], ['RECEIVED', 'ACTIVE', null]] as const) {
  it(`skips ineligible receipt ${status}/${org}/${phone === null}`, async () => {
    const { db, send, run } = fixture(status, org, phone);
    await run();
    expect(send).not.toHaveBeenCalled();
    expect(db.donationSms.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'SKIPPED' }) }));
  });
}
it('does not start or read the queue while the feature is disabled', () => {
  vi.stubEnv('SMS_ENABLED', 'false');
  const db = fixture().db;
  startDonationSmsWorker(db as unknown as PrismaClient)();
  expect(db.donationSms.findMany).not.toHaveBeenCalled();
});
