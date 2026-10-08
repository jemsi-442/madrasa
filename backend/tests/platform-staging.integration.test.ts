import { randomBytes } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, describe, expect, it } from "vitest";
import { bootstrapPlatformReviewer } from "../src/modules/platform/platform.bootstrap";
import { loginPlatform } from "../src/modules/platform/platform.login";
import { encryptMfaSecret, totpCode } from "../src/modules/platform/platform.mfa";
import { verifyPlatformAccess } from "../src/modules/platform/platform.authentication";
import { createPlatformLoginLimiter } from "../src/modules/platform/platform.login-limit";
import { PlatformGovernanceService } from "../src/modules/platform/platform.service";
import { createPlatformHealthReader } from "../src/modules/platform/platform.health";
import { issueSchoolAdminInvitation, acceptSchoolAdminInvitation } from "../src/modules/platform/platform.school-invitation";
import bcrypt from "bcryptjs";
import { activateSchool } from "../src/modules/platform/platform.activation";
import { recordTechnicalReview, withdrawTechnicalReview } from "../src/modules/platform/platform.technical-review";
import express from "express";
import request from "supertest";
import { createSchoolInvitationRouter } from "../src/modules/platform/platform.invitation-routes";
import { createSchoolInvitationLimiter } from "../src/modules/platform/platform.invitation-limit";
import { createPlatformRouter } from "../src/modules/platform/platform.routes";
import { errorHandler } from "../src/shared/middleware/error-handler";
import { unifiedLogin } from "../src/modules/auth/unified-login";

const enabled = process.env.PLATFORM_STAGING_RUN === "isolated";
if (enabled && !/^mysql:\/\/root@127\.0\.0\.1:\d+\/afaq_platform_staging_[a-f0-9]+$/.test(process.env.DATABASE_URL ?? "")) {
  throw new Error("Refusing staging tests outside the isolated runner database");
}

