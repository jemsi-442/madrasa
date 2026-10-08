import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { recordTechnicalReview, withdrawTechnicalReview } from '../src/modules/platform/platform.technical-review';

const actor = { scope: 'platform' as const, accountId: 'it', sessionId: 'session' };
const input = { invitationId: 'invite', evidenceReference: 'approved-private-evidence', checks: {
  tenantIsolation: true, accessControls: true, auditTrail: true, backupRecovery: true, supportEscalation: true,
} };
function fixture(role = 'IT_SECURITY') {
  const application = { status: 'APPROVED', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(),
    provisionedAt: new Date(), adminEmail: 'admin@example.test', organization: { id: 7n, status: 'PENDING_ACTIVATION' },
    adminInvitation: { id: 'invite', email: 'admin@example.test', acceptedAt: new Date(),
      acceptedUser: { id: 9n, orgId: 7n, email: 'admin@example.test', role: 'ADMIN', status: 'DISABLED' } },
  };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'it', status: 'ACTIVE', role }) },
    tenantApplication: { findUnique: vi.fn().mockResolvedValue(application) },
    platformAuditEvent: { findFirst: vi.fn().mockResolvedValue(null), create: vi.fn().mockResolvedValue({ id: 'receipt', createdAt: new Date() }) },
    organization: { updateMany: vi.fn() }, user: { updateMany: vi.fn() },
  };
  const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
  return { tx, db, application };
}
describe('independent IT sign-off', () => {
  it('withdraws only the selected latest review and safely replays without access writes', async () => {
    const f = fixture();
    let withdrawn = false;
    f.tx.platformAuditEvent.findFirst.mockImplementation(async ({ where }) => where.action === 'tenant.technical-review.recorded'
      ? { id: 'review' } : where.action === 'tenant.technical-review.withdrawn' && withdrawn ? { id: 'withdrawal' } : null);
    const data = { technicalReviewId: 'review', reason: 'New technical issue requires investigation' };
    expect(await withdrawTechnicalReview(f.db, actor, 'application', data)).toEqual({ withdrawn: true });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ entityType: 'TechnicalReview', entityId: 'review', action: 'tenant.technical-review.withdrawn' }) });
    withdrawn = true;
    expect(await withdrawTechnicalReview(f.db, actor, 'application', data)).toEqual({ withdrawn: false });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledTimes(1);
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'PARENT'])('denies withdrawal to %s', async (role) => {
    const f = fixture(role);
    await expect(withdrawTechnicalReview(f.db, actor, 'application', { technicalReviewId: 'review', reason: 'Investigation required' })).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it.each(['stale', 'active', 'activated', 'audit-failure'])('fails closed for withdrawal: %s', async (kind) => {
    const f = fixture();
    if (kind === 'active') f.application.organization.status = 'ACTIVE';
    f.tx.platformAuditEvent.findFirst.mockImplementation(async ({ where }) => where.action === 'tenant.school.activated' && kind === 'activated'
      ? { id: 'activation' } : where.action === 'tenant.technical-review.recorded' ? { id: kind === 'stale' ? 'newer' : 'review' } : null);
    if (kind === 'audit-failure') f.tx.platformAuditEvent.create.mockRejectedValue(new Error('audit failed'));
    await expect(withdrawTechnicalReview(f.db, actor, 'application', { technicalReviewId: 'review', reason: 'Investigation required' })).rejects.toThrow();
    if (kind !== 'audit-failure') expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
  });
  it('records evidence without activating a school or revealing it in the receipt', async () => {
    const f = fixture();
    const result = await recordTechnicalReview(f.db, actor, 'application', input);
    expect(result.reviewId).toBe('receipt');
    expect(JSON.stringify(result)).not.toContain(input.evidenceReference);
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({
      action: 'tenant.technical-review.recorded', actorRole: 'IT_SECURITY', entityId: 'application',
      metadata: expect.objectContaining({ fingerprint: expect.stringMatching(/^[a-f0-9]{64}$/), operatorAttestations: input.checks }),
    }) }));
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
    expect(f.tx.user.updateMany).not.toHaveBeenCalled();
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'PARENT'])('denies technical sign-off to %s', async (role) => {
    const f = fixture(role);
    await expect(recordTechnicalReview(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findUnique).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it.each(Object.keys(input.checks))('requires explicit %s evidence attestation', async (check) => {
    const f = fixture();
    await expect(recordTechnicalReview(f.db, actor, 'application', { ...input, checks: { ...input.checks, [check]: false } })).rejects.toThrow();
    expect(f.tx.platformAccount.findUnique).not.toHaveBeenCalled();
  });
  it.each(['invitation', 'user', 'review', 'previous-activation', 'disabled'])('rejects inconsistent state: %s', async (kind) => {
    const f = fixture();
    if (kind === 'invitation') f.application.adminInvitation.id = 'rotated';
    if (kind === 'user') f.application.adminInvitation.acceptedUser.orgId = 99n;
    if (kind === 'review') f.application.reviewedById = 'requester';
    if (kind === 'previous-activation') f.tx.platformAuditEvent.findFirst.mockResolvedValue({ id: 'old' });
    if (kind === 'disabled') f.tx.platformAccount.findUnique.mockResolvedValue({ id: 'it', status: 'DISABLED', role: 'IT_SECURITY' });
    await expect(recordTechnicalReview(f.db, actor, 'application', input)).rejects.toMatchObject({ statusCode: kind === 'disabled' ? 403 : 409 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('fails closed when audit persistence fails', async () => {
    const f = fixture(); f.tx.platformAuditEvent.create.mockRejectedValue(new Error('audit unavailable'));
    await expect(recordTechnicalReview(f.db, actor, 'application', input)).rejects.toThrow('audit unavailable');
    expect(f.tx.organization.updateMany).not.toHaveBeenCalled();
  });
});
