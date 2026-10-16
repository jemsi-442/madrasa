import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
const actor = { scope: 'platform' as const, accountId: 'office', sessionId: 's' };
function fixture(role = 'SUPER_ADMIN', status = 'ACTIVE') {
  const tx = {
    studentGuardian: { count: vi.fn().mockResolvedValue(4) },
    tenantApplication: { count: vi.fn().mockResolvedValue(2) },
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'office', role, status }) },
    user: { count: vi.fn().mockResolvedValue(1), findMany: vi.fn().mockResolvedValue([
      { id: 2n, fullName: 'School Admin', role: 'ADMIN', status: 'ACTIVE',
        organization: { id: 1n, name: 'School', code: 'AFQ', status: 'ACTIVE' } },
    ]) },
  };
  return { tx, service: new PlatformGovernanceService({ $transaction: (fn: (arg: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
it('restricts results to staff and returns only office-safe fields', async () => {
  const f = fixture();
  const data = await f.service.staffDirectory(actor);
  expect(data.items[0]?.school.id).toBe('1');
  expect(data.summary).toEqual({ admins: 1, teachers: 1, guardianLinks: 4, pendingRequests: 2 });
  expect(f.tx.tenantApplication.count).toHaveBeenCalledWith({ where: { status: 'REQUESTED', organizationId: null } });
  expect(f.tx.user.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: { role: { in: ['ADMIN', 'TEACHER', 'ACCOUNTANT'] } }, take: 25, skip: 0,
    select: { id: true, fullName: true, role: true, status: true,
      organization: { select: { id: true, name: true, code: true, status: true } } },
  }));
});
it('applies role, status, search and pagination together', async () => {
  const f = fixture();
  await f.service.staffDirectory(actor, { role: 'TEACHER', status: 'DISABLED', search: ' School ', page: '2' });
  expect(f.tx.user.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 25,
    where: expect.objectContaining({ role: 'TEACHER', status: 'DISABLED', OR: expect.arrayContaining([{ fullName: { contains: 'School' } }]) }) }));
});
for (const role of ['IT_SECURITY', 'ADMIN', 'PARENT']) it(`rejects ${role}`, async () => {
  const f = fixture(role);
  await expect(f.service.staffDirectory(actor)).rejects.toMatchObject({ statusCode: 403 });
  expect(f.tx.user.count).not.toHaveBeenCalled();
  expect(f.tx.studentGuardian.count).not.toHaveBeenCalled();
});
it('rejects disabled Super Admin and unsupported roles', async () => {
  const f = fixture('SUPER_ADMIN', 'DISABLED');
  await expect(f.service.staffDirectory(actor)).rejects.toMatchObject({ statusCode: 403 });
  for (const role of ['PARENT', 'LEARNER', 'SUPER_ADMIN']) {
    await expect(fixture().service.staffDirectory(actor, { role })).rejects.toThrow();
  }
});
