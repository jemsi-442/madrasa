import type { CookieOptions, Request, Response } from "express";

import { env } from "../../config/env";
import { HttpError } from "../../shared/errors/http-error";
import { asyncHandler } from "../../shared/utils/async-handler";
import { loginSchema } from "./auth.schemas";
import { login, logout, refreshSession } from "./auth.service";
import { prisma } from '../../shared/db/prisma';
import { readCompanyCookie, clearCompanyCookie, restoreCompanySession } from './company-browser-session';
import { verifyPlatformAccess } from '../platform/platform.authentication';

const cookieName = "mif_browser_session";
const cookieOptions: CookieOptions = {
  httpOnly: true,
  secure: env.NODE_ENV === "production",
  sameSite: "lax",
  path: "/api/auth/browser",
};

export const clearSchoolCookie = (res: Response) => { res.clearCookie(cookieName, cookieOptions); };

export const allowedBrowserOrigin = (origin: string): boolean => {
  const configured = env.WEB_APP_ORIGINS.split(",").map((value) => value.trim()).filter(Boolean);
  if (configured.includes(origin) || origin === new URL(env.APP_BASE_URL).origin) return true;
  if (env.NODE_ENV === "production") return false;
  try {
    const url = new URL(origin);
    return url.origin === origin && ["http:", "https:"].includes(url.protocol)
      && ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  } catch {
    return false;
  }
};

export const protectBrowserSession = asyncHandler(async (req, res, next) => {
  res.setHeader("Cache-Control", "no-store");
  // Browser auth relies on cookies: require a trusted Origin and a preflighted header.
  const origin = req.get("Origin");
  if (!origin || !allowedBrowserOrigin(origin) || req.get("X-MIF-Browser") !== "1") {
    throw new HttpError(403, "This sign-in request is not allowed");
  }
  next();
});

const readCookie = (req: Request): string | null => {
  const value = req.headers.cookie?.split(";").map((part) => part.trim())
    .find((part) => part.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1);
  if (!value) return null;
  try { return decodeURIComponent(value); } catch { return null; }
};

export const sendBrowserSession = (
  res: Response,
  session: Awaited<ReturnType<typeof login>>,
  status = 200,
) => {
  clearCompanyCookie(res, env.NODE_ENV === 'production');
  res.cookie(cookieName, session.refreshToken, cookieOptions);
  const { refreshToken: _refreshToken, ...publicSession } = session;
  res.status(status).json({ success: true, data: publicSession });
};

export const browserLogin = async (req: Request, res: Response) => {
  sendBrowserSession(res, await login(loginSchema.parse(req.body)));
};

export const browserRefresh = async (req: Request, res: Response) => {
  try {
    const companyToken = readCompanyCookie(req);
    if (companyToken) {
      if ([env.JWT_SECRET, env.JWT_REFRESH_SECRET].includes(env.PLATFORM_JWT_SECRET)) throw new HttpError(503, 'Sign-in is temporarily unavailable');
      const data = await restoreCompanySession(prisma, env.PLATFORM_JWT_SECRET, companyToken);
      res.json({ success: true, data });
      return;
    }
    const refreshToken = readCookie(req);
    if (!refreshToken) throw new HttpError(401, "Please sign in");
    sendBrowserSession(res, await refreshSession({ refreshToken }));
  } catch (error) {
    if (error instanceof HttpError && error.statusCode === 401) {
      res.clearCookie(cookieName, cookieOptions);
      clearCompanyCookie(res, env.NODE_ENV === 'production');
    }
    throw error;
  }
};

export const browserLogout = async (req: Request, res: Response) => {
  try {
    const token = readCompanyCookie(req);
    if (token) {
      const context = await verifyPlatformAccess(prisma, token, env.PLATFORM_JWT_SECRET);
      await prisma.platformSession.updateMany({ where: { id: context.sessionId, accountId: context.accountId, revokedAt: null }, data: { revokedAt: new Date() } });
    }
  } catch (error) {
    if (!(error instanceof HttpError && error.statusCode === 401)) throw error;
  }
  clearCompanyCookie(res, env.NODE_ENV === 'production');
  const refreshToken = readCookie(req);
  if (refreshToken) {
    try { await logout({ refreshToken }); } catch (error) {
      if (!(error instanceof HttpError && error.statusCode === 401)) throw error;
    }
  }
  res.clearCookie(cookieName, cookieOptions);
  res.json({ success: true });
};
