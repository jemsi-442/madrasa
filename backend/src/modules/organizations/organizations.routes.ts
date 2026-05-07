import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { getMyOrganizationHandler } from "./organizations.controller";

export const organizationsRouter = Router();

organizationsRouter.get(
  "/me",
  authenticate,
  requireTenantContext,
  asyncHandler(getMyOrganizationHandler),
);

