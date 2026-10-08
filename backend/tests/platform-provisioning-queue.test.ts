import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';

const actor = { scope: 'platform' as const, accountId: 'operator', sessionId: 'session' };
function fixture(role = 'IT_SECURITY') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'operator', role, status: 'ACTIVE' }) },
    tenantApplication: { findMany: vi.fn().mockResolvedValue([{ id: 'application', schoolName: 'School', requestedCode: 'school', reviewedAt: new Date(), organization: { id: 45n, status: 'PENDING_ACTIVATION' } }]) },
  };
  return { tx, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('IT provisioning queue', () => {
  it('returns only approved handoffs with bounded pages and no contact or review reasons', async () => {
    const f = fixture();
    const result = await f.service.listProvisioningQueue(actor, { page: 2, pageSize: 20 });
    expect(f.tx.tenantApplication.findMany).toHaveBeenCalledWith({
      where: { status: 'APPROVED' }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: 20, take: 20,
      select: { id: true, schoolName: true, requestedCode: true, reviewedAt: true, organization: { select: { id: true, status: true } } },
    });
    expect(result[0]!.organization!.id).toBe('45');
    expect(() => JSON.stringify(result)).not.toThrow();
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'PARENT'])('denies %s the IT execution queue', async (role) => {
    const f = fixture(role);
    await expect(f.service.listProvisioningQueue(actor)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findMany).not.toHaveBeenCalled();
  });
  it('rejects caller-supplied application status', async () => {
    const f = fixture();
    await expect(f.service.listProvisioningQueue(actor, { status: 'REQUESTED' })).rejects.toThrow();
    expect(f.tx.tenantApplication.findMany).not.toHaveBeenCalled();
  });
  it('searches only school names and codes while retaining approved scope and pagination', async () => {
    const f = fixture();
    await f.service.listProvisioningQueue(actor, { q: '  Afaq  ', page: 2, pageSize: 20 });
    expect(f.tx.tenantApplication.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { status: 'APPROVED', OR: [{ schoolName: { contains: 'Afaq' } }, { requestedCode: { contains: 'Afaq' } }] },
      skip: 20, take: 20,
    }));
  });
  it('escapes wildcard characters and accepts whitespace as an unfiltered query', async () => {
    const f = fixture();
    await f.service.listProvisioningQueue(actor, { q: '%_\\' });
    expect(f.tx.tenantApplication.findMany).toHaveBeenLastCalledWith(expect.objectContaining({
      where: { status: 'APPROVED', OR: [{ schoolName: { contains: '\\%\\_\\\\' } }, { requestedCode: { contains: '\\%\\_\\\\' } }] },
    }));
    await f.service.listProvisioningQueue(actor, { q: '  ' });
    expect(f.tx.tenantApplication.findMany).toHaveBeenLastCalledWith(expect.objectContaining({ where: { status: 'APPROVED' } }));
  });
  it.each(['x'.repeat(101), ['school'], { contains: 'school' }])('rejects invalid search input', async (q) => {
    const f = fixture();
    await expect(f.service.listProvisioningQueue(actor, { q })).rejects.toThrow();
    expect(f.tx.tenantApplication.findMany).not.toHaveBeenCalled();
  });
  it('serializes the linked ID in the Super Admin application list', async () => {
    const f = fixture('SUPER_ADMIN');
    f.tx.tenantApplication.findMany.mockResolvedValue([{ id: 'application', organizationId: 45n }]);
    const result = await f.service.listApplications(actor);
    expect(result[0]!.organizationId).toBe('45');
    expect(() => JSON.stringify(result)).not.toThrow();
  });
});
