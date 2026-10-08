import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
const actor = { scope: 'platform' as const, accountId: 'admin', sessionId: 'session' };
function fixture(role = 'SUPER_ADMIN') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'admin', role, status: 'ACTIVE' }), groupBy: vi.fn().mockResolvedValue([{ role: 'IT_SECURITY', status: 'DISABLED', _count: { _all: 2 } }]) },
    tenantApplication: { groupBy: vi.fn().mockResolvedValue([{ status: 'REQUESTED', _count: { _all: 3 } }]), count: vi.fn().mockResolvedValue(1) },
  };
  return { tx, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('platform governance overview', () => {
  it('aggregates platform counts and excludes own requests from independent review', async () => {
    const f = fixture();
    const result = await f.service.overview(actor);
    expect(result).toMatchObject({ applications: { REQUESTED: 3, APPROVED: 0, REJECTED: 0 }, awaitingYourReview: 1,
      accounts: { SUPER_ADMIN: { ACTIVE: 0, DISABLED: 0 }, IT_SECURITY: { ACTIVE: 0, DISABLED: 2 } } });
    expect(f.tx.tenantApplication.count).toHaveBeenCalledWith({ where: { status: 'REQUESTED', requestedById: { not: 'admin' } } });
    expect(f.tx.platformAccount.groupBy).toHaveBeenCalledWith({ by: ['role', 'status'], _count: { _all: true } });
    expect(Number.isNaN(Date.parse(result.checkedAt))).toBe(false);
  });
  it.each(['IT_SECURITY', 'ADMIN'])('denies %s without reading aggregates', async (role) => {
    const f = fixture(role);
    await expect(f.service.overview(actor)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.groupBy).not.toHaveBeenCalled();
  });
  it('does not return fabricated zeros on database failure', async () => {
    const f = fixture(); f.tx.tenantApplication.groupBy.mockRejectedValue(new Error('database unavailable'));
    await expect(f.service.overview(actor)).rejects.toThrow('database unavailable');
  });
});
