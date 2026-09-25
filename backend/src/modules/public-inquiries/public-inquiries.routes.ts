import { Router } from "express";

import {
  listTenantPublicInquiriesHandler,
  updateTenantPublicInquiryStatusHandler,
} from "./public-inquiries.controller";
import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";

export const publicInquiriesRouter = Router();

publicInquiriesRouter.use(authenticate, requireTenantContext);

publicInquiriesRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listTenantPublicInquiriesHandler));
publicInquiriesRouter.patch(
  "/:id/status",
  requireRole("ADMIN", "ACCOUNTANT"),
  asyncHandler(updateTenantPublicInquiryStatusHandler),
);
