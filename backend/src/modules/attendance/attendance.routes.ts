import { Router } from "express";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  bulkMarkAttendanceHandler,
  getClassAttendanceHandler,
  getStudentAttendanceHandler,
} from "./attendance.controller";

import { registerQuerySchema, registerSaveSchema } from "./register.schemas";
import { getRegister, getRegisterHistory, saveRegister } from "./register.service";

export const attendanceRouter = Router();

attendanceRouter.use(authenticate, requireTenantContext, requireActiveSchoolAccount);

attendanceRouter.get("/register", requireRole("ADMIN", "TEACHER"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await getRegister(req.authUser!, registerQuerySchema.parse(req.query)) });
}));
attendanceRouter.get("/register/history", requireRole("ADMIN", "TEACHER"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await getRegisterHistory(req.authUser!, registerQuerySchema.parse(req.query)) });
}));
attendanceRouter.post("/register", requireRole("ADMIN", "TEACHER"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await saveRegister(req.authUser!, registerSaveSchema.parse(req.body)) });
}));

attendanceRouter.post(
  "/bulk-mark",
  requireRole("TEACHER"),
  asyncHandler(bulkMarkAttendanceHandler),
);
attendanceRouter.get(
  "/class/:classId",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(getClassAttendanceHandler),
);
attendanceRouter.get(
  "/student/:studentId",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(getStudentAttendanceHandler),
);
