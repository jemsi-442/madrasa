import { Prisma, type PrismaClient } from "@prisma/client";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import { assertPlatformPermission } from "./platform.permissions";
import { platformAccountIdSchema } from "./platform.schemas";
import type { PlatformContext } from "./platform.service";

const activationSchema = z.object({
  invitationId: platformAccountIdSchema,
  evidenceReference: z.string().trim().min(10).max(500),
  checks: z.object({
    tenantIsolation: z.literal(true),
    accessControls: z.literal(true),
    auditTrail: z.literal(true),
    backupRecovery: z.literal(true),
    supportEscalation: z.literal(true),
  }).strict(),
}).strict();

// Internal only until invitation delivery/acceptance and the review UI are connected.
// Checklist entries are operator attestations, not automated verification results.
export async function activateSchool(db: PrismaClient, actor: PlatformContext, applicationId: unknown, input: unknown) {
  const id = platformAccountIdSchema.parse(applicationId);
  const data = activationSchema.parse(input);
  if (actor.scope !== "platform") throw new HttpError(401, "Platform authentication required");
  try {
    return await db.$transaction(async (tx) => {
      const account = await tx.platformAccount.findUnique({
        where: { id: actor.accountId }, select: { id: true, status: true, role: true },
      });
      if (!account || account.status !== "ACTIVE") throw new HttpError(403, "Active platform account required");
      assertPlatformPermission(account.role, "tenant.activation.approve");
      const application = await tx.tenantApplication.findUnique({ where: { id },
        select: { status: true, requestedById: true, reviewedById: true, reviewedAt: true, provisionedAt: true, adminEmail: true,
          organization: { select: { id: true, status: true } },
          adminInvitation: { select: { id: true, email: true, acceptedAt: true,
            acceptedUser: { select: { id: true, orgId: true, email: true, role: true, status: true } } } } },
      });
      if (!application || application.status !== "APPROVED" || !application.organization || !application.provisionedAt) {
        throw new HttpError(409, "Approved provisioned school required");
      }
      if (!application.reviewedAt || !application.reviewedById || application.reviewedById === application.requestedById) {
        throw new HttpError(409, "Independent application review required");
      }
      if (application.requestedById === account.id) throw new HttpError(403, "Another Super Admin must authorize activation");
      const invitation = application.adminInvitation;
      const user = invitation?.acceptedUser;
      const organization = application.organization;
      if (!invitation || invitation.id !== data.invitationId || !invitation.acceptedAt || !user
        || invitation.email !== application.adminEmail || user.email !== invitation.email
        || user.orgId !== organization.id || user.role !== "ADMIN") {
        throw new HttpError(409, "Matching first-admin acceptance required");
      }
      const receipt = await tx.platformAuditEvent.findFirst({ where: {
        entityType: "TenantApplication", entityId: id, action: "tenant.school.activated",
      }, select: { id: true } });
      if (receipt) {
        if (organization.status === "ACTIVE" && user.status === "ACTIVE") {
          return { organizationId: organization.id.toString(), status: "ACTIVE" as const, activated: false };
        }
        // Onboarding cannot repair later state changes to an already activated school.
        throw new HttpError(409, "Recorded activation does not match current access; review required");
      }
      // Never turn suspension or a later admin-disable action into onboarding replay.
      if (organization.status !== "PENDING_ACTIVATION" || user.status !== "DISABLED") {
        throw new HttpError(409, "School or administrator is not awaiting activation");
      }
      const changed = await tx.organization.updateMany({
        where: { id: organization.id, status: "PENDING_ACTIVATION" }, data: { status: "ACTIVE" },
      });
      const enabled = await tx.user.updateMany({
        where: { id: user.id, orgId: organization.id, email: invitation.email, role: "ADMIN", status: "DISABLED" },
        data: { status: "ACTIVE" },
      });
      if (changed.count !== 1 || enabled.count !== 1) throw new HttpError(409, "Activation state changed; refresh and review again");
      await tx.platformAuditEvent.create({ data: {
        actorId: account.id, actorRole: account.role, action: "tenant.school.activated",
        entityType: "TenantApplication", entityId: id,
        metadata: { previousStatus: "PENDING_ACTIVATION", status: "ACTIVE",
          invitationId: invitation.id, organizationId: organization.id.toString(),
          evidenceReference: data.evidenceReference, operatorAttestations: data.checks },
      } });
      return { organizationId: organization.id.toString(), status: "ACTIVE" as const, activated: true };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2034") {
      throw new HttpError(409, "Activation state changed; refresh and review again");
    }
    throw error;
  }
}
