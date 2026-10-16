import type { PrismaClient } from "@prisma/client";
import type { RequestHandler } from "express";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import { asyncHandler } from "../../shared/utils/async-handler";
import { loginPlatformPassword } from "../platform/platform.password-login";
import { normalizeLogin, schoolLoginIdentity } from "./login-identity";
import { loginPassword } from "./password.schemas";

const schema = z.object({ login: z.string().trim().min(1).max(150), password: loginPassword }).strict();

// Resolve identity once; never try another role after a password failure.
export function unifiedLogin(db: PrismaClient, signingKey: string,
  consumeLimit: (login: string, ip: string) => Promise<void>,
  clearSchoolCookie?: (res: Parameters<RequestHandler>[1]) => void,
  schoolSecrets: readonly string[] = [],
  browserSession?: (req: Parameters<RequestHandler>[0], res: Parameters<RequestHandler>[1], token: string, expiresIn: number) => void): RequestHandler {
  return asyncHandler(async (req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    const data = schema.parse(req.body);
    const login = normalizeLogin(data.login);
    await consumeLimit(login, req.ip ?? req.socket.remoteAddress ?? "unknown");
    const company = await db.platformAccount.findUnique({ where: { email: login }, select: { id: true } });
    const schoolCount = await db.user.count({ where: schoolLoginIdentity(login) });
    if (schoolCount > 1 || (company && schoolCount > 0)) throw new HttpError(401, "Invalid credentials");
    if (!company) {
      req.body = { login, password: data.password };
      return next();
    }
    if (schoolSecrets.includes(signingKey)) throw new HttpError(503, "Sign-in is temporarily unavailable");
    const result = await loginPlatformPassword(db, signingKey, { email: login, password: data.password });
    clearSchoolCookie?.(res);
    browserSession?.(req, res, result.accessToken, result.expiresIn);
    res.json({ success: true, data: result });
  });
}
