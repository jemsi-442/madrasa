import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  createHifdhProgressHandler,
  getHifdhProgressByIdHandler,
  listHifdhProgressHandler,
} from "./hifdh.controller";

export const hifdhRouter = Router();

hifdhRouter.use(authenticate, requireTenantContext);

hifdhRouter.get("/", requireRole("ADMIN", "TEACHER"), asyncHandler(listHifdhProgressHandler));
hifdhRouter.get("/:id", requireRole("ADMIN", "TEACHER"), asyncHandler(getHifdhProgressByIdHandler));
hifdhRouter.post("/", requireRole("TEACHER"), asyncHandler(createHifdhProgressHandler));
