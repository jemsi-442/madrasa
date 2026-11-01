import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import type { AuthenticatedUser } from '../src/shared/middleware/authenticate';
const store = vi.hoisted(() => {
  const tx = {
    donor: { findFirst: vi.fn() }, fundraisingCampaign: { findFirst: vi.fn() },
    donation: { create: vi.fn() }, donationSms: { create: vi.fn() }, auditLog: { create: vi.fn() },
  };
  return { tx, db: { donation: { findUnique: vi.fn() }, $transaction: vi.fn() } };
});
vi.mock('../src/shared/db/prisma', () => ({ prisma: store.db }));
import { recordDonation } from '../src/modules/fundraising/fundraising.service';
const actor = { role: 'ADMIN', orgId: '1', userId: '2' } as AuthenticatedUser;
const input = { donorId: '3', campaignId: '4', amount: '100.00', method: 'CASH' as const,
  receivedAt: '2026-01-01T00:00:00Z', idempotencyKey: '00000000-0000-4000-8000-000000000001' };
beforeEach(() => {
  vi.clearAllMocks();
  store.db.donation.findUnique.mockResolvedValue(null);
  store.tx.donor.findFirst.mockResolvedValue({ id: 3n });
  store.tx.fundraisingCampaign.findFirst.mockResolvedValue({ id: 4n, status: 'ACTIVE' });
  store.tx.donation.create.mockImplementation(async ({ data }) => ({ id: 10n, ...data }));
  store.db.$transaction.mockImplementation(async fn => fn(store.tx));
  vi.stubEnv('SMS_ENABLED', 'true'); vi.stubEnv('DONATION_SMS_ENABLED', 'true');
});
afterEach(() => vi.unstubAllEnvs());
it('creates one notification inside the donation transaction and not on HTTP replay', async () => {
  const row = await recordDonation(actor, input);
  expect(store.tx.donationSms.create).toHaveBeenCalledExactlyOnceWith({ data: { donationId: 10n } });
  store.db.donation.findUnique.mockResolvedValue(row);
  await recordDonation(actor, input);
  expect(store.tx.donation.create).toHaveBeenCalledTimes(1);
  expect(store.tx.donationSms.create).toHaveBeenCalledTimes(1);
});
it('disabled SMS keeps donation recording independent of the new queue table', async () => {
  vi.stubEnv('DONATION_SMS_ENABLED', 'false');
  await recordDonation(actor, input);
  expect(store.tx.donation.create).toHaveBeenCalledTimes(1);
  expect(store.tx.donationSms.create).not.toHaveBeenCalled();
});
