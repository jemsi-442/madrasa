import { randomBytes, randomUUID } from "node:crypto";
import { Prisma, type PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import { PLATFORM_AUDIENCE, PLATFORM_ISSUER } from "./platform.authentication";

const schema = z.object({ email: z.string().trim().toLowerCase().email().max(150), password: z.string().min(1).max(72).refine(value => Buffer.byteLength(value, "utf8") <= 72) }).strict();
const dummyHash = bcrypt.hashSync(randomBytes(32).toString("hex"), 12);

export async function loginPlatformPassword(db: PrismaClient, signingKey: string, input: unknown) {
  if (signingKey.length < 32) throw new HttpError(503, "Sign-in is temporarily unavailable");
  const data = schema.parse(input);
  const account = await db.platformAccount.findUnique({ where: { email: data.email } });
  const matches = await bcrypt.compare(data.password, account?.passwordHash ?? dummyHash);
  if (!account || !matches || account.status !== "ACTIVE") {
    if (account) await db.platformAuditEvent.create({ data: {
      actorId: account.id, actorRole: account.role, action: "platform.login.failed", entityType: "PlatformAccount", entityId: account.id,
    } });
    throw new HttpError(401, "Invalid credentials");
  }
  const now = Math.floor(Date.now() / 1000);
  const sid = randomUUID();
  await db.$transaction(async (tx) => {
    const current = await tx.platformAccount.findFirst({ where: { id: account.id, status: "ACTIVE", role: account.role, passwordHash: account.passwordHash }, select: { id: true } });
    if (!current) throw new HttpError(401, "Invalid credentials");
    await tx.platformSession.create({ data: {
      id: sid, accountId: account.id, role: account.role, createdAt: new Date(now * 1000),
      mfaVerifiedAt: null, expiresAt: new Date((now + 900) * 1000),
    } });
    await tx.platformAuditEvent.create({ data: { actorId: account.id, actorRole: account.role,
      action: "platform.login.succeeded", entityType: "PlatformAccount", entityId: account.id } });
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  const accessToken = jwt.sign({ sub: account.id, sid, role: account.role, type: "platform_access", iat: now, exp: now + 900 }, signingKey,
    { algorithm: "HS256", issuer: PLATFORM_ISSUER, audience: PLATFORM_AUDIENCE });
  return { scope: "platform" as const, accessToken, expiresIn: 900, user: { id: account.id, fullName: account.fullName, role: account.role } };
}
