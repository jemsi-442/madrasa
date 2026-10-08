import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
import { technicalReviewFingerprint } from '../src/modules/platform/platform.technical-review';
const actor = { scope: 'platform' as const, accountId: 'operator', sessionId: 'session' };
function fixture(role = 'IT_SECURITY') {
  const application = { id: 'application', status: 'APPROVED', schoolName: 'School', requestedCode: 'school', adminEmail: 'private@example.test',
    requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(), provisionedAt: new Date(),
    organization: { id: 7n, status: 'PENDING_ACTIVATION' },
    adminInvitation: { id: 'invite', email: 'private@example.test', createdAt: new Date(), expiresAt: new Date(Date.now() + 100000), acceptedAt: new Date(),
      acceptedUser: { id: 9n, orgId: 7n, email: 'private@example.test', role: 'ADMIN', status: 'DISABLED' } },
  };
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'operator', role, status: 'ACTIVE' }) },
    tenantApplication: { findFirst: vi.fn().mockResolvedValue(application) },
    platformAuditEvent: { findFirst: vi.fn().mockResolvedValue(null) },
  };
  return { application, tx, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('onboarding progress snapshots', () => {
  it.each(['CURRENT', 'MISSING', 'EXPIRED', 'STATE_CHANGED', 'OPERATOR_UNAVAILABLE', 'WITHDRAWN'])('reports %s without exposing IT evidence to the office', async (status) => {
    for (const role of ['SUPER_ADMIN', 'IT_SECURITY']) {
      const f = fixture(role);
      const recordedAt = new Date(Date.now() - (status === 'EXPIRED' ? 86_400_000 : 1_000));
      f.tx.platformAuditEvent.findFirst.mockImplementation(async ({ where }) => where.action === 'tenant.technical-review.withdrawn' && status === 'WITHDRAWN' ? { id: 'withdrawal' } : where.action !== 'tenant.technical-review.recorded' || status === 'MISSING' ? null : {
        id: 'review', actorId: 'signer', createdAt: recordedAt,
        metadata: { fingerprint: status === 'STATE_CHANGED' ? 'old' : technicalReviewFingerprint(f.application as Parameters<typeof technicalReviewFingerprint>[0]), evidenceReference: 'private-evidence' },
      });
      f.tx.platformAccount.findUnique.mockImplementation(async ({ where }) => where.id === 'signer'
        ? { id: 'signer', role: 'IT_SECURITY', status: status === 'OPERATOR_UNAVAILABLE' ? 'DISABLED' : 'ACTIVE' }
        : { id: 'operator', role, status: 'ACTIVE' });
      const result = await f.service.onboardingProgress(actor, 'application');
      expect(result.nextResponsibility).toBe(status === 'CURRENT' ? 'OFFICE_APPROVAL' : 'IT_REVIEW');
      if (role === 'IT_SECURITY') expect(result.activationReview?.signOffStatus).toBe(status);
      else expect(result).not.toHaveProperty('activationReview');
      expect(JSON.stringify(result)).not.toContain('private-evidence');
      expect(JSON.stringify(result)).not.toContain('fingerprint');
      expect(JSON.stringify(result)).not.toContain('signer');
    }
  });
  it.each(['SUPER_ADMIN', 'IT_SECURITY'])('allows %s a safe approved-only snapshot', async (role) => {
    const f = fixture(role);
    const result = await f.service.onboardingProgress(actor, 'application');
    expect(result.stage).toBe('ACTIVATION_REVIEW_PENDING');
    expect(result.deliveryConfigured).toBe(false);
    expect(JSON.stringify(result)).not.toContain('private@example.test');
    expect(result).not.toHaveProperty('acceptedUser');
    if (role === 'IT_SECURITY') {
      expect(result.activationReview).toMatchObject({ prerequisitesPassed: true, activationEnabled: false });
      expect(result.activationReview?.checks.every((check) => check.passed)).toBe(true);
      expect(result.activationReview?.manualReviews).toHaveLength(5);
    } else {
      expect(result).not.toHaveProperty('activationReview');
    }
    expect(f.tx.tenantApplication.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'application', status: 'APPROVED' } }));
  });
  it('distinguishes provisioning and invitation preparation', async () => {
    const f = fixture();
    f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, organization: null, adminInvitation: null });
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('PROVISIONING_PENDING');
    f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, adminInvitation: null });
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('INVITATION_PENDING');
  });
  it('distinguishes waiting acceptance and expiry, never claiming email delivery', async () => {
    const f = fixture();
    const invitation = { ...f.application.adminInvitation, acceptedAt: null, acceptedUser: null };
    f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, adminInvitation: invitation });
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('ACCEPTANCE_PENDING');
    f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, adminInvitation: { ...invitation, expiresAt: new Date(0) } });
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('INVITATION_EXPIRED');
  });
  it('requires matching active admin and audit before showing active', async () => {
    const f = fixture(); f.application.organization.status = 'ACTIVE'; f.application.adminInvitation.acceptedUser.status = 'ACTIVE';
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('REVIEW_REQUIRED');
    f.tx.platformAuditEvent.findFirst.mockResolvedValue({ createdAt: new Date() });
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('ACTIVE');
    f.application.adminInvitation.acceptedUser.status = 'DISABLED';
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('REVIEW_REQUIRED');
  });
  it('flags suspended school and mismatched acceptance', async () => {
    const f = fixture(); f.application.organization.status = 'SUSPENDED';
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('REVIEW_REQUIRED');
    f.application.organization.status = 'PENDING_ACTIVATION'; f.application.adminInvitation.acceptedUser.orgId = 99n;
    expect((await f.service.onboardingProgress(actor, 'application')).stage).toBe('REVIEW_REQUIRED');
  });
  it('does not reveal unapproved or missing records', async () => {
    const f = fixture(); f.tx.tenantApplication.findFirst.mockResolvedValue(null);
    await expect(f.service.onboardingProgress(actor, 'application')).rejects.toMatchObject({ statusCode: 404 });
  });
  it('does not permit the original requester to pass readiness checks', async () => {
    const f = fixture(); f.application.requestedById = actor.accountId;
    const result = await f.service.onboardingProgress(actor, 'application');
    expect(result.stage).toBe('ACTIVATION_REVIEW_PENDING');
    expect(result.activationReview?.prerequisitesPassed).toBe(false);
    expect(result.activationReview?.checks).toContainEqual({ label: 'You are not the original requester', passed: false });
  });
  it('fails readiness when provisioning evidence or consistent access is missing', async () => {
    const f = fixture();
    f.tx.tenantApplication.findFirst.mockResolvedValue({ ...f.application, provisionedAt: null });
    expect((await f.service.onboardingProgress(actor, 'application')).activationReview?.prerequisitesPassed).toBe(false);
    f.tx.tenantApplication.findFirst.mockResolvedValue(f.application);
    f.tx.platformAuditEvent.findFirst.mockResolvedValue({ createdAt: new Date() });
    const result = await f.service.onboardingProgress(actor, 'application');
    expect(result.activationReview?.prerequisitesPassed).toBe(false);
    expect(result.activationReview?.checks).toContainEqual({ label: 'No previous activation recorded', passed: false });
  });
  it.each(['ADMIN', 'PARENT'])('denies school role %s', async (role) => {
    const f = fixture(role);
    await expect(f.service.onboardingProgress(actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findFirst).not.toHaveBeenCalled();
  });
});
