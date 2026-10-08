import { randomBytes, randomUUID } from "node:crypto";
import type { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";

import { HttpError } from "../../shared/errors/http-error";
import { PLATFORM_AUDIENCE, PLATFORM_ISSUER } from "./platform.authentication";
import { decryptMfaSecret, matchTotpStep, validMfaKey } from "./platform.mfa";

export const platformPassword = z.string().min(12).max(72).refine((v) => Buffer.byteLength(v, "utf8") <= 72);
export const platformLoginSchema = z.object({
  email: z.string().trim().toLowerCase().email().max(150),
  password: z.string().min(1).max(72).refine((v) => Buffer.byteLength(v, "utf8") <= 72),
  code: z.string().regex(/^\d{6}$/),
}).strict();

export type PlatformLoginOptions = {
  encryptionKey: string;
  consumeLimit: (email: string, ip: string) => Promise<void>;
};

// Equal-cost password verification for unknown accounts; not a usable credential.
const dummyHash = bcrypt.hashSync(randomBytes(32).toString("hex"), 12);

export async function loginPlatform(db: PrismaClient, secret: string, options: PlatformLoginOptions, input: unknown, ip: string) {
  if (secret.length < 32 || !validMfaKey(options.encryptionKey) || secret === options.encryptionKey) {
    throw new HttpError(503, "Platform login is not configured");
  }
  const data = platformLoginSchema.parse(input);
  await options.consumeLimit(data.email, ip);
  const account = await db.platformAccount.findUnique({ where: { email: data.email } });
  const passwordOk = await bcrypt.compare(data.password, account?.passwordHash ?? dummyHash);
  let step: bigint | null = null;
  if (account?.mfaSecretEncrypted && passwordOk && account.status === "ACTIVE") {
    try {
      step = matchTotpStep(decryptMfaSecret(account.mfaSecretEncrypted, account.id, options.encryptionKey), data.code);
    } catch {
      throw new HttpError(503, "Platform login is temporarily unavailable");
    }
  }
  if (!account || !passwordOk || account.status !== "ACTIVE" || step === null || step <= account.lastMfaStep) {
    if (account) await db.platformAuditEvent.create({ data: {
      actorId: account.id, actorRole: account.role, action: "platform.login.failed",
      entityType: "PlatformAccount", entityId: account.id,
    } });
    throw new HttpError(401, "Invalid platform credentials or verification code");
  }
  const now = Math.floor(Date.now() / 1000);
  const sid = randomUUID();
  const accessToken = jwt.sign({ sub: account.id, sid, role: account.role, type: "platform_access", iat: now, exp: now + 900 }, secret,
    { algorithm: "HS256", issuer: PLATFORM_ISSUER, audience: PLATFORM_AUDIENCE });
  await db.$transaction(async (tx) => {
    // Consuming a code, creating its session and the audit event must commit together.
    const consumed = await tx.platformAccount.updateMany({ where: {
      id: account.id, status: "ACTIVE", role: account.role, passwordHash: account.passwordHash,
      mfaSecretEncrypted: account.mfaSecretEncrypted, lastMfaStep: { lt: step },
    }, data: { lastMfaStep: step } });
    if (consumed.count !== 1) throw new HttpError(401, "Invalid platform credentials or verification code");
    await tx.platformSession.create({ data: {
      id: sid, accountId: account.id, role: account.role,
      createdAt: new Date(now * 1000), mfaVerifiedAt: new Date(now * 1000), expiresAt: new Date((now + 900) * 1000),
    } });
    await tx.platformAuditEvent.create({ data: {
      actorId: account.id, actorRole: account.role, action: "platform.login.succeeded",
      entityType: "PlatformAccount", entityId: account.id,
    } });
  });
  return { accessToken, expiresIn: 900, user: { id: account.id, fullName: account.fullName, role: account.role } };
}
