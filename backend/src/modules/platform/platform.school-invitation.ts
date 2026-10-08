import { createHash, randomBytes } from "node:crypto";
import { Prisma, type PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import type { PlatformContext } from "./platform.service";
import { platformAccountIdSchema } from "./platform.schemas";

const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");
const acceptanceSchema = z.object({
  token: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  fullName: z.string().trim().min(2).max(150),
  password: z.string().min(12).max(72).refine((value) => Buffer.byteLength(value, "utf8") <= 72, "Password must not exceed 72 UTF-8 bytes"),
}).strict();

// Internal lifecycle only: no HTTP route until secure delivery and rate limits exist.
// The raw token is returned solely for a future trusted delivery adapter, never IT UI.
export async function issueSchoolAdminInvitation(db: PrismaClient, actor: PlatformContext, applicationId: unknown) {
  const id = platformAccountIdSchema.parse(applicationId);
  if (actor.scope !== "platform") throw new HttpError(401, "Platform authentication required");
  const token = randomBytes(32).toString("base64url");
  return db.$transaction(async (tx) => {
    const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId }, select: { id: true, role: true, status: true } });
    if (account?.role !== "IT_SECURITY" || account.status !== "ACTIVE") throw new HttpError(403, "IT account required");
    const application = await tx.tenantApplication.findUnique({ where: { id }, include: { organization: true, adminInvitation: true } });
    if (!application || application.status !== "APPROVED" || !application.reviewedAt
      || !application.reviewedById || application.reviewedById === application.requestedById
      || application.organization?.status !== "PENDING_ACTIVATION") {
      throw new HttpError(409, "Approved inactive school required");
    }
    if (application.adminInvitation?.acceptedAt || await tx.user.count({ where: { orgId: application.organization.id, role: "ADMIN" } })) {
      throw new HttpError(409, "First administrator already exists");
    }
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const data = { email: application.adminEmail, issuedById: account.id, tokenHash: hashToken(token), expiresAt };
    const invitation = await tx.schoolAdminInvitation.upsert({
      where: { applicationId: id }, create: { ...data, applicationId: id }, update: data,
    });
    await tx.platformAuditEvent.create({ data: {
      actorId: account.id, actorRole: account.role, action: "tenant.admin.invitation.issued",
      entityType: "TenantApplication", entityId: id,
    } });
    return { token, email: application.adminEmail, invitationId: invitation.id, expiresAt };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}

export async function acceptSchoolAdminInvitation(db: PrismaClient, input: unknown) {
  const data = acceptanceSchema.parse(input);
  const tokenHash = hashToken(data.token);
  return db.$transaction(async (tx) => {
    const invitation = await tx.schoolAdminInvitation.findUnique({
      where: { tokenHash }, include: { application: { include: { organization: true } } },
    });
    const application = invitation?.application;
    if (!invitation || invitation.acceptedAt || invitation.expiresAt <= new Date()
      || application?.status !== "APPROVED" || application.adminEmail !== invitation.email
      || !application.reviewedAt || !application.reviewedById || application.reviewedById === application.requestedById
      || application.organization?.status !== "PENDING_ACTIVATION") {
      throw new HttpError(410, "Invitation is unavailable or expired");
    }
    if (await tx.user.count({ where: { orgId: application.organization.id, role: "ADMIN" } })) {
      throw new HttpError(409, "First administrator already exists");
    }
    const passwordHash = await bcrypt.hash(data.password, 12);
    const user = await tx.user.create({ data: {
      orgId: application.organization.id, email: invitation.email, fullName: data.fullName,
      passwordHash, role: "ADMIN", status: "DISABLED",
    }, select: { id: true } });
    // This acceptance receipt and account creation commit together; no login is issued.
    const accepted = await tx.schoolAdminInvitation.updateMany({
      where: { id: invitation.id, tokenHash, acceptedAt: null, expiresAt: { gt: new Date() } },
      data: { acceptedAt: new Date(), acceptedUserId: user.id },
    });
    if (accepted.count !== 1) throw new HttpError(410, "Invitation is unavailable or expired");
    return { status: "PENDING_ACTIVATION" as const };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
