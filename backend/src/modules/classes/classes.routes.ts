import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  createClassHandler,
  createEnrollmentHandler,
  getClassByIdHandler,
  listClassesHandler,
  listEnrollmentsHandler,
} from "./classes.controller";

export const classesRouter = Router();
export const enrollmentsRouter = Router();

classesRouter.use(authenticate, requireTenantContext);
enrollmentsRouter.use(authenticate, requireTenantContext);

classesRouter.get("/", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(listClassesHandler));
classesRouter.get("/:id", requireRole("ADMIN", "TEACHER"), asyncHandler(getClassByIdHandler));
classesRouter.post("/", requireRole("ADMIN"), asyncHandler(createClassHandler));

enrollmentsRouter.get(
  "/",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(listEnrollmentsHandler),
);
enrollmentsRouter.post("/", requireRole("ADMIN"), asyncHandler(createEnrollmentHandler));
