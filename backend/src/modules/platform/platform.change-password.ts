import bcrypt from "bcryptjs";
import { Prisma, type PrismaClient } from "@prisma/client";
import { changePasswordSchema } from "../auth/school-password";
import { HttpError } from "../../shared/errors/http-error";
import type { PlatformContext } from "./platform.service";

export async function changePlatformPassword(db: PrismaClient, actor: PlatformContext, raw: unknown) {
  const input = changePasswordSchema.parse(raw);
  const account = await db.platformAccount.findFirst({ where: { id: actor.accountId, status: "ACTIVE" } });
  if (!account || !await bcrypt.compare(input.currentPassword, account.passwordHash)) throw new HttpError(400, "Password could not be changed. Check your current password.");
  if (await bcrypt.compare(input.password, account.passwordHash)) throw new HttpError(422, "Choose a different password");
  const passwordHash = await bcrypt.hash(input.password, 12);
  await db.$transaction(async tx => {
    const session = await tx.platformSession.findFirst({ where: { id: actor.sessionId, accountId: actor.accountId, revokedAt: null, expiresAt: { gt: new Date() } } });
    if (!session) throw new HttpError(401, "Please sign in again");
    const changed = await tx.platformAccount.updateMany({ where: { id: account.id, status: "ACTIVE", passwordHash: account.passwordHash }, data: { passwordHash } });
    if (changed.count !== 1) throw new HttpError(409, "Account changed. Sign in and try again.");
    await tx.platformSession.updateMany({ where: { accountId: account.id, revokedAt: null }, data: { revokedAt: new Date() } });
    await tx.platformAuditEvent.create({ data: { actorId: account.id, actorRole: account.role, action: "platform.password.changed", entityType: "PlatformAccount", entityId: account.id } });
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
