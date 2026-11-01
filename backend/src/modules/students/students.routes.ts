import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { readGuardianResidence, updateGuardianResidence } from './guardian-residence';
import { readStudentResidence, saveStudentResidence } from './student-residence';
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

studentsRouter.get('/:id/residence', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await readStudentResidence(req.authUser!, req.params.id) });
}));
studentsRouter.post('/:id/residence', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await saveStudentResidence(req.authUser!, req.params.id, req.body) });
}));

studentsRouter.get('/:id/guardian-residence', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await readGuardianResidence(req.authUser!, req.params.id) });
}));
studentsRouter.post('/:id/guardian-residence', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await updateGuardianResidence(req.authUser!, req.params.id, req.body) });
}));

studentsRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listStudentsHandler));
studentsRouter.get("/:id", requireRole("ADMIN", "TEACHER"), asyncHandler(getStudentByIdHandler));
studentsRouter.post("/", requireRole("ADMIN"), asyncHandler(createStudentHandler));
studentsRouter.patch("/:id", requireRole("ADMIN"), asyncHandler(updateStudentHandler));
studentsRouter.post("/:id/guardians", requireRole("ADMIN"), asyncHandler(linkGuardianToStudentHandler));
studentsRouter.patch("/:id/primary-guardian", requireRole("ADMIN"), asyncHandler(setPrimaryGuardianHandler));
studentsRouter.delete(
  "/:id/guardians/:guardianId",
  requireRole("ADMIN"),
  asyncHandler(unlinkGuardianFromStudentHandler),
);

guardiansRouter.get("/", requireRole("ADMIN"), asyncHandler(listGuardiansHandler));
guardiansRouter.post("/", requireRole("ADMIN"), asyncHandler(createGuardianHandler));
