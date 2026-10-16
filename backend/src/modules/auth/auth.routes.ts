import { Router } from "express";
import { browserLogin, browserLogout, browserRefresh, protectBrowserSession, clearSchoolCookie } from "./browser-session";
import { unifiedLogin } from "./unified-login";
import { setCompanyCookie } from './company-browser-session';
import { prisma } from "../../shared/db/prisma";
import { env } from "../../config/env";
import { createPlatformLoginLimiter } from "../platform/platform.login-limit";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { loginHandler, logoutAllHandler, logoutHandler, meHandler, refreshHandler } from "./auth.controller";
import { limitRegistration, registerLearnerHandler } from "./registration";
import { submitFamilyApplication } from "../users/family-applications";
import { changeSchoolPassword } from "./school-password";

export const authRouter = Router();
const resolveLogin = unifiedLogin(prisma, env.PLATFORM_JWT_SECRET,
  createPlatformLoginLimiter(env.REDIS_URL, env.PLATFORM_JWT_SECRET || env.JWT_SECRET), clearSchoolCookie,
  [env.JWT_SECRET, env.JWT_REFRESH_SECRET], (req, res, token, expiresIn) => {
    if (req.path === '/browser/login') setCompanyCookie(res, token, expiresIn, env.NODE_ENV === 'production');
  });

authRouter.use("/browser", protectBrowserSession);
authRouter.post("/browser/login", resolveLogin, asyncHandler(browserLogin));
authRouter.post("/browser/refresh", asyncHandler(browserRefresh));
authRouter.post("/browser/logout", asyncHandler(browserLogout));
authRouter.post("/browser/register", asyncHandler(limitRegistration), asyncHandler(registerLearnerHandler));

authRouter.post("/login", resolveLogin, asyncHandler(loginHandler));
authRouter.post("/register", asyncHandler(limitRegistration), asyncHandler(registerLearnerHandler));
authRouter.post("/family-registration", asyncHandler(limitRegistration), asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.status(202).json({ success: true, data: await submitFamilyApplication(req.body) });
}));
authRouter.post("/refresh", asyncHandler(refreshHandler));
authRouter.post("/logout", asyncHandler(logoutHandler));
authRouter.post("/logout-all", authenticate, requireTenantContext, asyncHandler(logoutAllHandler));
authRouter.get("/me", authenticate, requireTenantContext, asyncHandler(meHandler));
authRouter.post("/change-password", authenticate, requireTenantContext, asyncHandler(limitRegistration), asyncHandler(async (req, res) => {
  await changeSchoolPassword(req.authUser!, req.body);
  clearSchoolCookie(res);
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: { message: "Password changed. Sign in again on all devices." } });
}));