describe.skipIf(!enabled)("real isolated platform staging", () => {
  const db = new PrismaClient({ log: [] });
  const key = randomBytes(32).toString("hex");
  const signing = randomBytes(32).toString("hex");
  const password = randomBytes(20).toString("hex");
  const firstSecret = randomBytes(20);
  const secondSecret = randomBytes(20);
  const code = (secret: Buffer) => totpCode(secret, BigInt(Math.floor(Date.now() / 30_000)));
  const options = { encryptionKey: key, consumeLimit: createPlatformLoginLimiter(process.env.REDIS_URL!, signing) };
  const service = new PlatformGovernanceService(db);
  afterAll(async () => { await db.$disconnect(); });

  it("persists password-only sessions through the unified HTTP boundary", async () => {
    const account = await db.platformAccount.create({ data: {
      email: 'password-it@example.test', fullName: 'Password IT', role: 'IT_SECURITY', status: 'ACTIVE',
      passwordHash: await bcrypt.hash(password, 4),
    } });
    const app = express(); app.use(express.json());
    app.post('/login', unifiedLogin(db, signing, createPlatformLoginLimiter(process.env.REDIS_URL!, signing)), (_req, res) => { res.sendStatus(401); });
    app.use(errorHandler);
    try {
      const response = await request(app).post('/login').send({ login: account.email, password }).expect(200);
      const actor = await verifyPlatformAccess(db, response.body.data.accessToken, signing);
      const session = await db.platformSession.findUniqueOrThrow({ where: { id: actor.sessionId } });
      expect(session.mfaVerifiedAt).toBeNull();
      expect((await service.listOwnSessions(actor)).map(row => row.id)).toContain(actor.sessionId);
      await expect(service.overview(actor)).rejects.toMatchObject({ statusCode: 403 });
      await service.logout(actor);
      await expect(verifyPlatformAccess(db, response.body.data.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
    } finally {
      await db.platformAuditEvent.deleteMany({ where: { actorId: account.id } });
      await db.platformSession.deleteMany({ where: { accountId: account.id } });
      await db.platformAccount.delete({ where: { id: account.id } });
    }
  });

  it("bootstraps only two reviewers under concurrent requests", async () => {
    const attempt = (email: string, secret: Buffer) => bootstrapPlatformReviewer(db, { email, fullName: "Staging Reviewer", password, code: code(secret) }, secret, key);
    await attempt("first@example.test", firstSecret);
    const results = await Promise.allSettled([
      attempt("second@example.test", secondSecret), attempt("third@example.test", secondSecret),
    ]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(await db.platformAccount.count()).toBe(2);
    expect(await db.platformAuditEvent.count({ where: { action: "platform.account.bootstrapped" } })).toBe(2);
  }, 20_000);

  it("logs in, blocks replay, independently approves, audits and revokes sessions", async () => {
    // Enrollment consumed the current code; simulate arrival of a new time step in this disposable DB only.
    await db.platformAccount.updateMany({ data: { lastMfaStep: -1 } });
    const first = await loginPlatform(db, signing, options, { email: "first@example.test", password, code: code(firstSecret) }, "staging-client");
    const requester = await verifyPlatformAccess(db, first.accessToken, signing);
    await expect(loginPlatform(db, signing, options, { email: "first@example.test", password, code: code(firstSecret) }, "staging-client"))
      .rejects.toMatchObject({ statusCode: 401 });
    const secondAccount = await db.platformAccount.findFirstOrThrow({ where: { email: { not: "first@example.test" } } });
    const second = await loginPlatform(db, signing, options, { email: secondAccount.email, password, code: code(secondSecret) }, "staging-client");
    const reviewer = await verifyPlatformAccess(db, second.accessToken, signing);
    const application = await service.createApplication(requester, { schoolName: "Staging School", requestedCode: "staging-school", adminEmail: "school@example.test" });
    await expect(service.reviewApplication(requester, application.id, { decision: "APPROVED", reason: "Verified ownership evidence" }))
      .rejects.toMatchObject({ statusCode: 403 });
    await service.reviewApplication(reviewer, application.id, { decision: "APPROVED", reason: "Verified ownership evidence" });
    expect(await db.organization.count()).toBe(0);
    expect(await db.platformAuditEvent.count({ where: { action: "tenant.application.approved" } })).toBe(1);
    await service.logout(requester);
    await expect(verifyPlatformAccess(db, first.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
  }, 20_000);

  it("isolates owned sessions and atomically audits selected-session revocation", async () => {
    const loginFirst = async () => {
      // Advance the replay watermark only in the disposable staging database.
      await db.platformAccount.updateMany({ where: { email: "first@example.test" }, data: { lastMfaStep: -1 } });
      return loginPlatform(db, signing, options, { email: "first@example.test", password, code: code(firstSecret) }, "staging-sessions");
    };
    const first = await loginFirst();
    const actor = await verifyPlatformAccess(db, first.accessToken, signing);
    const other = await loginFirst();
    const otherActor = await verifyPlatformAccess(db, other.accessToken, signing);
    const foreign = await db.platformSession.findFirstOrThrow({ where: { accountId: { not: actor.accountId }, revokedAt: null } });
    const listed = await service.listOwnSessions(actor);
    expect(listed.map((session) => session.id).sort()).toEqual([actor.sessionId, otherActor.sessionId].sort());
    expect(listed.filter((session) => session.current).map((session) => session.id)).toEqual([actor.sessionId]);
    await expect(service.revokeOwnSession(actor, foreign.id)).rejects.toMatchObject({ statusCode: 404 });
    expect((await db.platformSession.findUniqueOrThrow({ where: { id: foreign.id } })).revokedAt).toBeNull();

    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_session_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected staging audit failure'");
    try {
      await expect(service.revokeOwnSession(actor, otherActor.sessionId)).rejects.toThrow();
      expect((await db.platformSession.findUniqueOrThrow({ where: { id: otherActor.sessionId } })).revokedAt).toBeNull();
      await expect(verifyPlatformAccess(db, other.accessToken, signing)).resolves.toMatchObject({ accountId: actor.accountId });
    } finally { await db.$executeRawUnsafe("DROP TRIGGER staging_fail_session_audit"); }

    expect(await service.revokeOwnSession(actor, otherActor.sessionId)).toEqual({ revoked: 1, current: false });
    await expect(verifyPlatformAccess(db, other.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
    expect(await service.revokeOwnSession(actor, otherActor.sessionId)).toEqual({ revoked: 0, current: false });
    expect(await db.platformAuditEvent.count({ where: { action: "platform.session.revoked", entityId: otherActor.sessionId } })).toBe(1);
    expect(await service.revokeOwnSession(actor, actor.sessionId)).toEqual({ revoked: 1, current: true });
    await expect(verifyPlatformAccess(db, first.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
  }, 20_000);

  it("projects only public directory fields from real platform accounts", async () => {
    const account = await db.platformAccount.findFirstOrThrow();
    const records = await service.listAccounts({ scope: "platform", accountId: account.id, sessionId: "internal-directory-test" });
    expect(records).toHaveLength(2);
    for (const record of records) {
      expect(Object.keys(record).sort()).toEqual(['id', 'fullName', 'email', 'role', 'status', 'createdAt'].sort());
      expect(record.role).toBe('SUPER_ADMIN');
    }
    expect(await service.listAccounts({ scope: "platform", accountId: account.id, sessionId: "internal-directory-test" }, { page: 2, pageSize: 2 })).toEqual([]);
  });

  it("rolls back intake if the audit insert fails", async () => {
    const account = await db.platformAccount.findFirstOrThrow();
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected staging audit failure'");
    try {
      await expect(service.createApplication({ scope: "platform", accountId: account.id, sessionId: "internal-rollback-test" }, {
        schoolName: "Rollback School", requestedCode: "rollback-school", adminEmail: "rollback@example.test",
      })).rejects.toThrow();
      expect(await db.tenantApplication.count({ where: { requestedCode: "rollback-school" } })).toBe(0);
    } finally { await db.$executeRawUnsafe("DROP TRIGGER staging_fail_audit"); }
  });

  it("enforces the actual Redis account limit", async () => {
    const limit = createPlatformLoginLimiter(process.env.REDIS_URL!, randomBytes(32).toString("hex"));
    for (let i = 0; i < 10; i++) await limit("limit@example.test", "limit-client");
    await expect(limit("limit@example.test", "limit-client")).rejects.toMatchObject({ statusCode: 429 });
  });

  it("checks real MariaDB and Redis without exposing connection configuration", async () => {
    const office = await db.platformAccount.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } });
    const reader = createPlatformHealthReader(db, process.env.REDIS_URL!);
    await expect(service.health({ scope: 'platform', accountId: office.id, sessionId: 'office-health' }, reader)).rejects.toMatchObject({ statusCode: 403 });
    const account = await db.platformAccount.create({ data: {
      email: 'health-it@example.test', fullName: 'Health operator', passwordHash: 'test-only', role: 'IT_SECURITY', status: 'ACTIVE',
    } });
    try {
      const result = await service.health({ scope: "platform", accountId: account.id, sessionId: "internal-health-test" }, reader);
      expect(result.status).toBe("healthy");
      expect(result.checks).toHaveLength(2);
      expect(result.checks.every((check) => check.status === "available")).toBe(true);
      expect(JSON.stringify(result)).not.toContain("127.0.0.1");
    } finally { await db.platformAccount.delete({ where: { id: account.id } }); }
  });

  it("allows only one concurrent decision and one decision audit", async () => {
    const accounts = await db.platformAccount.findMany({ orderBy: { id: "asc" } });
    const requester = { scope: "platform" as const, accountId: accounts[0]!.id, sessionId: "internal-concurrency-test" };
    const reviewer = { ...requester, accountId: accounts[1]!.id };
    const application = await service.createApplication(requester, {
      schoolName: "Concurrent School", requestedCode: "concurrent-school", adminEmail: "concurrent@example.test",
    });
    const results = await Promise.allSettled([
      service.reviewApplication(reviewer, application.id, { decision: "APPROVED", reason: "Ownership evidence verified" }),
      service.reviewApplication(reviewer, application.id, { decision: "REJECTED", reason: "Ownership evidence insufficient" }),
    ]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(await db.platformAuditEvent.count({ where: { entityId: application.id, action: { in: ["tenant.application.approved", "tenant.application.rejected"] } } })).toBe(1);
  });

  it("disables IT atomically, blocks its token, and preserves Super Admin access", async () => {
    const admin = await db.platformAccount.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } });
    const actor = { scope: 'platform' as const, accountId: admin.id, sessionId: 'internal-disable-test' };
    const id = randomBytes(15).toString('hex');
    const mfa = randomBytes(20);
    await db.platformAccount.create({ data: {
      id, email: 'security@example.test', fullName: 'Staging IT', passwordHash: admin.passwordHash,
      role: 'IT_SECURITY', status: 'ACTIVE', mfaSecretEncrypted: encryptMfaSecret(mfa, id, key),
    } });
    const login = await loginPlatform(db, signing, options, { email: 'security@example.test', password, code: code(mfa) }, 'staging-disable');
    const it = await verifyPlatformAccess(db, login.accessToken, signing);
    const input = { reason: 'Staging operator access removed' };
    await expect(service.disableItAccount(it, admin.id, input)).rejects.toMatchObject({ statusCode: 403 });
    await expect(service.disableItAccount(actor, admin.id, input)).rejects.toMatchObject({ statusCode: 403 });
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_disable_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected staging audit failure'");
    try {
      await expect(service.disableItAccount(actor, id, input)).rejects.toThrow();
      expect((await db.platformAccount.findUniqueOrThrow({ where: { id } })).status).toBe('ACTIVE');
      await expect(verifyPlatformAccess(db, login.accessToken, signing)).resolves.toMatchObject({ accountId: id });
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_disable_audit'); }
    const results = await Promise.allSettled([service.disableItAccount(actor, id, input), service.disableItAccount(actor, id, input)]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect((await db.platformAccount.findUniqueOrThrow({ where: { id } })).status).toBe('DISABLED');
    expect(await db.platformSession.count({ where: { accountId: id, revokedAt: null } })).toBe(0);
    expect(await db.platformAuditEvent.count({ where: { entityId: id, action: 'platform.account.disabled' } })).toBe(1);
    await expect(verifyPlatformAccess(db, login.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
    await expect(loginPlatform(db, signing, options, { email: 'security@example.test', password, code: code(mfa) }, 'staging-disable')).rejects.toMatchObject({ statusCode: 401 });
    expect((await db.platformAccount.findUniqueOrThrow({ where: { id: admin.id } })).status).toBe('ACTIVE');
    const reviewer = await db.platformAccount.findFirstOrThrow({ where: { role: 'SUPER_ADMIN', id: { not: admin.id } } });
    const reviewActor = { ...actor, accountId: reviewer.id };
    const history = await service.accountAccessHistory(reviewActor, id, { pageSize: 1 });
    const restoreInput = { ...input, suspensionEventId: history[0]!.id };
    await expect(service.restoreItAccount(reviewActor, id, { ...restoreInput, suspensionEventId: 'stale-event' })).rejects.toMatchObject({ statusCode: 409 });
    await expect(service.restoreItAccount(actor, id, restoreInput)).rejects.toMatchObject({ statusCode: 403 });
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_restore_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected staging audit failure'");
    try {
      await expect(service.restoreItAccount(reviewActor, id, restoreInput)).rejects.toThrow();
      expect((await db.platformAccount.findUniqueOrThrow({ where: { id } })).status).toBe('DISABLED');
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_restore_audit'); }
    expect((await service.restoreItAccount(reviewActor, id, restoreInput)).status).toBe('ACTIVE');
    await expect(service.restoreItAccount(reviewActor, id, restoreInput)).rejects.toMatchObject({ statusCode: 409 });
    await expect(verifyPlatformAccess(db, login.accessToken, signing)).rejects.toMatchObject({ statusCode: 401 });
    expect(await db.platformAuditEvent.count({ where: { entityId: id, action: 'platform.account.restored' } })).toBe(1);
    // Simulate the next OTP step in this disposable database, never reset it in production.
    await db.platformAccount.update({ where: { id }, data: { lastMfaStep: -1 } });
    const fresh = await loginPlatform(db, signing, options, { email: 'security@example.test', password, code: code(mfa) }, 'staging-restore');
    await expect(verifyPlatformAccess(db, fresh.accessToken, signing)).resolves.toMatchObject({ accountId: id });
  }, 20_000);

  it('provisions an inactive school once and rolls back all writes if audit fails', async () => {
    const admins = await db.platformAccount.findMany({ where: { role: 'SUPER_ADMIN' }, take: 2 });
    const itAccount = await db.platformAccount.create({ data: {
      email: 'provisioner@example.test', fullName: 'Provisioning Operator', role: 'IT_SECURITY',
      status: 'ACTIVE', passwordHash: 'not-a-login-credential',
    } });
    const context = (accountId: string) => ({ scope: 'platform' as const, accountId, sessionId: 'isolated-service-test' });
    const application = await service.createApplication(context(admins[0]!.id), {
      schoolName: 'Pending School', requestedCode: 'pending-school', adminEmail: 'pending@example.test',
    });
    await service.reviewApplication(context(admins[1]!.id), application.id, { decision: 'APPROVED', reason: 'Independent evidence checked' });
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_provision_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected audit failure'");
    try {
      await expect(service.provisionPendingSchool(context(itAccount.id), application.id)).rejects.toThrow();
      expect(await db.organization.findUnique({ where: { code: 'pending-school' } })).toBeNull();
      expect((await db.tenantApplication.findUniqueOrThrow({ where: { id: application.id } })).organizationId).toBeNull();
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_provision_audit'); }
    const results = await Promise.allSettled([
      service.provisionPendingSchool(context(itAccount.id), application.id),
      service.provisionPendingSchool(context(itAccount.id), application.id),
    ]);
    expect(results.some((result) => result.status === 'fulfilled')).toBe(true);
    const replay = await service.provisionPendingSchool(context(itAccount.id), application.id);
    expect(replay).toMatchObject({ status: 'PENDING_ACTIVATION', created: false });
    expect(await db.organization.count({ where: { code: 'pending-school' } })).toBe(1);
    expect(await db.user.count({ where: { orgId: BigInt(replay.organizationId) } })).toBe(0);
    expect(await db.platformAuditEvent.count({ where: { entityId: application.id, action: 'tenant.school.provisioned' } })).toBe(1);
  }, 20_000);

  it('issues hashed, expiring invitations and accepts once without activating school or admin', async () => {
    const application = await db.tenantApplication.findUniqueOrThrow({ where: { requestedCode: 'pending-school' } });
    const operator = await db.platformAccount.findUniqueOrThrow({ where: { email: 'provisioner@example.test' } });
    const actor = { scope: 'platform' as const, accountId: operator.id, sessionId: 'isolated-invitation-test' };
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_invitation_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected invitation audit failure'");
    try {
      await expect(issueSchoolAdminInvitation(db, actor, application.id)).rejects.toThrow();
      expect(await db.schoolAdminInvitation.count({ where: { applicationId: application.id } })).toBe(0);
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_invitation_audit'); }
    const first = await issueSchoolAdminInvitation(db, actor, application.id);
    const stored = await db.schoolAdminInvitation.findUniqueOrThrow({ where: { applicationId: application.id } });
    expect(stored.tokenHash).toMatch(/^[a-f0-9]{64}$/);
    expect(JSON.stringify(stored)).not.toContain(first.token);
    expect(first.email).toBe(application.adminEmail);
    expect(first.expiresAt.getTime() - Date.now()).toBeGreaterThan(23 * 60 * 60 * 1000);
    const input = { token: first.token, fullName: 'First School Admin', password: 'staging-admin-password-only' };
    await db.schoolAdminInvitation.update({ where: { id: stored.id }, data: { expiresAt: new Date(0) } });
    await expect(acceptSchoolAdminInvitation(db, input)).rejects.toMatchObject({ statusCode: 410 });
    const fresh = await issueSchoolAdminInvitation(db, actor, application.id);
    await expect(acceptSchoolAdminInvitation(db, input)).rejects.toMatchObject({ statusCode: 410 });
    input.token = fresh.token;
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_acceptance BEFORE UPDATE ON school_admin_invitations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected acceptance failure'");
    try {
      await expect(acceptSchoolAdminInvitation(db, input)).rejects.toThrow();
      expect(await db.user.count({ where: { orgId: application.organizationId! } })).toBe(0);
      expect((await db.schoolAdminInvitation.findUniqueOrThrow({ where: { id: stored.id } })).acceptedAt).toBeNull();
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_acceptance'); }
    const results = await Promise.allSettled([acceptSchoolAdminInvitation(db, input), acceptSchoolAdminInvitation(db, input)]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    await expect(acceptSchoolAdminInvitation(db, input)).rejects.toMatchObject({ statusCode: 410 });
    await expect(issueSchoolAdminInvitation(db, actor, application.id)).rejects.toMatchObject({ statusCode: 409 });
    const users = await db.user.findMany({ where: { orgId: application.organizationId! } });
    expect(users).toHaveLength(1);
    expect(users[0]).toMatchObject({ role: 'ADMIN', status: 'DISABLED', email: application.adminEmail });
    expect(await bcrypt.compare(input.password, users[0]!.passwordHash)).toBe(true);
    expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe('PENDING_ACTIVATION');
    const receipt = await db.schoolAdminInvitation.findUniqueOrThrow({ where: { id: stored.id } });
    expect(receipt.acceptedAt).not.toBeNull();
    expect(receipt.acceptedUserId).toBe(users[0]!.id);
    expect(await db.refreshToken.count({ where: { userId: users[0]!.id } })).toBe(0);
  }, 20_000);

  it('activates school and accepted admin atomically, with safe concurrency and replay', async () => {
    const application = await db.tenantApplication.findUniqueOrThrow({ where: { requestedCode: 'pending-school' }, include: { adminInvitation: true } });
    const actor = { scope: 'platform' as const, accountId: application.reviewedById!, sessionId: 'isolated-activation-test' };
    const technicalInput = { invitationId: application.adminInvitation!.id, evidenceReference: 'isolated-staging-attestation-not-production-evidence', checks: {
      tenantIsolation: true, accessControls: true, auditTrail: true, backupRecovery: true, supportEscalation: true,
    } };
    await expect(recordTechnicalReview(db, actor, application.id, technicalInput)).rejects.toMatchObject({ statusCode: 403 });
    const operator = await db.platformAccount.findFirstOrThrow({ where: { role: 'IT_SECURITY', status: 'ACTIVE' } });
    const itActor = { ...actor, accountId: operator.id };
    expect((await service.onboardingProgress(actor, application.id)).nextResponsibility).toBe('IT_REVIEW');
    const review = await recordTechnicalReview(db, itActor, application.id, technicalInput);
    const officeProgress = await service.onboardingProgress(actor, application.id);
    expect(officeProgress.nextResponsibility).toBe('OFFICE_APPROVAL');
    expect(officeProgress).not.toHaveProperty('activationReview');
    expect((await service.onboardingProgress(itActor, application.id)).activationReview?.signOffStatus).toBe('CURRENT');
    const replacement = await recordTechnicalReview(db, itActor, application.id, technicalInput);
    const latest = await db.platformAuditEvent.findFirstOrThrow({
      where: { entityId: application.id, entityType: 'TenantApplication', action: 'tenant.technical-review.recorded', actorRole: 'IT_SECURITY' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    const supersededId = latest.id === replacement.reviewId ? review.reviewId : replacement.reviewId;
    const input = { invitationId: application.adminInvitation!.id, technicalReviewId: latest.id, approvalReason: 'Office onboarding requirements approved' };
    await expect(activateSchool(db, actor, application.id, { ...input, technicalReviewId: supersededId })).rejects.toMatchObject({ statusCode: 409 });
    expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe('PENDING_ACTIVATION');
    expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('DISABLED');
    const withdrawalInput = { technicalReviewId: input.technicalReviewId, reason: 'Staging technical issue requires a fresh review' };
    await expect(withdrawTechnicalReview(db, actor, application.id, withdrawalInput)).rejects.toMatchObject({ statusCode: 403 });
    expect(await withdrawTechnicalReview(db, itActor, application.id, withdrawalInput)).toEqual({ withdrawn: true });
    expect(await withdrawTechnicalReview(db, itActor, application.id, withdrawalInput)).toEqual({ withdrawn: false });
    const scopedWithdrawals = await service.listAuditEvents(itActor, { applicationId: application.id, action: 'tenant.technical-review.withdrawn' });
    expect(scopedWithdrawals).toHaveLength(1);
    const reviewHistory = await service.listAuditEvents(itActor, { technicalReviewId: withdrawalInput.technicalReviewId });
    expect(reviewHistory.map((event) => event.action).sort()).toEqual(['tenant.technical-review.recorded', 'tenant.technical-review.withdrawn']);
    expect(await service.listAuditEvents(itActor, { technicalReviewId: withdrawalInput.technicalReviewId, applicationId: 'unrelated-application' })).toEqual([]);
    expect(await service.listAuditEvents(itActor, { technicalReviewId: 'missing-review' })).toEqual([]);
    await expect(service.listAuditEvents(actor, { technicalReviewId: withdrawalInput.technicalReviewId })).rejects.toMatchObject({ statusCode: 403 });
    expect(scopedWithdrawals[0]).toMatchObject({ entityType: 'TechnicalReview', entityId: withdrawalInput.technicalReviewId, metadata: {} });
    expect(JSON.stringify(scopedWithdrawals)).not.toContain(withdrawalInput.reason);
    expect(await service.listAuditEvents(itActor, { applicationId: 'unrelated-application', action: 'tenant.technical-review.withdrawn' })).toEqual([]);
    expect((await service.listAuditEvents(actor, { applicationId: application.id })).some((event) => event.action === 'tenant.technical-review.withdrawn')).toBe(false);
    expect((await service.onboardingProgress(actor, application.id)).nextResponsibility).toBe('IT_REVIEW');
    expect((await service.onboardingProgress(itActor, application.id)).activationReview?.signOffStatus).toBe('WITHDRAWN');
    await expect(activateSchool(db, actor, application.id, input)).rejects.toMatchObject({ statusCode: 409 });
    input.technicalReviewId = (await recordTechnicalReview(db, itActor, application.id, technicalInput)).reviewId;
    expect((await service.onboardingProgress(actor, application.id)).nextResponsibility).toBe('OFFICE_APPROVAL');
    await expect(activateSchool(db, itActor, application.id, input)).rejects.toMatchObject({ statusCode: 403 });
    await expect(activateSchool(db, actor, application.id, { ...input, technicalReviewId: 'missing-review' })).rejects.toMatchObject({ statusCode: 409 });
    const officeEvents = await service.listAuditEvents(actor, { applicationId: application.id });
    expect(officeEvents.some((event) => event.action === 'tenant.technical-review.recorded')).toBe(false);
    await db.tenantApplication.update({ where: { id: application.id }, data: { provisionedAt: null } });
    try {
      await expect(activateSchool(db, actor, application.id, input)).rejects.toMatchObject({ statusCode: 409 });
      expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe('PENDING_ACTIVATION');
      expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('DISABLED');
      expect(await db.platformAuditEvent.count({ where: { entityId: application.id, action: 'tenant.school.activated' } })).toBe(0);
    } finally {
      await db.tenantApplication.update({ where: { id: application.id }, data: { provisionedAt: application.provisionedAt } });
    }
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_activation_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected activation audit failure'");
    try {
      await expect(activateSchool(db, actor, application.id, input)).rejects.toThrow();
      expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe('PENDING_ACTIVATION');
      expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('DISABLED');
    } finally { await db.$executeRawUnsafe('DROP TRIGGER staging_fail_activation_audit'); }
    const results = await Promise.allSettled([activateSchool(db, actor, application.id, input), activateSchool(db, actor, application.id, input)]);
    expect(results.some((result) => result.status === 'fulfilled')).toBe(true);
    expect((await activateSchool(db, actor, application.id, input)).activated).toBe(false);
    expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe('ACTIVE');
    expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('ACTIVE');
    expect(await db.platformAuditEvent.count({ where: { entityId: application.id, action: 'tenant.school.activated' } })).toBe(1);
    await db.user.update({ where: { id: application.adminInvitation!.acceptedUserId! }, data: { status: 'DISABLED' } });
    await expect(activateSchool(db, actor, application.id, input)).rejects.toMatchObject({ statusCode: 409 });
    expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('DISABLED');
    // Simulate inconsistent state after a recorded activation, never repair it via onboarding.
    try {
      for (const status of ['PENDING_ACTIVATION', 'SUSPENDED', 'TRIAL'] as const) {
        await db.organization.update({ where: { id: application.organizationId! }, data: { status } });
        await expect(activateSchool(db, actor, application.id, input)).rejects.toMatchObject({ statusCode: 409 });
        expect((await db.organization.findUniqueOrThrow({ where: { id: application.organizationId! } })).status).toBe(status);
        expect((await db.user.findUniqueOrThrow({ where: { id: application.adminInvitation!.acceptedUserId! } })).status).toBe('DISABLED');
        expect(await db.platformAuditEvent.count({ where: { entityId: application.id, action: 'tenant.school.activated' } })).toBe(1);
        expect((await service.onboardingProgress(actor, application.id)).stage).toBe('REVIEW_REQUIRED');
      }
    } finally {
      await db.organization.update({ where: { id: application.organizationId! }, data: { status: 'ACTIVE' } });
    }
  }, 20_000);

  it('runs the approved onboarding HTTP journey with real MFA sessions and storage', async () => {
    const app = express(); app.use(express.json());
    app.use('/api/platform', createPlatformRouter(db, signing, [], options));
    app.use('/api/school-invitations', createSchoolInvitationRouter(db));
    app.use(errorHandler);
    const hash = await bcrypt.hash(password, 12);
    const login = async (name: string, role: 'SUPER_ADMIN' | 'IT_SECURITY') => {
      // Fixture identities exist only in the disposable database, never in production.
      const id = randomBytes(15).toString('hex');
      const secret = randomBytes(20);
      const email = `${name}@example.test`;
      await db.platformAccount.create({ data: {
        id, email, fullName: name, role, status: 'ACTIVE', passwordHash: hash,
        mfaSecretEncrypted: encryptMfaSecret(secret, id, key),
      } });
      const response = await request(app).post('/api/platform/login').send({ email, password, code: code(secret) });
      expect(response.status).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.headers['set-cookie']).toBeUndefined();
      expect(response.body.data.user).toMatchObject({ id, role });
      expect(await db.platformSession.count({ where: { accountId: id, revokedAt: null } })).toBe(1);
      return `Bearer ${response.body.data.accessToken}`;
    };
    const requester = await login('http-requester', 'SUPER_ADMIN');
    const reviewer = await login('http-reviewer', 'SUPER_ADMIN');
    const operator = await login('http-operator', 'IT_SECURITY');
    const created = await request(app).post('/api/platform/tenant-applications').set('Authorization', requester).send({
      schoolName: 'HTTP Journey School', requestedCode: 'http-journey-school', adminEmail: 'http-admin@example.test',
    });
    expect(created.status).toBe(201);
    const id = created.body.data.id as string;
    const url = `/api/platform/tenant-applications/${id}`;
    const decision = { decision: 'APPROVED', reason: 'Disposable HTTP ownership evidence checked' };
    expect((await request(app).post(`${url}/review`).set('Authorization', requester).send(decision)).status).toBe(403);
    expect((await request(app).get(`${url}/onboarding-progress`).set('Authorization', operator)).status).toBe(404);
    const queue = '/api/platform/provisioning-queue';
    expect((await request(app).get(queue).query({ q: 'http-journey' }).set('Authorization', operator)).body.data).toEqual([]);
    expect((await request(app).get('/api/platform/tenant-applications').set('Authorization', operator)).status).toBe(403);
    expect((await request(app).post(`${url}/review`).set('Authorization', reviewer).send(decision)).status).toBe(200);
    for (const q of ['http-journey', 'HTTP Journey']) {
      const matches = await request(app).get(queue).query({ q }).set('Authorization', operator);
      expect(matches.status).toBe(200);
      expect(matches.body.data.map((row: { id: string }) => row.id)).toEqual([id]);
    }
    for (const q of ['%', '_', '\\', 'http-admin@example.test']) {
      const matches = await request(app).get(queue).query({ q }).set('Authorization', operator);
      expect(matches.status).toBe(200);
      expect(matches.body.data).toEqual([]);
    }
    expect((await request(app).get(queue).query({ q: 'x'.repeat(101) }).set('Authorization', operator)).status).toBe(422);
    expect((await request(app).post(`${url}/provision`).set('Authorization', reviewer).send({})).status).toBe(403);
    const preflight = await request(app).get(`${url}/provisioning-preflight`).set('Authorization', operator);
    expect(preflight.status).toBe(200);
    expect(preflight.body.data.prerequisitesPassed).toBe(true);
    const beforeSetup = await request(app).get('/api/platform/overview').set('Authorization', reviewer);
    expect(beforeSetup.status).toBe(200);
    const filtered = (setup: string) => request(app).get(queue).query({ q: 'http-journey', setup }).set('Authorization', operator);
    expect((await filtered('pending')).body.data.map((row: { id: string }) => row.id)).toEqual([id]);
    expect((await filtered('created')).body.data).toEqual([]);
    const provisioned = await request(app).post(`${url}/provision`).set('Authorization', operator).send({});
    expect(provisioned.status).toBe(201);
    expect(provisioned.body.data).toMatchObject({ status: 'PENDING_ACTIVATION', created: true });
    expect(typeof provisioned.body.data.organizationId).toBe('string');
    const afterSetup = await request(app).get('/api/platform/overview').set('Authorization', reviewer);
    expect(afterSetup.status).toBe(200);
    expect(afterSetup.body.data.onboarding).toEqual({
      awaitingSetup: beforeSetup.body.data.onboarding.awaitingSetup - 1,
      pendingActivation: beforeSetup.body.data.onboarding.pendingActivation + 1,
    });
    expect((await filtered('pending')).body.data).toEqual([]);
    const createdQueue = await filtered('created');
    expect(createdQueue.status).toBe(200);
    expect(createdQueue.body.data).toHaveLength(1);
    expect(createdQueue.body.data[0]).toMatchObject({ id, organization: { status: 'PENDING_ACTIVATION' } });
    expect((await filtered('active')).status).toBe(422);
    const replay = await request(app).post(`${url}/provision`).set('Authorization', operator).send({});
    expect(replay.status).toBe(200);
    expect(replay.body.data).toMatchObject({ organizationId: provisioned.body.data.organizationId, created: false });
    const auditCount = await db.platformAuditEvent.count();
    for (const authorization of [requester, reviewer, operator]) {
      const response = await request(app).get(`${url}/onboarding-progress`).set('Authorization', authorization);
      expect(response.status).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.body.data).toMatchObject({ stage: 'INVITATION_PENDING', deliveryConfigured: false });
      expect(JSON.stringify(response.body)).not.toContain('http-admin@example.test');
      expect(response.body.data).not.toHaveProperty('tokenHash');
      if (authorization === operator) expect(response.body.data.activationReview).toMatchObject({ prerequisitesPassed: false, activationEnabled: false });
      else expect(response.body.data).not.toHaveProperty('activationReview');
    }
    expect(await db.platformAuditEvent.count()).toBe(auditCount);
    const history = await request(app).get('/api/platform/audit-events').query({ applicationId: id }).set('Authorization', operator);
    expect(history.status).toBe(200);
    expect(history.headers['cache-control']).toBe('no-store');
    expect(history.body.data).toHaveLength(3);
    expect(history.body.data.every((event: { entityId: string; entityType: string }) => event.entityId === id && event.entityType === 'TenantApplication')).toBe(true);
    expect(history.body.data.map((event: { action: string }) => event.action).sort()).toEqual([
      'tenant.application.approved', 'tenant.application.requested', 'tenant.school.provisioned',
    ]);
    const officeHistory = await request(app).get('/api/platform/audit-events').query({ applicationId: id }).set('Authorization', reviewer);
    expect(officeHistory.status).toBe(200);
    expect(officeHistory.body.data.map((event: { action: string }) => event.action).sort()).toEqual([
      'tenant.application.approved', 'tenant.application.requested',
    ]);
    for (const path of ['/health', '/audit-events?action=platform.login.failed', `${url.replace('/api/platform', '')}/provisioning-preflight`]) {
      expect((await request(app).get(`/api/platform${path}`).set('Authorization', reviewer)).status).toBe(403);
    }
    const absentHistory = await request(app).get('/api/platform/audit-events').query({ applicationId: 'missing-application' }).set('Authorization', operator);
    expect(absentHistory.status).toBe(200);
    expect(absentHistory.body.data).toEqual([]);
    const list = await request(app).get('/api/platform/tenant-applications?status=APPROVED').set('Authorization', reviewer);
    expect(list.status).toBe(200);
    expect(list.body.data.find((row: { id: string }) => row.id === id)).toMatchObject({
      organizationId: provisioned.body.data.organizationId,
    });
    expect((await request(app).post('/api/school-invitations/accept').send({})).status).toBe(503);
    expect(await db.organization.count({ where: { code: 'http-journey-school' } })).toBe(1);
    expect(await db.user.count({ where: { orgId: BigInt(provisioned.body.data.organizationId) } })).toBe(0);
    expect(await db.schoolAdminInvitation.count({ where: { applicationId: id } })).toBe(0);
    expect(await db.platformAuditEvent.count({ where: { entityId: id, action: 'tenant.school.provisioned' } })).toBe(1);
    expect((await request(app).post('/api/platform/logout').set('Authorization', operator).send({})).status).toBe(200);
    expect((await request(app).get(`${url}/onboarding-progress`).set('Authorization', operator)).status).toBe(401);
  }, 20_000);

  it('enforces invitation HTTP throttling with real Redis before acceptance', async () => {
    const app = express(); app.use(express.json());
    app.use('/school-invitations', createSchoolInvitationRouter(db, {
      enabled: true, consumeLimit: createSchoolInvitationLimiter(process.env.REDIS_URL!, signing),
    }));
    app.use(errorHandler);
    const body = { token: randomBytes(32).toString('base64url'), fullName: 'Not An Invite', password: 'staging-not-a-credential' };
    const before = await db.user.count();
    for (let attempt = 0; attempt < 10; attempt++) {
      const response = await request(app).post('/school-invitations/accept').send(body);
      expect(response.status).toBe(410);
      expect(response.headers['cache-control']).toBe('no-store');
    }
    const denied = await request(app).post('/school-invitations/accept').send(body);
    expect(denied.status).toBe(429);
    expect(denied.headers['retry-after']).toBe('900');
    expect(await db.user.count()).toBe(before);
    // Rotating tokens cannot evade the shared IP limit.
    for (let attempt = 0; attempt < 19; attempt++) {
      expect((await request(app).post('/school-invitations/accept').send({ ...body, token: randomBytes(32).toString('base64url') })).status).toBe(410);
    }
    expect((await request(app).post('/school-invitations/accept').send({ ...body, token: randomBytes(32).toString('base64url') })).status).toBe(429);
  }, 20_000);

  it("rolls back OTP consumption and session creation when login audit fails", async () => {
    await db.platformAccount.updateMany({ where: { email: "first@example.test" }, data: { lastMfaStep: -1 } });
    const before = await db.platformSession.count();
    await db.$executeRawUnsafe("CREATE TRIGGER staging_fail_login_audit BEFORE INSERT ON platform_audit_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Injected staging audit failure'");
    try {
      await expect(loginPlatform(db, signing, options, { email: "first@example.test", password, code: code(firstSecret) }, "staging-client")).rejects.toThrow();
      expect(await db.platformSession.count()).toBe(before);
      expect((await db.platformAccount.findUniqueOrThrow({ where: { email: "first@example.test" } })).lastMfaStep).toBe(-1n);
    } finally { await db.$executeRawUnsafe("DROP TRIGGER staging_fail_login_audit"); }
  });
});
