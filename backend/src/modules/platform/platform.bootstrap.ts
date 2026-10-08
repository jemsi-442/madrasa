import { randomBytes } from "node:crypto";
import { Prisma, type PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import { platformPassword } from "./platform.login";
import { encryptMfaSecret, matchTotpStep } from "./platform.mfa";

const inputSchema = z.object({
  fullName: z.string().trim().min(2).max(150),
  email: z.string().trim().toLowerCase().email().max(150),
  password: platformPassword,
  code: z.string().regex(/^\d{6}$/),
}).strict();

// Local operator tool only. Never expose this function through an HTTP route.
export async function bootstrapPlatformReviewer(db: PrismaClient, input: unknown, mfaSecret: Buffer, encryptionKey: string) {
  const data = inputSchema.parse(input);
  const step = matchTotpStep(mfaSecret, data.code);
  if (step === null) throw new HttpError(422, "Authenticator confirmation failed");
  const id = randomBytes(15).toString("hex");
  const passwordHash = await bcrypt.hash(data.password, 12);
  const encrypted = encryptMfaSecret(mfaSecret, id, encryptionKey);
  return db.$transaction(async (tx) => {
    // Serializable prevents concurrent bootstrap requests from exceeding two reviewers.
    const count = await tx.platformAccount.count({ where: { role: "SUPER_ADMIN" } });
    if (count >= 2) throw new HttpError(409, "Initial reviewers already exist; bootstrap is closed");
    const account = await tx.platformAccount.create({ data: {
      id, email: data.email, fullName: data.fullName, passwordHash,
      role: "SUPER_ADMIN", status: "ACTIVE", mfaSecretEncrypted: encrypted, lastMfaStep: step,
    }, select: { id: true, fullName: true, role: true } });
    await tx.platformAuditEvent.create({ data: {
      actorId: id, actorRole: "SUPER_ADMIN", action: "platform.account.bootstrapped",
      entityType: "PlatformAccount", entityId: id,
    } });
    return account;
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
