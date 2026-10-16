import { it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';

const actor = { scope: 'platform' as const, accountId: 'office', sessionId: 'session' };
function fixture(role = 'SUPER_ADMIN') {
  const tx = {
    tenantApplication: { count: vi.fn().mockResolvedValue(0), findMany: vi.fn().mockResolvedValue([]) },
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'office', status: 'ACTIVE', role }) },
    user: { count: vi.fn().mockResolvedValue(1) },
    branch: { findMany: vi.fn().mockResolvedValue([{ location: 'Dar es Salaam' }]) },
    organization: { count: vi.fn().mockResolvedValue(1), findMany: vi.fn().mockResolvedValue([
      { id: 7n, name: 'Afaq Madrasa', code: 'AFQ', status: 'ACTIVE', users: [{ fullName: 'School Admin' }],
        branches: [{ location: 'Dar es Salaam' }],
        _count: { students: 24, users: 3 }, onboardingApplication: null },
    ]) },
  };
  const db = { $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformGovernanceService(db) };
}
it('returns aggregate school directory with search and bounded pagination', async () => {
  const { service, tx } = fixture();
  const result = await service.madrasaDirectory(actor, { search: ' AFQ ', status: 'ACTIVE', page: '2' });
  expect(result.items[0]).toEqual({ id: '7', name: 'Afaq Madrasa', code: 'AFQ', status: 'ACTIVE',
    admins: ['School Admin'], students: 24, teachers: 3, applicationId: null, locations: ['Dar es Salaam'] });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 25, take: 25,
    where: { status: 'ACTIVE', OR: [{ name: { contains: 'AFQ' } }, { code: { contains: 'AFQ' } }] } }));
});
for (const role of ['IT_SECURITY', 'ADMIN', 'TEACHER']) it(`denies directory to ${role}`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.madrasaDirectory(actor)).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.organization.findMany).not.toHaveBeenCalled();
});
it('rejects invalid page and status filters', async () => {
  const { service, tx } = fixture();
  for (const query of [{ page: -1 }, { status: 'UNKNOWN' }, { search: 'x'.repeat(101) }]) {
    await expect(service.madrasaDirectory(actor, query)).rejects.toThrow();
  }
  expect(tx.organization.count).not.toHaveBeenCalled();
});
it('filters by a real branch location and returns global summary', async () => {
  const { service, tx } = fixture();
  const result = await service.madrasaDirectory(actor, { location: 'Dar es Salaam' });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { branches: { some: { location: 'Dar es Salaam' } } } }));
  expect(result.summary).toEqual({ total: 1, active: 1, onboarding: 1, assignedAdmins: 1 });
  expect(result.locations).toEqual(['Dar es Salaam']);
});
it('exports filtered results, never silently truncates', async () => {
  const { service, tx } = fixture();
  await service.madrasaDirectory(actor, { export: 'true', page: '2' });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 0, take: 5000 }));
  tx.organization.count.mockResolvedValue(5001);
  await expect(service.madrasaDirectory(actor, { export: 'true' })).rejects.toMatchObject({ statusCode: 422 });
});
it('merges unprovisioned requests before schools and preserves independent review', async () => {
  const { service, tx } = fixture();
  tx.tenantApplication.count.mockResolvedValue(1);
  tx.tenantApplication.findMany.mockResolvedValue([{ id: 'request', schoolName: 'New Madrasa', requestedCode: 'NEW', status: 'REQUESTED', requestedById: actor.accountId, decisionReason: null }] as never);
  const result = await service.madrasaDirectory(actor);
  expect(result.total).toBe(2);
  expect(result.items[0]).toMatchObject({ id: 'application:request', status: 'REQUESTED', canReview: false, applicationId: 'request', students: null });
  expect(tx.tenantApplication.count).toHaveBeenCalledWith({ where: { organizationId: null } });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 0, take: 24 }));
});
it('continues organization pagination after pending records', async () => {
  const { service, tx } = fixture();
  tx.tenantApplication.count.mockResolvedValue(3);
  await service.madrasaDirectory(actor, { page: 2 });
  expect(tx.tenantApplication.findMany).not.toHaveBeenCalled();
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 22, take: 25 }));
});
