import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { loginHandler, logoutAllHandler, logoutHandler, meHandler, refreshHandler } from "./auth.controller";

export const authRouter = Router();

authRouter.post("/login", asyncHandler(loginHandler));
authRouter.post("/refresh", asyncHandler(refreshHandler));
authRouter.post("/logout", asyncHandler(logoutHandler));
authRouter.post("/logout-all", authenticate, requireTenantContext, asyncHandler(logoutAllHandler));
authRouter.get("/me", authenticate, requireTenantContext, asyncHandler(meHandler));
