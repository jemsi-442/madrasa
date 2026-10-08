import { createHash } from "node:crypto";
import { Prisma, type PrismaClient } from "@prisma/client";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import { assertPlatformPermission } from "./platform.permissions";
import { platformAccountIdSchema } from "./platform.schemas";
import type { PlatformContext } from "./platform.service";

export const technicalReviewSchema = z.object({
  invitationId: platformAccountIdSchema,
  evidenceReference: z.string().trim().min(10).max(500),
  checks: z.object({
    tenantIsolation: z.literal(true), accessControls: z.literal(true),
    auditTrail: z.literal(true), backupRecovery: z.literal(true),
    supportEscalation: z.literal(true),
  }).strict(),
}).strict();

const withdrawalSchema = z.object({
  technicalReviewId: platformAccountIdSchema,
  reason: z.string().trim().min(10).max(500),
}).strict();

// A separate immutable receipt invalidates this review, not future IT reviews.
export function reviewWithdrawalWhere(reviewId: string) {
  return { entityType: "TechnicalReview", entityId: reviewId, action: "tenant.technical-review.withdrawn" };
}

export const activationApplicationSelect = {
  status: true, requestedById: true, reviewedById: true, reviewedAt: true,
  provisionedAt: true, adminEmail: true,
  organization: { select: { id: true, status: true } },
  adminInvitation: { select: { id: true, email: true, acceptedAt: true,
    acceptedUser: { select: { id: true, orgId: true, email: true, role: true, status: true } } } },
} satisfies Prisma.TenantApplicationSelect;

type Application = Prisma.TenantApplicationGetPayload<{ select: typeof activationApplicationSelect }>;

// Bind evidence to the exact reviewed onboarding state without copying contacts into audit metadata.
export function technicalReviewFingerprint(application: Application): string {
  const invitation = application.adminInvitation;
  const user = invitation?.acceptedUser;
  const state = [
    application.status, application.requestedById, application.reviewedById,
    application.reviewedAt, application.provisionedAt, application.adminEmail,
    application.organization?.id.toString(), application.organization?.status,
    invitation?.id, invitation?.email, invitation?.acceptedAt,
    user?.id.toString(), user?.orgId.toString(), user?.email, user?.role, user?.status,
  ];
  return createHash("sha256").update(JSON.stringify(state)).digest("hex");
}

// Internal only. Attestations are human evidence review, not automated security tests.
export async function recordTechnicalReview(db: PrismaClient, actor: PlatformContext, applicationId: unknown, input: unknown) {
  const id = platformAccountIdSchema.parse(applicationId);
  const data = technicalReviewSchema.parse(input);
  if (actor.scope !== "platform") throw new HttpError(401, "Platform authentication required");
  try {
    return await db.$transaction(async (tx) => {
      const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId }, select: { id: true, role: true, status: true } });
      if (!account || account.status !== "ACTIVE") throw new HttpError(403, "Active platform account required");
      assertPlatformPermission(account.role, "tenant.technical-review.create");
      const application = await tx.tenantApplication.findUnique({ where: { id }, select: activationApplicationSelect });
      const invitation = application?.adminInvitation;
      const user = invitation?.acceptedUser;
      if (!application || application.status !== "APPROVED" || !application.reviewedAt || !application.reviewedById
        || application.reviewedById === application.requestedById || !application.provisionedAt
        || application.organization?.status !== "PENDING_ACTIVATION"
        || invitation?.id !== data.invitationId || !invitation.acceptedAt || !user
        || user.orgId !== application.organization.id || user.role !== "ADMIN" || user.status !== "DISABLED"
        || user.email !== invitation.email || invitation.email !== application.adminEmail) {
        throw new HttpError(409, "Consistent approved onboarding and accepted administrator required");
      }
      const activated = await tx.platformAuditEvent.findFirst({ where: { entityType: "TenantApplication", entityId: id, action: "tenant.school.activated" }, select: { id: true } });
      if (activated) throw new HttpError(409, "Previously activated school requires separate review");
      const receipt = await tx.platformAuditEvent.create({ data: {
        actorId: account.id, actorRole: account.role, entityType: "TenantApplication", entityId: id,
        action: "tenant.technical-review.recorded",
        metadata: { fingerprint: technicalReviewFingerprint(application), invitationId: invitation.id,
          evidenceReference: data.evidenceReference, operatorAttestations: data.checks },
      }, select: { id: true, createdAt: true } });
      return { reviewId: receipt.id, expiresAt: new Date(receipt.createdAt.getTime() + 86_400_000).toISOString() };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2034") {
      throw new HttpError(409, "Onboarding changed; refresh and review again");
    }
    throw error;
  }
}

export async function withdrawTechnicalReview(db: PrismaClient, actor: PlatformContext, applicationId: unknown, input: unknown) {
  const id = platformAccountIdSchema.parse(applicationId);
  const data = withdrawalSchema.parse(input);
  if (actor.scope !== "platform") throw new HttpError(401, "Platform authentication required");
  try {
    return await db.$transaction(async (tx) => {
      const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId }, select: { id: true, role: true, status: true } });
      if (!account || account.status !== "ACTIVE") throw new HttpError(403, "Active platform account required");
      assertPlatformPermission(account.role, "tenant.technical-review.create");
      const application = await tx.tenantApplication.findUnique({ where: { id }, select: { status: true, organization: { select: { status: true } } } });
      if (application?.status !== "APPROVED" || application.organization?.status !== "PENDING_ACTIVATION") {
        throw new HttpError(409, "Only pending onboarding reviews can be withdrawn");
      }
      const activated = await tx.platformAuditEvent.findFirst({ where: { entityType: "TenantApplication", entityId: id, action: "tenant.school.activated" }, select: { id: true } });
      if (activated) throw new HttpError(409, "Activated schools require separate incident handling");
      const review = await tx.platformAuditEvent.findFirst({
        where: { entityType: "TenantApplication", entityId: id, action: "tenant.technical-review.recorded", actorRole: "IT_SECURITY" },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], select: { id: true },
      });
      if (!review || review.id !== data.technicalReviewId) throw new HttpError(409, "Refresh and select the latest IT review");
      const withdrawn = await tx.platformAuditEvent.findFirst({ where: reviewWithdrawalWhere(review.id), select: { id: true } });
      if (withdrawn) return { withdrawn: false };
      await tx.platformAuditEvent.create({ data: {
        ...reviewWithdrawalWhere(review.id), actorId: account.id, actorRole: account.role,
        metadata: { applicationId: id, reason: data.reason },
      } });
      return { withdrawn: true };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2034") {
      throw new HttpError(409, "Onboarding changed; refresh and review again");
    }
    throw error;
  }
}
