import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  createAnnouncementHandler,
  getAnnouncementByIdHandler,
  listAnnouncementsHandler,
} from "./announcements.controller";

export const announcementsRouter = Router();

announcementsRouter.use(authenticate, requireTenantContext);

announcementsRouter.get("/", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(listAnnouncementsHandler));
announcementsRouter.get("/:id", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(getAnnouncementByIdHandler));
announcementsRouter.post("/", requireRole("ADMIN"), asyncHandler(createAnnouncementHandler));
