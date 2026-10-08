import { Prisma, type PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';

const actor = { scope: 'platform' as const, accountId: 'it', sessionId: 'session' };
function fixture(role = 'IT_SECURITY') {
  const application = { id: 'application', schoolName: 'Approved School', requestedCode: 'approved-school',
    status: 'APPROVED', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(), organization: null };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'it', role, status: 'ACTIVE' }) },
    tenantApplication: { findUnique: vi.fn().mockResolvedValue(application), updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    organization: { create: vi.fn().mockResolvedValue({ id: 9n, status: 'PENDING_ACTIVATION' }) },
    platformAuditEvent: { create: vi.fn() },
  };
  const transaction = vi.fn(async (run: (tx: unknown) => unknown) => run(tx));
  return { tx, transaction, application, service: new PlatformGovernanceService({ $transaction: transaction } as unknown as PrismaClient) };
}
describe('pending school provisioning', () => {
  it('uses approved details and commits an inactive school, application link and audit together', async () => {
    const f = fixture();
    expect(await f.service.provisionPendingSchool(actor, 'application')).toEqual({ organizationId: '9', status: 'PENDING_ACTIVATION', created: true });
    expect(f.transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'Serializable' });
    expect(f.tx.organization.create).toHaveBeenCalledWith({ data: { name: 'Approved School', code: 'approved-school', status: 'PENDING_ACTIVATION' }, select: { id: true, status: true } });
    expect(f.tx.tenantApplication.updateMany).toHaveBeenCalledWith({ where: { id: 'application', status: 'APPROVED', organizationId: null }, data: { organizationId: 9n, provisionedAt: expect.any(Date) } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ action: 'tenant.school.provisioned', actorRole: 'IT_SECURITY' }) }));
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'TEACHER'])('denies execution to %s', async (role) => {
    const f = fixture(role);
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findUnique).not.toHaveBeenCalled();
  });
  it.each(['REQUESTED', 'REJECTED'])('does not provision %s', async (status) => {
    const f = fixture(); f.tx.tenantApplication.findUnique.mockResolvedValue({ ...f.application, status });
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.organization.create).not.toHaveBeenCalled();
  });
  it('requires independent review even if status was changed incorrectly', async () => {
    const f = fixture(); f.tx.tenantApplication.findUnique.mockResolvedValue({ ...f.application, reviewedById: 'requester' });
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.create).not.toHaveBeenCalled();
  });
  it('replays the linked result without recreating, auditing or changing school status', async () => {
    const f = fixture(); f.tx.tenantApplication.findUnique.mockResolvedValue({ ...f.application, organization: { id: 9n, status: 'PENDING_ACTIVATION' } });
    expect(await f.service.provisionPendingSchool(actor, 'application')).toMatchObject({ organizationId: '9', created: false });
    expect(f.tx.organization.create).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('fails the transaction on an application race or audit failure', async () => {
    const f = fixture(); f.tx.tenantApplication.updateMany.mockResolvedValue({ count: 0 });
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
    f.tx.tenantApplication.updateMany.mockResolvedValue({ count: 1 });
    f.tx.platformAuditEvent.create.mockRejectedValue(new Error('audit failure'));
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toThrow('audit failure');
  });
  it.each(['P2002', 'P2034'])('returns a safe conflict for %s', async (code) => {
    const f = fixture(); f.tx.organization.create.mockRejectedValue(new Prisma.PrismaClientKnownRequestError('database detail', { code, clientVersion: 'test' }));
    await expect(f.service.provisionPendingSchool(actor, 'application')).rejects.toMatchObject({ statusCode: 409 });
  });
});
