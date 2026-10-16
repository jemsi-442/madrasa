import type { CookieOptions, Request, Response } from 'express';
import type { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';
import { verifyPlatformAccess } from '../platform/platform.authentication';
import { HttpError } from '../../shared/errors/http-error';

const name = 'afaq_company_session';
export const companyCookieOptions = (secure: boolean): CookieOptions => ({
  httpOnly: true, secure, sameSite: 'lax', path: '/api/auth/browser',
});
export function readCompanyCookie(req: Request): string | null {
  const value = req.headers.cookie?.split(';').map(p => p.trim())
    .find(p => p.startsWith(`${name}=`))?.slice(name.length + 1);
  if (!value) return null;
  try { return decodeURIComponent(value); } catch { throw new HttpError(401, 'Please sign in'); }
}
export function clearCompanyCookie(res: Response, secure: boolean) {
  res.clearCookie(name, companyCookieOptions(secure));
}
export function setCompanyCookie(res: Response, token: string, expiresIn: number, secure: boolean) {
  res.cookie(name, token, { ...companyCookieOptions(secure), maxAge: expiresIn * 1000 });
}
// Restores the same verified session, never extends its original lifetime.
export async function restoreCompanySession(db: PrismaClient, secret: string, token: string) {
  const context = await verifyPlatformAccess(db, token, secret);
  const user = await db.platformAccount.findUniqueOrThrow({
    where: { id: context.accountId }, select: { id: true, fullName: true, role: true },
  });
  const claims = jwt.decode(token) as jwt.JwtPayload;
  return { scope: 'platform', accessToken: token,
    expiresIn: Math.max(0, claims.exp! - Math.floor(Date.now() / 1000)), user };
}
