import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { createUserHandler, listUsersHandler } from "./users.controller";
import { familyRegistrationSchema, issueFamilyRegistration } from "./family-registration";
import { prisma } from "../../shared/db/prisma";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { familyGuardiansQuery, listAvailableFamilyGuardians } from "./family-guardians";
import { listFamilyApplications, reviewFamilyApplication } from "./family-applications";
import { resetSchoolPassword } from "../auth/school-password";

export const usersRouter = Router();

usersRouter.use(authenticate, requireTenantContext, requireActiveSchoolAccount);

usersRouter.get("/", requireRole("ADMIN"), asyncHandler(listUsersHandler));
usersRouter.get("/family-applications", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: await listFamilyApplications(req.authUser!, req.query) });
}));
usersRouter.post("/family-applications/:id/review", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: await reviewFamilyApplication(req.authUser!, String(req.params.id), req.body) });
}));
usersRouter.get("/family-guardians", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  const actor = req.authUser!;
  const data = await listAvailableFamilyGuardians(actor.orgId, actor.branchId, familyGuardiansQuery.parse(req.query));
  res.json({ success: true, data });
}));
usersRouter.post("/", requireRole("ADMIN"), asyncHandler(createUserHandler));
usersRouter.post("/:id/reset-family-password", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  await resetSchoolPassword(req.authUser!, String(req.params.id), req.body);
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: { message: "Password reset. Share privately; no email has been sent." } });
}));
usersRouter.post("/:id/family-registration", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  const input = familyRegistrationSchema.parse(req.body);
  const data = await issueFamilyRegistration(prisma, req.authUser!, String(req.params.id), input.regionCode);
  res.json({ success: true, data });
}));
