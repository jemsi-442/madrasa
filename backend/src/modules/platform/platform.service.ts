import { Prisma, type PrismaClient } from "@prisma/client";

import { HttpError } from "../../shared/errors/http-error";
import { assertPlatformPermission, hasPlatformPermission, type PlatformPermission } from "./platform.permissions";
import { platformPageSchema, platformAuditQuerySchema, platformSessionIdSchema, tenantApplicationSchema, tenantDecisionSchema } from "./platform.schemas";
import type { PlatformHealthReader } from "./platform.health";
import { platformAccountIdSchema, platformDisableAccountSchema, platformAccountQuerySchema, platformRestoreAccountSchema, platformApplicationQuerySchema, platformProvisioningQuerySchema } from "./platform.schemas";
import { technicalReviewFingerprint, reviewWithdrawalWhere } from "./platform.technical-review";

// Only a future verified platform session may construct this context.
// Do not adapt a school req.authUser into it, even for a school ADMIN.
export type PlatformContext = Readonly<{ scope: "platform"; accountId: string; sessionId: string }>;

export const officeHistoryActions = [
  "tenant.application.requested", "tenant.application.approved", "tenant.application.rejected",
  "tenant.school.activated", "platform.account.disabled", "platform.account.restored",
];

export class PlatformGovernanceService {
  constructor(private readonly db: PrismaClient) {}

