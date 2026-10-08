import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { activateSchool } from '../src/modules/platform/platform.activation';
import { technicalReviewFingerprint } from '../src/modules/platform/platform.technical-review';

const actor = { scope: 'platform' as const, accountId: 'reviewer', sessionId: 'verified-session' };
const input = { invitationId: 'invite', technicalReviewId: 'technical-review', approvalReason: 'Office onboarding approval recorded' };
function fixture(role = 'SUPER_ADMIN') {
  const application = { id: 'application', status: 'APPROVED', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(),
    provisionedAt: new Date(), adminEmail: 'admin@example.test', organization: { id: 7n, status: 'PENDING_ACTIVATION' },
    adminInvitation: { id: 'invite', email: 'admin@example.test', acceptedAt: new Date(),
      acceptedUser: { id: 9n, orgId: 7n, email: 'admin@example.test', role: 'ADMIN', status: 'DISABLED' } },
  };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockImplementation(async ({ where }) => where.id === 'it'
      ? { id: 'it', status: 'ACTIVE', role: 'IT_SECURITY' }
      : { id: actor.accountId, status: 'ACTIVE', role }) },
    tenantApplication: { findUnique: vi.fn().mockResolvedValue(application) },
    organization: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    user: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    platformAuditEvent: { create: vi.fn(), findFirst: vi.fn().mockImplementation(async ({ where }) => where.action === 'tenant.technical-review.recorded'
      ? { id: 'technical-review', actorId: 'it', createdAt: new Date(), metadata: { fingerprint: technicalReviewFingerprint(application as Parameters<typeof technicalReviewFingerprint>[0]) } }
      : null) },
  };
  return { application, tx, db: { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient };
}
describe('guarded school activation foundation', () => {
  it('rejects a withdrawn review before changing access', async () => {
    const f = fixture();
    const original = f.tx.platformAuditEvent.findFirst.getMockImplementation()!;
    f.tx.platformAuditEvent.findFirst.mockImplementation(async (query) => query.where.action === 'tenant.technical-review.withdrawn' ? { id: 'withdrawal' } : original(query));
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
  it('rejects a superseded receipt even if the latest review is valid', async () => {
    const f = fixture();
    await expect(activateSchool(f.db, actor, 'application', { ...input, technicalReviewId: 'older-review' })).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAuditEvent.findFirst).toHaveBeenCalledWith({
      where: { entityType: 'TenantApplication', entityId: 'application', action: 'tenant.technical-review.recorded', actorRole: 'IT_SECURITY' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      select: { id: true, actorId: true, createdAt: true, metadata: true },
    });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it.each(['missing', 'expired', 'future', 'changed', 'same-actor', 'disabled-operator'])('blocks %s technical sign-off before enabling access', async (kind) => {
    const f = fixture();
    const review = { id: 'technical-review', actorId: kind === 'same-actor' ? actor.accountId : 'it',
      createdAt: new Date(Date.now() + (kind === 'expired' ? -86_400_000 : kind === 'future' ? 60_000 : 0)),
      metadata: { fingerprint: kind === 'changed' ? 'outdated-state' : technicalReviewFingerprint(f.application as Parameters<typeof technicalReviewFingerprint>[0]) } };
    f.tx.platformAuditEvent.findFirst.mockImplementation(async ({ where }) => where.action === 'tenant.technical-review.recorded' && kind !== 'missing' ? review : null);
    if (kind === 'disabled-operator') f.tx.platformAccount.findUnique.mockImplementation(async ({ where }) => where.id === 'it'
      ? { id: 'it', status: 'DISABLED', role: 'IT_SECURITY' }
      : { id: actor.accountId, status: 'ACTIVE', role: 'SUPER_ADMIN' });
    await expect(activateSchool(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('enables only the linked school/admin using independent IT sign-off and office approval', async () => {
    const f = fixture();
    expect(await activateSchool(f.db, actor, 'application', input)).toEqual({ organizationId: '7', status: 'ACTIVE', activated: true });
    expect(f.tx.organization.updateMany).toHaveBeenCalledWith({ where: { id: 7n, status: 'PENDING_ACTIVATION' }, data: { status: 'ACTIVE' } });
    expect(f.tx.user.updateMany).toHaveBeenCalledWith({ where: { id: 9n, orgId: 7n, email: 'admin@example.test', role: 'ADMIN', status: 'DISABLED' }, data: { status: 'ACTIVE' } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: 'tenant.school.activated', metadata: expect.objectContaining({ technicalReviewId: input.technicalReviewId, approvalReason: input.approvalReason }) }) });
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
  it.each(['tenantIsolation', 'accessControls', 'auditTrail', 'backupRecovery', 'supportEscalation'])('rejects office-submitted %s technical attestation', async (check) => {
    const f = fixture();
    await expect(activateSchool(f.db, actor, 'application', { ...input, checks: { [check]: true } })).rejects.toThrow();
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
