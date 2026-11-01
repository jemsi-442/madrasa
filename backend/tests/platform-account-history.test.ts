import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
import { hasPlatformPermission } from '../src/modules/platform/platform.permissions';
const actor = { scope: 'platform' as const, accountId: 'admin', sessionId: 'session' };
function fixture(role = 'SUPER_ADMIN') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValueOnce({ id: 'admin', role, status: 'ACTIVE' }).mockResolvedValue({ id: 'it' }) },
    platformAuditEvent: { findMany: vi.fn().mockResolvedValue([{ id: 'event', action: 'platform.account.disabled', actorId: 'admin', createdAt: new Date(), metadata: { reason: 'Reviewed suspension', status: 'DISABLED', password: 'never expose', nested: { token: 'secret' } } }]) },
  };
  return { tx, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('restricted account access history', () => {
  it('IT account access does not grant lifecycle or curriculum changes', () => {
    expect(hasPlatformPermission('IT_SECURITY', 'platform.account.read')).toBe(true);
    for (const permission of ['platform.account.disable.it', 'platform.account.restore.it', 'curriculum.manage'] as const) {
      expect(hasPlatformPermission('IT_SECURITY', permission)).toBe(false);
    }
  });
  it('IT directory selects only public account fields', async () => {
    const f = fixture('IT_SECURITY');
    Object.assign(f.tx.platformAccount, { findMany: vi.fn().mockResolvedValue([]) });
    await expect(f.service.listAccounts(actor, { role: 'IT_SECURITY', status: 'ACTIVE' })).resolves.toEqual([]);
    expect((f.tx.platformAccount as any).findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { role: 'IT_SECURITY', status: 'ACTIVE' },
      select: { id: true, fullName: true, email: true, role: true, status: true, createdAt: true },
    }));
  });
  it('bounds history to one platform account and approved event types', async () => {
    const f = fixture();
    const events = await f.service.accountAccessHistory(actor, 'it', { page: 2, pageSize: 10 });
    expect(f.tx.platformAuditEvent.findMany).toHaveBeenCalledWith({
      where: { entityType: 'PlatformAccount', entityId: 'it', action: { in: ['platform.account.disabled', 'platform.account.restored'] } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: 10, take: 10,
      select: { id: true, action: true, actorId: true, createdAt: true, metadata: true },
    });
    expect(events[0]).toMatchObject({ reason: 'Reviewed suspension', metadata: { status: 'DISABLED' } });
    expect(JSON.stringify(events)).not.toContain('secret');
    expect(JSON.stringify(events)).not.toContain('password');
  });
  it('allows IT to inspect sanitized access history', async () => {
    const f = fixture('IT_SECURITY');
    const events = await f.service.accountAccessHistory(actor, 'it');
    expect(events[0]).toMatchObject({ reason: 'Reviewed suspension' });
    expect(JSON.stringify(events)).not.toContain('secret');
  });
  it.each(['ADMIN', 'ACCOUNTANT', 'TEACHER', 'UNKNOWN'])('denies role %s', async (role) => {
    const f = fixture(role);
    await expect(f.service.accountAccessHistory(actor, 'it')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
  it('rejects query injection', async () => {
    const f = fixture();
    await expect(f.service.accountAccessHistory(actor, 'it', { entityId: 'other' })).rejects.toThrow();
    expect(f.tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
  it('returns 404 for a missing platform account', async () => {
    const f = fixture(); f.tx.platformAccount.findUnique.mockResolvedValue(null);
    await expect(f.service.accountAccessHistory(actor, 'missing')).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
});
