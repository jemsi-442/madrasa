import type { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import { z } from "zod";

import { HttpError } from "../../shared/errors/http-error";
import type { PlatformContext } from "./platform.service";

export const PLATFORM_ISSUER = "afaq-platform";
export const PLATFORM_AUDIENCE = "afaq-platform-console";

const claimsSchema = z.object({
  sub: z.string().min(1).max(30),
  sid: z.string().uuid(),
  type: z.literal("platform_access"),
  role: z.enum(["SUPER_ADMIN", "IT_SECURITY"]),
  iat: z.number().int().nonnegative(),
  exp: z.number().int().positive(),
});

// School access tokens are never accepted by the platform console.
export async function verifyPlatformAccess(
  db: PrismaClient,
  token: string,
  signingSecret: string,
): Promise<PlatformContext> {
  if (signingSecret.length < 32) throw new HttpError(503, "Platform authentication is not configured");
  let claims: z.infer<typeof claimsSchema>;
  try {
    claims = claimsSchema.parse(jwt.verify(token, signingSecret, {
      algorithms: ["HS256"], issuer: PLATFORM_ISSUER, audience: PLATFORM_AUDIENCE,
    }));
    const now = Math.floor(Date.now() / 1000);
    if (claims.iat > now || claims.exp <= claims.iat || claims.exp - claims.iat > 900) {
      throw new Error("Invalid platform token lifetime");
    }
  } catch {
    throw new HttpError(401, "Invalid platform access token");
  }
  const account = await db.platformAccount.findUnique({
    where: { id: claims.sub }, select: { id: true, status: true, role: true },
  });
  if (!account || account.status !== "ACTIVE" || account.role !== claims.role) {
    throw new HttpError(401, "Platform account is unavailable");
  }
  const session = await db.platformSession.findUnique({ where: { id: claims.sid } });
  const now = Date.now();
  if (!session || session.accountId !== account.id || session.role !== account.role || session.revokedAt ||
      session.expiresAt.getTime() <= now || session.expiresAt.getTime() < claims.exp * 1000 ||
      session.mfaVerifiedAt.getTime() > now || session.mfaVerifiedAt.getTime() < now - 900_000 ||
      Math.floor(session.createdAt.getTime() / 1000) !== claims.iat) {
    throw new HttpError(401, "Platform session is unavailable");
  }
  return { scope: "platform", accountId: account.id, sessionId: session.id };
}
