import { afterEach, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { DonorMessagesService } from '../src/modules/platform/platform.donor-messages';
import { processManualDonorSms } from '../src/jobs/manual-donor-sms';
afterEach(() => vi.unstubAllEnvs());
const actor = { scope: 'platform' as const, accountId: 'super', sessionId: 'session' };
const donor = { id: 1n, fullName: 'Synthetic donor', phone: '255700000000', smsOptIn: true, organization: { name: 'Synthetic madrasa', status: 'ACTIVE' } };
function fixture(role = 'SUPER_ADMIN') {
  const draft = { id: 'message-1', revision: 1, status: 'DRAFT', creatorId: 'super', body: 'Synthetic message',
    recipients: [{ id: 1n, donorId: 1n, phone: donor.phone, donor }] };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'super', role, status: 'ACTIVE', fullName: 'Synthetic sender' }) },
    donor: { findMany: vi.fn().mockResolvedValue([donor]), findUnique: vi.fn().mockResolvedValue(donor), update: vi.fn() },
    donorMessage: { create: vi.fn().mockResolvedValue(draft), updateMany: vi.fn().mockResolvedValue({ count: 1 }), findFirst: vi.fn().mockResolvedValue(draft), findUniqueOrThrow: vi.fn().mockResolvedValue(draft), findMany: vi.fn().mockResolvedValue([]) },
    donorMessageRecipient: { deleteMany: vi.fn(), createMany: vi.fn(), updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    platformAuditEvent: { create: vi.fn() },
  };
  const service = new DonorMessagesService({ $transaction: (fn: (connection: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
  return { service, tx, draft };
}
function enable() {
  vi.stubEnv('SMS_ENABLED', 'true'); vi.stubEnv('DONOR_MANUAL_SMS_ENABLED', 'true');
  vi.stubEnv('SMS_PROVIDER', 'meseji'); vi.stubEnv('MESEJI_API_KEY', 'synthetic'); vi.stubEnv('MESEJI_SENDER_ID', 'AFAQ');
}
it.each(['granted', 'missing'])('filters %s consent before pagination', async consent => {
  const { service, tx } = fixture();
  await service.recipients(actor, { consent, page: 2, q: 'Synthetic' });
  expect(tx.donor.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: expect.objectContaining({ smsOptIn: consent === 'granted', organization: { status: 'ACTIVE' } }),
    skip: 20, take: 21,
  }));
});
it('rejects unknown recipient filters', async () => {
  const { service, tx } = fixture();
  await expect(service.recipients(actor, { consent: 'anything' })).rejects.toThrow();
  expect(tx.donor.findMany).not.toHaveBeenCalled();
});
for (const role of ['IT_SECURITY', 'ACCOUNTANT', 'ADMIN']) it(`denies ${role} before reading donor data`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.recipients(actor, {})).rejects.toMatchObject({ statusCode: 403 });
  await expect(service.save(actor, { body: 'Hello', donorIds: ['1'] })).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.donor.findMany).not.toHaveBeenCalled();
});
it('saves exact text and snapshots recipient details without sending', async () => {
  const { service, tx } = fixture();
  await service.save(actor, { body: 'Synthetic message', donorIds: ['1', '1'] });
  expect(tx.donorMessageRecipient.createMany).toHaveBeenCalledWith({ data: [{ messageId: 'message-1', donorId: 1n, donorName: donor.fullName, madrasaName: donor.organization.name, phone: donor.phone }] });
  expect(tx.donorMessageRecipient.updateMany).not.toHaveBeenCalled();
});
it('rejects non-consenting recipients and duplicate phone numbers', async () => {
  const { service, tx } = fixture();
  tx.donor.findMany.mockResolvedValue([{ ...donor, smsOptIn: false }]);
  await expect(service.save(actor, { body: 'Synthetic', donorIds: ['1'] })).rejects.toMatchObject({ statusCode: 409 });
  tx.donor.findMany.mockResolvedValue([donor, { ...donor, id: 2n }]);
  await expect(service.save(actor, { body: 'Synthetic', donorIds: ['1', '2'] })).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.donorMessage.create).not.toHaveBeenCalled();
});
it('refuses stale edits rather than overwriting queued messages', async () => {
  const { service, tx } = fixture();
  tx.donorMessage.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.save(actor, { id: 'message-1', revision: 1, body: 'changed', donorIds: ['1'] })).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.donorMessageRecipient.deleteMany).not.toHaveBeenCalled();
});
it('requires configuration and rechecks consent before queueing', async () => {
  const { service, tx, draft } = fixture();
  vi.stubEnv('DONOR_MANUAL_SMS_ENABLED', 'false');
  await expect(service.send(actor, 'message-1', { revision: 1 })).rejects.toMatchObject({ statusCode: 503 });
  enable();
  tx.donorMessage.findFirst.mockResolvedValue({ ...draft, recipients: [{ ...draft.recipients[0], donor: { ...donor, smsOptIn: false } }] });
  await expect(service.send(actor, 'message-1', { revision: 1 })).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.donorMessageRecipient.updateMany).not.toHaveBeenCalled();
});
it('queues once and retries return the already queued message', async () => {
  enable();
  const { service, tx, draft } = fixture();
  await service.send(actor, 'message-1', { revision: 1 });
  tx.donorMessage.findFirst.mockResolvedValue({ ...draft, status: 'QUEUED' });
  await service.send(actor, 'message-1', { revision: 1 });
  expect(tx.donorMessageRecipient.updateMany).toHaveBeenCalledTimes(1);
  expect(tx.donorMessage.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'message-1', creatorId: 'super' } }));
});
it('worker does not send after consent withdrawal', async () => {
  const db = { donorMessageRecipient: {
    updateMany: vi.fn().mockResolvedValue({ count: 1 }), findMany: vi.fn().mockResolvedValue([{ id: 1n, phone: donor.phone }]),
    findUniqueOrThrow: vi.fn().mockResolvedValue({ donor: { ...donor, smsOptIn: false }, message: { creatorId: 'super', body: 'Synthetic', status: 'QUEUED', queuedAt: new Date() } }), update: vi.fn(),
  }, platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'SUPER_ADMIN', status: 'ACTIVE' }) } };
  const send = vi.fn();
  await processManualDonorSms(db as unknown as PrismaClient, { apiKey: 'synthetic', senderId: 'AFAQ' }, send);
  expect(send).not.toHaveBeenCalled();
  expect(db.donorMessageRecipient.update).toHaveBeenCalledWith({ where: { id: 1n }, data: { status: 'SKIPPED', reason: 'CONSENT_WITHDRAWN' } });
});
