import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';

const actor = { scope: 'platform' as const, accountId: 'operator', sessionId: 'session' };
function fixture(role = 'IT_SECURITY', status = 'ACTIVE') {
  const application = { id: 'application', requestedCode: 'afaq-school', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date() };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'operator', role, status }) },
    tenantApplication: { findFirst: vi.fn().mockResolvedValue(application) },
    organization: { findUnique: vi.fn().mockResolvedValue(null), create: vi.fn() },
    user: { create: vi.fn() },
  };
  return { tx, application, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('approved madrassa provisioning preflight', () => {
  it.each(['IT_SECURITY'])('allows %s to inspect without creating or activating a school', async (role) => {
    const f = fixture(role);
    const result = await f.service.provisioningPreflight(actor, 'application');
    expect(result).toMatchObject({ prerequisitesPassed: true, provisioningEnabled: false, checks: { independentReview: true, schoolCodeAvailable: true } });
    expect(f.tx.tenantApplication.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'application', status: 'APPROVED' } }));
    expect(f.tx.organization.findUnique).toHaveBeenCalledWith({ where: { code: 'afaq-school' }, select: { id: true } });
    expect(f.tx.organization.create).not.toHaveBeenCalled();
    expect(f.tx.user.create).not.toHaveBeenCalled();
    expect(result).not.toHaveProperty('adminEmail');
    expect(result).not.toHaveProperty('reviewedById');
  });
  it('reports an occupied code without disclosing the existing school', async () => {
    const f = fixture(); f.tx.organization.findUnique.mockResolvedValue({ id: 12n });
    const result = await f.service.provisioningPreflight(actor, 'application');
    expect(result.prerequisitesPassed).toBe(false);
    expect(result.checks.schoolCodeAvailable).toBe(false);
    expect(result).not.toHaveProperty('organization');
    expect(result).not.toHaveProperty('organizationId');
  });
  it.each([null, 'requester'])('blocks absent or non-independent reviewer %s', async (reviewedById) => {
    const f = fixture(); f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, reviewedById });
    expect((await f.service.provisioningPreflight(actor, 'application')).prerequisitesPassed).toBe(false);
  });
  it('requires a recorded review date', async () => {
    const f = fixture(); f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, reviewedAt: null });
    expect((await f.service.provisioningPreflight(actor, 'application')).checks.independentReview).toBe(false);
  });
  it('does not expose missing or unapproved applications', async () => {
    const f = fixture('IT_SECURITY'); f.tx.tenantApplication.findFirst.mockResolvedValue(null);
    await expect(f.service.provisioningPreflight(actor, 'application')).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.organization.findUnique).not.toHaveBeenCalled();
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'TEACHER', 'PARENT'])('denies non-IT role %s before reading applications', async (role) => {
    const f = fixture(role);
    await expect(f.service.provisioningPreflight(actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findFirst).not.toHaveBeenCalled();
  });
  it('denies disabled company accounts', async () => {
    const f = fixture('IT_SECURITY', 'DISABLED');
    await expect(f.service.provisioningPreflight(actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findFirst).not.toHaveBeenCalled();
  });
  it('fails closed on database failure', async () => {
    const f = fixture(); f.tx.organization.findUnique.mockRejectedValue(new Error('unavailable'));
    await expect(f.service.provisioningPreflight(actor, 'application')).rejects.toThrow('unavailable');
  });
});