  async onboardingProgress(actor: PlatformContext, input: unknown) {
    const id = platformAccountIdSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "tenant.onboarding.read");
      const application = await tx.tenantApplication.findFirst({
        where: { id, status: "APPROVED" },
        select: { id: true, status: true, schoolName: true, requestedCode: true, adminEmail: true,
          requestedById: true, reviewedById: true, reviewedAt: true, provisionedAt: true,
          organization: { select: { id: true, status: true } },
          adminInvitation: { select: { id: true, email: true, createdAt: true, expiresAt: true, acceptedAt: true,
            acceptedUser: { select: { id: true, orgId: true, email: true, role: true, status: true } } } },
        },
      });
      if (!application) throw new HttpError(404, "Approved application not found");
      const now = new Date();
      const organization = application.organization;
      const invitation = application.adminInvitation;
      const user = invitation?.acceptedUser;
      const approved = Boolean(application.reviewedAt && application.reviewedById && application.reviewedById !== application.requestedById);
      const accepted = Boolean(invitation?.acceptedAt && user && organization && user.orgId === organization.id
        && user.role === "ADMIN" && user.email === invitation.email && invitation.email === application.adminEmail);
      const activation = organization ? await tx.platformAuditEvent.findFirst({
        where: { entityType: "TenantApplication", entityId: id, action: "tenant.school.activated" },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], select: { createdAt: true },
      }) : null;
      let stage: string;
      if (!approved) stage = "REVIEW_REQUIRED";
      else if (!organization) stage = invitation ? "REVIEW_REQUIRED" : "PROVISIONING_PENDING";
      else if (!application.provisionedAt) stage = "REVIEW_REQUIRED";
      else if (organization.status === "ACTIVE") stage = accepted && user?.status === "ACTIVE" && activation ? "ACTIVE" : "REVIEW_REQUIRED";
      else if (organization.status !== "PENDING_ACTIVATION" || activation) stage = "REVIEW_REQUIRED";
      else if (!invitation) stage = "INVITATION_PENDING";
      else if (invitation.email !== application.adminEmail) stage = "REVIEW_REQUIRED";
      else if (user && !invitation.acceptedAt) stage = "REVIEW_REQUIRED";
      else if (invitation.acceptedAt) stage = accepted && user?.status === "DISABLED" ? "ACTIVATION_REVIEW_PENDING" : "REVIEW_REQUIRED";
      else stage = invitation.expiresAt <= now ? "INVITATION_EXPIRED" : "ACCEPTANCE_PENDING";
      let signOffStatus = "NOT_READY";
      if (stage === "ACTIVATION_REVIEW_PENDING") {
        const review = await tx.platformAuditEvent.findFirst({
          where: { entityType: "TenantApplication", entityId: id, action: "tenant.technical-review.recorded", actorRole: "IT_SECURITY" },
          orderBy: [{ createdAt: "desc" }, { id: "desc" }],
          select: { id: true, actorId: true, createdAt: true, metadata: true },
        });
        signOffStatus = "MISSING";
        if (review) {
          const withdrawn = await tx.platformAuditEvent.findFirst({ where: reviewWithdrawalWhere(review.id), select: { id: true } });
          const age = now.getTime() - review.createdAt.getTime();
          const metadata = review.metadata;
          if (withdrawn) signOffStatus = "WITHDRAWN";
          else if (age < 0 || age >= 86_400_000) signOffStatus = "EXPIRED";
          else if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)
            || metadata.fingerprint !== technicalReviewFingerprint(application)) signOffStatus = "STATE_CHANGED";
          else {
            const operator = await tx.platformAccount.findUnique({ where: { id: review.actorId }, select: { role: true, status: true } });
            signOffStatus = operator?.role === "IT_SECURITY" && operator.status === "ACTIVE" ? "CURRENT" : "OPERATOR_UNAVAILABLE";
          }
        }
      }
      return {
        applicationId: id, schoolName: application.schoolName, requestedCode: application.requestedCode,
        stage, checkedAt: now.toISOString(),
        ...(stage === "ACTIVATION_REVIEW_PENDING" ? {
          nextResponsibility: signOffStatus === "CURRENT" ? "OFFICE_APPROVAL" : "IT_REVIEW",
        } : {}),
        steps: [
          { label: "Independent approval", completed: approved, at: application.reviewedAt },
          { label: "Inactive school created", completed: Boolean(organization), at: application.provisionedAt },
          { label: "Invitation record created", completed: Boolean(invitation), at: invitation?.createdAt ?? null },
          { label: "Admin acceptance recorded", completed: accepted, at: invitation?.acceptedAt ?? null },
          { label: "Activation audited", completed: Boolean(activation), at: activation?.createdAt ?? null },
        ],
        invitationExpiresAt: invitation?.expiresAt ?? null,
        deliveryConfigured: false,
        ...(account.role === "IT_SECURITY" ? {
          activationReview: {
            signOffStatus,
            activationEnabled: false,
            prerequisitesPassed: stage === "ACTIVATION_REVIEW_PENDING" && account.id !== application.requestedById,
            checks: [
              { label: "Application independently approved", passed: approved },
              { label: "You are not the original requester", passed: account.id !== application.requestedById },
              { label: "Provisioning timestamp recorded", passed: Boolean(organization && application.provisionedAt) },
              { label: "School is awaiting activation", passed: organization?.status === "PENDING_ACTIVATION" },
              { label: "Matching first-admin acceptance recorded", passed: accepted },
              { label: "Accepted administrator is disabled until activation", passed: accepted && user?.status === "DISABLED" },
              { label: "No previous activation recorded", passed: !activation },
            ],
            manualReviews: ["Tenant isolation", "Access controls", "Audit trail", "Backup and recovery", "Support escalation"],
          },
        } : {}),
      };
    });
  }

  async listProvisioningQueue(actor: PlatformContext, input: unknown = {}) {
    const { page, pageSize, q, setup } = platformProvisioningQuerySchema.parse(input);
    // Treat SQL LIKE metacharacters as literal search text, not wildcards.
    const search = q?.replace(/[\\%_]/g, "\\$&");
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "tenant.provisioning.create");
      const applications = await tx.tenantApplication.findMany({
        where: { status: "APPROVED",
          ...(setup === "pending" ? { organizationId: null } : setup === "created" ? { organizationId: { not: null } } : {}),
          ...(search ? { OR: [
          { schoolName: { contains: search } }, { requestedCode: { contains: search } },
        ] } : {}) },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize, take: pageSize,
        select: { id: true, schoolName: true, requestedCode: true, reviewedAt: true,
          organization: { select: { id: true, status: true } } },
      });
      return applications.map(({ organization, ...application }) => ({ ...application,
        organization: organization ? { id: organization.id.toString(), status: organization.status } : null,
      }));
    });
  }

  async provisionPendingSchool(actor: PlatformContext, input: unknown) {
    const id = platformAccountIdSchema.parse(input);
    try {
      return await this.db.$transaction(async (tx) => {
        const account = await this.authorize(tx, actor, "tenant.provisioning.create");
        const application = await tx.tenantApplication.findUnique({
          where: { id },
          select: { id: true, status: true, schoolName: true, requestedCode: true,
            requestedById: true, reviewedById: true, reviewedAt: true, organizationId: true,
            organization: { select: { id: true, status: true } } },
        });
        if (!application || application.status !== "APPROVED") {
          throw new HttpError(404, "Approved application not found");
        }
        if (!application.reviewedAt || !application.reviewedById
          || application.reviewedById === application.requestedById) {
          throw new HttpError(409, "Independent approval is required");
        }
        // The application link is the idempotency key, not a client-supplied school ID.
        if (application.organization) {
          return { organizationId: application.organization.id.toString(),
            status: application.organization.status, created: false };
        }
        const organization = await tx.organization.create({
          data: { name: application.schoolName, code: application.requestedCode, status: "PENDING_ACTIVATION" },
          select: { id: true, status: true },
        });
        const linked = await tx.tenantApplication.updateMany({
          where: { id, status: "APPROVED", organizationId: null },
          data: { organizationId: organization.id, provisionedAt: new Date() },
        });
        if (linked.count !== 1) throw new HttpError(409, "Application changed; refresh and try again");
        await tx.platformAuditEvent.create({ data: {
          actorId: account.id, actorRole: account.role, action: "tenant.school.provisioned",
          entityType: "TenantApplication", entityId: id,
          metadata: { status: "PENDING_ACTIVATION", organizationId: organization.id.toString() },
        } });
        return { organizationId: organization.id.toString(), status: organization.status, created: true };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code)) {
        throw new HttpError(409, "School code or application changed; refresh and retry the same application");
      }
      throw error;
    }
  }

  async provisioningPreflight(actor: PlatformContext, input: unknown) {
    const id = platformAccountIdSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "tenant.provisioning.inspect");
      // IT can inspect an approved handoff, not browse unreviewed applications.
      const application = await tx.tenantApplication.findFirst({
        where: { id, status: "APPROVED" },
        select: { id: true, requestedCode: true, requestedById: true, reviewedById: true, reviewedAt: true, organizationId: true },
      });
      if (!application) throw new HttpError(404, "Approved application not found");
      const independentReview = Boolean(application.reviewedAt && application.reviewedById
        && application.reviewedById !== application.requestedById);
      const existing = await tx.organization.findUnique({
        where: { code: application.requestedCode }, select: { id: true },
      });
      return {
        applicationId: application.id, checkedAt: new Date().toISOString(),
        checks: { independentReview, schoolCodeAvailable: existing === null },
        prerequisitesPassed: independentReview && existing === null,
        provisioningEnabled: false,
        pendingSchoolCreationImplemented: true,
        alreadyProvisioned: application.organizationId != null,
        nextSteps: ["PENDING_SCHOOL_CREATION", "FIRST_ADMIN_INVITATION", "ADMIN_ACCEPTANCE", "SCHOOL_ACTIVATION"],
      };
    });
  }

  async overview(actor: PlatformContext) {
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "platform.overview.read");
      const applications = await tx.tenantApplication.groupBy({ by: ["status"], _count: { _all: true } });
      const accounts = await tx.platformAccount.groupBy({ by: ["role", "status"], _count: { _all: true } });
      const awaitingYourReview = await tx.tenantApplication.count({ where: { status: "REQUESTED", requestedById: { not: actor.accountId } } });
      const awaitingSetup = await tx.tenantApplication.count({ where: { status: "APPROVED", organizationId: null } });
      const pendingActivation = await tx.tenantApplication.count({ where: {
        status: "APPROVED", organization: { is: { status: "PENDING_ACTIVATION" } },
      } });
      const applicationCounts = { REQUESTED: 0, APPROVED: 0, REJECTED: 0 };
      for (const row of applications) applicationCounts[row.status] = row._count._all;
      const accountCounts = { SUPER_ADMIN: { ACTIVE: 0, DISABLED: 0 }, IT_SECURITY: { ACTIVE: 0, DISABLED: 0 } };
      for (const row of accounts) accountCounts[row.role][row.status] = row._count._all;
      return { checkedAt: new Date().toISOString(), applications: applicationCounts, awaitingYourReview, accounts: accountCounts,
        onboarding: { awaitingSetup, pendingActivation } };
    });
  }

  async disableItAccount(actor: PlatformContext, targetId: unknown, input: unknown) {
    const id = platformAccountIdSchema.parse(targetId);
    const { reason } = platformDisableAccountSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "platform.account.disable.it");
      if (id === account.id) throw new HttpError(403, "Self-disable is not permitted");
      const target = await tx.platformAccount.findUnique({ where: { id }, select: { id: true, role: true, status: true } });
      if (!target) throw new HttpError(404, "Platform account not found");
      if (target.role !== "IT_SECURITY") throw new HttpError(403, "Only IT Security accounts can be disabled here");
      if (target.status !== "ACTIVE") throw new HttpError(409, "Account is not active");
      const changed = await tx.platformAccount.updateMany({
        where: { id, role: "IT_SECURITY", status: "ACTIVE" }, data: { status: "DISABLED" },
      });
      if (changed.count !== 1) throw new HttpError(409, "Account has changed; refresh and try again");
      const sessions = await tx.platformSession.updateMany({
        where: { accountId: id, revokedAt: null }, data: { revokedAt: new Date() },
      });
      await tx.platformAuditEvent.create({ data: {
        actorId: account.id, actorRole: account.role, action: "platform.account.disabled",
        entityType: "PlatformAccount", entityId: id,
        metadata: { previousStatus: "ACTIVE", status: "DISABLED", count: sessions.count, reason },
      } });
      return { id, status: "DISABLED", revoked: sessions.count };
    });
  }

  async listAccounts(actor: PlatformContext, input: unknown = {}) {
    const { page, pageSize, role, status } = platformAccountQuerySchema.parse(input);
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "platform.account.read");
      return tx.platformAccount.findMany({
        where: { ...(role ? { role } : {}), ...(status ? { status } : {}) },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize, take: pageSize,
        select: { id: true, fullName: true, email: true, role: true, status: true, createdAt: true },
      });
    });
  }

  async restoreItAccount(actor: PlatformContext, targetId: unknown, input: unknown) {
    const id = platformAccountIdSchema.parse(targetId);
    const { reason, suspensionEventId } = platformRestoreAccountSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "platform.account.restore.it");
      if (id === account.id) throw new HttpError(403, "Self-restore is not permitted");
      const target = await tx.platformAccount.findUnique({ where: { id },
        select: { id: true, role: true, status: true, mfaSecretEncrypted: true } });
      if (!target) throw new HttpError(404, "Platform account not found");
      if (target.role !== "IT_SECURITY") throw new HttpError(403, "Only IT Security accounts can be restored here");
      if (target.status !== "DISABLED" || !target.mfaSecretEncrypted) throw new HttpError(409, "Account is not eligible for restoration");
      const suspension = await tx.platformAuditEvent.findFirst({
        where: { entityType: "PlatformAccount", entityId: id, action: { in: ["platform.account.disabled", "platform.account.restored"] } },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], select: { id: true, actorId: true, action: true },
      });
      if (!suspension || suspension.action !== "platform.account.disabled") throw new HttpError(409, "No recorded suspension to review");
      if (suspension.actorId === account.id) throw new HttpError(403, "Another Super Admin must review restoration");
      if (suspension.id !== suspensionEventId) throw new HttpError(409, "Suspension has changed; review the latest event");
      const changed = await tx.platformAccount.updateMany({
        where: { id, role: "IT_SECURITY", status: "DISABLED", mfaSecretEncrypted: target.mfaSecretEncrypted }, data: { status: "ACTIVE" },
      });
      if (changed.count !== 1) throw new HttpError(409, "Account has changed; refresh and try again");
      const sessions = await tx.platformSession.updateMany({ where: { accountId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.platformAuditEvent.create({ data: {
        actorId: account.id, actorRole: account.role, action: "platform.account.restored", entityType: "PlatformAccount", entityId: id,
        metadata: { previousStatus: "DISABLED", status: "ACTIVE", count: sessions.count, reason, suspensionEventId: suspension.id },
      } });
      return { id, status: "ACTIVE", revoked: sessions.count };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async accountAccessHistory(actor: PlatformContext, targetId: unknown, input: unknown = {}) {
    const id = platformAccountIdSchema.parse(targetId);
    const { page, pageSize } = platformPageSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "platform.account.read");
      const target = await tx.platformAccount.findUnique({ where: { id }, select: { id: true } });
      if (!target) throw new HttpError(404, "Platform account not found");
      const events = await tx.platformAuditEvent.findMany({
        where: { entityType: "PlatformAccount", entityId: id, action: { in: ["platform.account.disabled", "platform.account.restored"] } },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], skip: (page - 1) * pageSize, take: pageSize,
        select: { id: true, action: true, actorId: true, createdAt: true, metadata: true },
      });
      return events.map(({ metadata, ...event }) => {
        const value = metadata && typeof metadata === "object" && !Array.isArray(metadata) ? metadata : {};
        return { ...event, reason: typeof value.reason === "string" ? value.reason.slice(0, 500) : null,
          metadata: safePlatformAuditMetadata(metadata) };
      });
    });
  }

  async listOwnSessions(actor: PlatformContext, input: unknown = {}) {
    const { page, pageSize } = platformPageSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "platform.session.self");
      const now = new Date();
      const sessions = await tx.platformSession.findMany({
        where: { accountId: account.id, role: account.role, revokedAt: null, expiresAt: { gt: now },
          createdAt: { gte: new Date(now.getTime() - 900_000), lte: now } },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], skip: (page - 1) * pageSize, take: pageSize,
        select: { id: true, createdAt: true, expiresAt: true, mfaVerifiedAt: true },
      });
      return sessions.map((session) => ({ ...session, current: session.id === actor.sessionId }));
    });
  }

  async revokeOwnSession(actor: PlatformContext, input: unknown) {
    const id = platformSessionIdSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "platform.session.self");
      const owned = await tx.platformSession.findFirst({ where: { id, accountId: account.id }, select: { id: true } });
      if (!owned) throw new HttpError(404, "Session not found");
      const changed = await tx.platformSession.updateMany({
        where: { id, accountId: account.id, revokedAt: null }, data: { revokedAt: new Date() },
      });
      if (changed.count) await tx.platformAuditEvent.create({ data: {
        actorId: account.id, actorRole: account.role, action: "platform.session.revoked",
        entityType: "PlatformSession", entityId: id, metadata: { count: changed.count },
      } });
      return { revoked: changed.count, current: id === actor.sessionId };
    });
  }

  async health(actor: PlatformContext, readHealth?: PlatformHealthReader) {
    await this.db.$transaction(async (tx) => this.authorize(tx, actor, "platform.health.read"));
    if (!readHealth) throw new HttpError(503, "Platform health is not configured");
    return readHealth();
  }

  async logout(actor: PlatformContext, allSessions = false) {
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "platform.session.self");
      const changed = await tx.platformSession.updateMany({
        where: { accountId: account.id, ...(allSessions ? {} : { id: actor.sessionId }), revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (changed.count > 0) {
        await tx.platformAuditEvent.create({ data: {
          actorId: account.id, actorRole: account.role,
          action: allSessions ? "platform.sessions.revoked" : "platform.session.revoked",
          entityType: "PlatformAccount", entityId: account.id,
          metadata: { count: changed.count },
        } });
      }
      return { revoked: changed.count };
    });
  }

  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext, permission?: PlatformPermission) {
    if (actor.scope !== "platform" || !actor.accountId) {
      throw new HttpError(401, "Platform authentication required");
    }
    const account = await tx.platformAccount.findUnique({
      where: { id: actor.accountId },
      select: { id: true, role: true, status: true },
    });
    if (!account || account.status !== "ACTIVE") {
      throw new HttpError(403, "Platform account is not active");
    }
    if (permission) assertPlatformPermission(account.role, permission);
    return account;
  }

  async createApplication(actor: PlatformContext, input: unknown) {
    const data = tenantApplicationSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "tenant.application.create");
      const existing = await tx.organization.findUnique({
        where: { code: data.requestedCode }, select: { id: true },
      });
      if (existing) throw new HttpError(409, "Madrassa code is already in use");
      const application = await tx.tenantApplication.create({
        data: { ...data, requestedById: account.id },
      });
      await tx.platformAuditEvent.create({
        data: {
          actorId: account.id, actorRole: account.role,
          action: "tenant.application.requested", entityType: "TenantApplication", entityId: application.id,
          metadata: { status: "REQUESTED" },
        },
      });
      return application;
    });
  }

  async reviewApplication(actor: PlatformContext, id: string, input: unknown) {
    const decision = tenantDecisionSchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor, "tenant.application.review");
      const application = await tx.tenantApplication.findUnique({ where: { id } });
      if (!application) throw new HttpError(404, "Madrassa application not found");
      if (application.status !== "REQUESTED") throw new HttpError(409, "Application has already been reviewed");
      // A second Super Admin must review: creating a request is not approval.
      if (application.requestedById === account.id) throw new HttpError(403, "Another Super Admin must review this application");
      if (decision.decision === "APPROVED") {
        const existing = await tx.organization.findUnique({
          where: { code: application.requestedCode }, select: { id: true },
        });
        if (existing) throw new HttpError(409, "Madrassa code is already in use");
      }
      const changed = await tx.tenantApplication.updateMany({
        where: { id, status: "REQUESTED" },
        data: {
          status: decision.decision, reviewedById: account.id,
          decisionReason: decision.reason, reviewedAt: new Date(),
        },
      });
      // Compare-and-set prevents concurrent approvals/rejections from overwriting a decision.
      if (changed.count !== 1) throw new HttpError(409, "Application has already been reviewed");
      await tx.platformAuditEvent.create({
        data: {
          actorId: account.id, actorRole: account.role,
          action: `tenant.application.${decision.decision.toLowerCase()}`,
          entityType: "TenantApplication", entityId: id,
          metadata: { previousStatus: "REQUESTED", status: decision.decision },
        },
      });
      return tx.tenantApplication.findUniqueOrThrow({ where: { id } });
    });
  }

  async listApplications(actor: PlatformContext, input: unknown = {}) {
    const { page, pageSize, status, scope } = platformApplicationQuerySchema.parse(input);
    return this.db.$transaction(async (tx) => {
      await this.authorize(tx, actor, "tenant.application.read");
      const applications = await tx.tenantApplication.findMany({
        where: {
          ...(scope === "reviewable" ? { status: "REQUESTED" as const, requestedById: { not: actor.accountId } }
            : { ...(status ? { status } : {}), ...(scope === "mine" ? { requestedById: actor.accountId } : {}) }),
        },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize, take: pageSize,
      });
      return applications.map((application) => ({ ...application,
        organizationId: application.organizationId?.toString() ?? null,
      }));
    });
  }

  async listAuditEvents(actor: PlatformContext, input: unknown = {}) {
    const { page, pageSize, action, actorRole, actorId, applicationId, technicalReviewId, from, to } = platformAuditQuerySchema.parse(input);
    return this.db.$transaction(async (tx) => {
      const account = await this.authorize(tx, actor);
      const technical = hasPlatformPermission(account.role, "platform.audit.read");
      if (!technical) {
        assertPlatformPermission(account.role, "platform.office-history.read");
        if (technicalReviewId || actorId || actorRole || (action && !officeHistoryActions.includes(action))) {
          throw new HttpError(403, "Technical audit is restricted to IT");
        }
      }
      const events = await tx.platformAuditEvent.findMany({
        where: {
          ...(action ? { action } : {}), ...(actorRole ? { actorRole } : {}), ...(actorId ? { actorId } : {}),
          ...(!technical ? { action: action ?? { in: officeHistoryActions } } : {}),
          ...(technicalReviewId ? { AND: [{ OR: [
            { id: technicalReviewId, entityType: "TenantApplication", action: "tenant.technical-review.recorded" },
            { entityType: "TechnicalReview", entityId: technicalReviewId, action: "tenant.technical-review.withdrawn" },
          ] }] } : {}),
          ...(applicationId ? technical ? {
            OR: [
              { entityType: "TenantApplication", entityId: applicationId },
              { entityType: "TechnicalReview", action: "tenant.technical-review.withdrawn",
                metadata: { path: "$.applicationId", equals: applicationId } },
            ],
          } : { entityType: "TenantApplication", entityId: applicationId } : {}),
          ...((from || to) ? { createdAt: { ...(from ? { gte: new Date(from) } : {}), ...(to ? { lte: new Date(to) } : {}) } } : {}),
        },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize, take: pageSize,
        select: {
          id: true, actorId: true, actorRole: true, action: true,
          entityType: true, entityId: true, metadata: true, createdAt: true,
        },
      });
      return events.map((event) => ({ ...event, metadata: safePlatformAuditMetadata(event.metadata) }));
    });
  }
}

// Only operational status/count fields are exposed, even if future writers store more.
export function safePlatformAuditMetadata(input: unknown): Record<string, string | number> {
  if (!input || typeof input !== "object" || Array.isArray(input)) return {};
  const value = input as Record<string, unknown>;
  const safe: Record<string, string | number> = {};
  for (const field of ["status", "previousStatus"]) {
    if (typeof value[field] === "string" && ["REQUESTED", "APPROVED", "REJECTED", "ACTIVE", "DISABLED", "PENDING_ACTIVATION"].includes(value[field])) safe[field] = value[field];
  }
  if (typeof value.count === "number" && Number.isSafeInteger(value.count) && value.count >= 0) safe.count = value.count;
  return safe;
}
