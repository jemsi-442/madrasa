import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformSyncService } from '../src/modules/platform/platform.sync';
const actor = { scope: 'platform' as const, accountId: 'synthetic-it', sessionId: 'synthetic-session' };
function setup(role = 'IT_SECURITY', status = 'ACTIVE') {
  const tx = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    auditLog: { findMany: vi.fn().mockResolvedValue([{ id: 1n, orgId: 2n, createdAt: new Date('2026-01-01T00:00:00Z') }]), count: vi.fn().mockResolvedValue(1) } };
  return { tx, service: new PlatformSyncService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
it.each(['SUPER_ADMIN', 'TEACHER', 'ACCOUNTANT', 'ADMIN'])('rejects %s', async role => {
  const { tx, service } = setup(role);
  await expect(service.received(actor, {})).rejects.toThrow('restricted');
  expect(tx.auditLog.findMany).not.toHaveBeenCalled();
});
it('rejects disabled IT accounts', async () => {
  await expect(setup('IT_SECURITY', 'DISABLED').service.received(actor, {})).rejects.toThrow('restricted');
});
it('returns metadata only and does not infer device or conflict status', async () => {
  const { tx, service } = setup();
  const result = await service.received(actor, { page: '2' });
  expect(result.items[0]).toEqual({ receiptId: '1', madrasaId: '2', receivedAt: new Date('2026-01-01T00:00:00Z') });
  expect(result.deviceReportingConnected).toBe(false);
  expect(result.conflictQueueConnected).toBe(false);
  expect(tx.auditLog.findMany.mock.calls[0]![0]).toMatchObject({ skip: 20, take: 20, select: { id: true, orgId: true, createdAt: true } });
});
it('rejects unbounded pagination', async () => {
  await expect(setup().service.received(actor, { page: 0 })).rejects.toThrow();
});
