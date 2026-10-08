import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { activateSchool } from '../src/modules/platform/platform.activation';

const actor = { scope: 'platform' as const, accountId: 'reviewer', sessionId: 'verified-session' };
const input = { invitationId: 'invite', evidenceReference: 'staging-review-record-123', checks: {
  tenantIsolation: true, accessControls: true, auditTrail: true, backupRecovery: true, supportEscalation: true,
} };
function fixture(role = 'SUPER_ADMIN') {
  const application = { id: 'application', status: 'APPROVED', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(),
    provisionedAt: new Date(), adminEmail: 'admin@example.test', organization: { id: 7n, status: 'PENDING_ACTIVATION' },
    adminInvitation: { id: 'invite', email: 'admin@example.test', acceptedAt: new Date(),
      acceptedUser: { id: 9n, orgId: 7n, email: 'admin@example.test', role: 'ADMIN', status: 'DISABLED' } },
  };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, status: 'ACTIVE', role }) },
    tenantApplication: { findUnique: vi.fn().mockResolvedValue(application) },
    organization: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    user: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    platformAuditEvent: { create: vi.fn(), findFirst: vi.fn().mockResolvedValue(null) },
  };
  return { application, tx, db: { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient };
}
describe('guarded school activation foundation', () => {
  it('enables only the linked school/admin and records operator attestations', async () => {
    const f = fixture();
    expect(await activateSchool(f.db, actor, 'application', input)).toEqual({ organizationId: '7', status: 'ACTIVE', activated: true });
    expect(f.tx.organization.updateMany).toHaveBeenCalledWith({ where: { id: 7n, status: 'PENDING_ACTIVATION' }, data: { status: 'ACTIVE' } });
    expect(f.tx.user.updateMany).toHaveBeenCalledWith({ where: { id: 9n, orgId: 7n, email: 'admin@example.test', role: 'ADMIN', status: 'DISABLED' }, data: { status: 'ACTIVE' } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: 'tenant.school.activated', metadata: expect.objectContaining({ operatorAttestations: input.checks, evidenceReference: input.evidenceReference }) }) });
  });
  it.each(['IT_SECURITY', 'ADMIN', 'PARENT'])('denies activation to %s', async (role) => {
    const f = fixture(role);
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findUnique).not.toHaveBeenCalled();
  });
  it('requires another Super Admin than the requester', async () => {
    const f = fixture(); f.application.requestedById = actor.accountId; f.application.reviewedById = 'other';
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 403 });
  });
  it.each(['tenantIsolation', 'accessControls', 'auditTrail', 'backupRecovery', 'supportEscalation'])('requires the %s attestation', async (check) => {
    const f = fixture();
    await expect(activateSchool(f.db, actor, 'application', { ...input, checks: { ...input.checks, [check]: false } })).rejects.toThrow();
    expect(f.tx.platformAccount.findUnique).not.toHaveBeenCalled();
  });
  it('rejects a stale invitation ID and a missing acceptance', async () => {
    const f = fixture();
    await expect(activateSchool(f.db, actor, 'application', { ...input, invitationId: 'old-invite' })).rejects.toMatchObject({ statusCode: 409 });
    f.tx.tenantApplication.findUnique.mockResolvedValue({ ...f.application, adminInvitation: null });
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
  });
  it.each(['orgId', 'email', 'role'])('rejects a mismatched accepted user %s', async (field) => {
    const f = fixture();
    Object.assign(f.application.adminInvitation.acceptedUser, { [field]: field === 'orgId' ? 99n : 'wrong' });
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
  });
  it('does not reactivate a suspended school', async () => {
    const f = fixture(); f.application.organization.status = 'SUSPENDED';
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
  it('returns a recorded replay without enabling a subsequently disabled user', async () => {
    const f = fixture(); f.application.organization.status = 'ACTIVE'; f.application.adminInvitation.acceptedUser.status = 'ACTIVE';
    f.tx.platformAuditEvent.findFirst.mockResolvedValue({ id: 'receipt' });
    expect((await activateSchool(f.db, actor, 'application', input)).activated).toBe(false);
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
    f.application.adminInvitation.acceptedUser.status = 'DISABLED';
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
  it('requires a recorded provisioning timestamp before activation', async () => {
    const f = fixture();
    f.tx.tenantApplication.findUnique.mockResolvedValue({ ...f.application, provisionedAt: null });
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it.each(['PENDING_ACTIVATION', 'SUSPENDED', 'TRIAL'])('does not re-activate a previously activated school now marked %s', async (status) => {
    const f = fixture(); f.application.organization.status = status;
    f.tx.platformAuditEvent.findFirst.mockResolvedValue({ id: 'receipt' });
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('rejects active access without an activation audit receipt', async () => {
    const f = fixture(); f.application.organization.status = 'ACTIVE'; f.application.adminInvitation.acceptedUser.status = 'ACTIVE';
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
});
