import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  createGuardianHandler,
  createStudentHandler,
  getStudentByIdHandler,
  linkGuardianToStudentHandler,
  listGuardiansHandler,
  listStudentsHandler,
  setPrimaryGuardianHandler,
  unlinkGuardianFromStudentHandler,
  updateStudentHandler,
} from "./students.controller";

export const studentsRouter = Router();
export const guardiansRouter = Router();

studentsRouter.use(authenticate, requireTenantContext);
guardiansRouter.use(authenticate, requireTenantContext);

studentsRouter.get("/", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(listStudentsHandler));
studentsRouter.get("/:id", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(getStudentByIdHandler));
studentsRouter.post("/", requireRole("ADMIN"), asyncHandler(createStudentHandler));
studentsRouter.patch("/:id", requireRole("ADMIN"), asyncHandler(updateStudentHandler));
studentsRouter.post("/:id/guardians", requireRole("ADMIN"), asyncHandler(linkGuardianToStudentHandler));
studentsRouter.patch("/:id/primary-guardian", requireRole("ADMIN"), asyncHandler(setPrimaryGuardianHandler));
studentsRouter.delete(
  "/:id/guardians/:guardianId",
  requireRole("ADMIN"),
  asyncHandler(unlinkGuardianFromStudentHandler),
);

guardiansRouter.get("/", requireRole("ADMIN", "ACCOUNTANT", "TEACHER"), asyncHandler(listGuardiansHandler));
guardiansRouter.post("/", requireRole("ADMIN"), asyncHandler(createGuardianHandler));
