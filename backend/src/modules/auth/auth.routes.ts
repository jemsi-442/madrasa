import { Router } from "express";
import { browserLogin, browserLogout, browserRefresh, protectBrowserSession } from "./browser-session";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { loginHandler, logoutAllHandler, logoutHandler, meHandler, refreshHandler } from "./auth.controller";
import { limitRegistration, registerLearnerHandler } from "./registration";

export const authRouter = Router();

authRouter.use("/browser", protectBrowserSession);
authRouter.post("/browser/login", asyncHandler(browserLogin));
authRouter.post("/browser/refresh", asyncHandler(browserRefresh));
authRouter.post("/browser/logout", asyncHandler(browserLogout));
authRouter.post("/browser/register", asyncHandler(limitRegistration), asyncHandler(registerLearnerHandler));

authRouter.post("/login", asyncHandler(loginHandler));
authRouter.post("/register", asyncHandler(limitRegistration), asyncHandler(registerLearnerHandler));
authRouter.post("/refresh", asyncHandler(refreshHandler));
authRouter.post("/logout", asyncHandler(logoutHandler));
authRouter.post("/logout-all", authenticate, requireTenantContext, asyncHandler(logoutAllHandler));
authRouter.get("/me", authenticate, requireTenantContext, asyncHandler(meHandler));
