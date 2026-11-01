import { expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { PlatformFundsService } from '../src/modules/platform/platform.funds';
const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 's' };
const decimal = (value: string) => new Prisma.Decimal(value);
function fixture(role = 'SUPER_ADMIN', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    donationPledge: { findMany: vi.fn().mockResolvedValueOnce([
      { id: 1n, orgId: 1n, donorId: 1n, amount: decimal('100.10') },
      { id: 2n, orgId: 1n, donorId: 1n, amount: decimal('50.20') },
    ]).mockResolvedValueOnce([
      { id: 1n, donorId: 1n, amount: decimal('100.10'), campaign: { title: 'Synthetic fund' }, organization: { name: 'Synthetic madrasa' } },
    ]) },
    donation: {
      groupBy: vi.fn().mockResolvedValue([{ pledgeId: 1n, _sum: { amount: decimal('120.10') } }]),
      aggregate: vi.fn().mockResolvedValue({ _sum: { amount: decimal('20.10') } }),
    },
  };
  const db = { $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformFundsService(db) };
}
it('keeps receipts distinct from pledges, caps outstanding per pledge and preserves decimals', async () => {
  const { tx, service } = fixture();
  const result = await service.overview(actor, { month: '2026-12', page: 2 });
  expect(result.summary).toEqual({ donors: 1, pledged: '150.30', received: '20.10', outstanding: '50.20' });
  expect(result.items[0]?.status).toBe('Received');
  expect(tx.donation.aggregate).toHaveBeenCalledWith(expect.objectContaining({ where: {
    currency: 'TZS', status: 'RECEIVED', receivedAt: { gte: new Date('2026-12-01'), lt: new Date('2027-01-01') },
  } }));
  expect(tx.donation.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ status: 'RECEIVED', receivedAt: { lt: new Date('2027-01-01') } }) }));
  expect(tx.donationPledge.findMany).toHaveBeenLastCalledWith(expect.objectContaining({ skip: 10, take: 10 }));
});
for (const role of ['IT_SECURITY', 'ADMIN', 'ACCOUNTANT', 'TEACHER']) it(`denies ${role}`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.overview(actor, { month: '2026-10' })).rejects.toMatchObject({ statusCode: 403 });
  await expect(service.pdf(actor, { month: '2026-10' })).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.donationPledge.findMany).not.toHaveBeenCalled();
});
it('denies disabled accounts', async () => {
  const { service } = fixture('SUPER_ADMIN', 'DISABLED');
  await expect(service.overview(actor, { month: '2026-10' })).rejects.toMatchObject({ statusCode: 403 });
});
it('validates filters before querying data', async () => {
  const { service, tx } = fixture();
  for (const query of [{ month: '2026-13' }, { month: '2026-10', page: 0 }, { month: '2026-10', currency: 'all' }]) {
    await expect(service.overview(actor, query)).rejects.toThrow();
  }
  expect(tx.donationPledge.findMany).not.toHaveBeenCalled();
});
it('empty month returns honest zero amounts', async () => {
  const { service, tx } = fixture();
  tx.donationPledge.findMany.mockReset().mockResolvedValue([]);
  tx.donation.groupBy.mockResolvedValue([]);
  tx.donation.aggregate.mockResolvedValue({ _sum: { amount: null as never } });
  const result = await service.overview(actor, { month: '2026-10' });
  expect(result.summary).toEqual({ donors: 0, pledged: '0.00', received: '0.00', outstanding: '0.00' });
  expect(result.items).toEqual([]);
});
