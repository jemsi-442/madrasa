import bcrypt from "bcryptjs";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { loginPassword, newSchoolPassword } from "./password.schemas";

export const changePasswordSchema = z.object({ currentPassword: loginPassword, password: newSchoolPassword,
  confirmPassword: newSchoolPassword }).strict().refine(v => v.password === v.confirmPassword, {
    path: ["confirmPassword"], message: "Passwords do not match",
  });

export async function changeSchoolPassword(actor: AuthenticatedUser, raw: unknown) {
  const input = changePasswordSchema.parse(raw);
  const user = await prisma.user.findFirst({ where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId), status: "ACTIVE" } });
  if (!user || !await bcrypt.compare(input.currentPassword, user.passwordHash)) throw new HttpError(400, "Password could not be changed. Check your current password.");
  if (await bcrypt.compare(input.password, user.passwordHash)) throw new HttpError(422, "Choose a different password");
  const passwordHash = await bcrypt.hash(input.password, 12);
  await prisma.$transaction(async tx => {
    const result = await tx.user.updateMany({ where: { id: user.id, orgId: user.orgId, status: "ACTIVE", authVersion: user.authVersion },
      data: { passwordHash, authVersion: { increment: 1 } } });
    if (result.count !== 1) throw new HttpError(409, "Account changed. Sign in and try again.");
    await tx.refreshToken.updateMany({ where: { userId: user.id, revokedAt: null }, data: { revokedAt: new Date() } });
    await tx.auditLog.create({ data: { orgId: user.orgId, actorUserId: user.id, action: "auth.password.changed", entityType: "User", entityId: String(user.id) } });
  });
}

export const resetSchoolPasswordSchema = z.object({ password: newSchoolPassword, confirmPassword: newSchoolPassword,
  verified: z.literal(true) }).strict().refine(v => v.password === v.confirmPassword, { path: ["confirmPassword"], message: "Passwords do not match" });

export async function resetSchoolPassword(actor: AuthenticatedUser, target: string, raw: unknown) {
  const input = resetSchoolPasswordSchema.parse(raw);
  const targetId = BigInt(z.string().regex(/^[1-9]\d*$/).parse(target));
  const passwordHash = await bcrypt.hash(input.password, 12);
  await prisma.$transaction(async tx => {
    const admin = await tx.user.findFirst({ where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: "ADMIN", status: "ACTIVE",
      organization: { status: { in: ["ACTIVE", "TRIAL"] } } }, select: { id: true, branchId: true } });
    if (!admin) throw new HttpError(403, "Access denied");
    // The family recovery workflow cannot reset company or school-administrator accounts.
    const result = await tx.user.updateMany({ where: { id: targetId, orgId: BigInt(actor.orgId), role: "PARENT", status: "ACTIVE",
      ...(admin.branchId ? { branchId: admin.branchId } : {}) }, data: { passwordHash, authVersion: { increment: 1 } } });
    if (result.count !== 1) throw new HttpError(404, "Active parent account not found");
    await tx.refreshToken.updateMany({ where: { userId: targetId, revokedAt: null }, data: { revokedAt: new Date() } });
    await tx.auditLog.create({ data: { orgId: BigInt(actor.orgId), actorUserId: admin.id,
      action: "family.password.reset", entityType: "User", entityId: String(targetId), metadata: { delivery: "MANUAL", identityVerified: true } } });
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
