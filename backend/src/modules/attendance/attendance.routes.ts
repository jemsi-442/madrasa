import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  bulkMarkAttendanceHandler,
  getClassAttendanceHandler,
  getStudentAttendanceHandler,
} from "./attendance.controller";

export const attendanceRouter = Router();

attendanceRouter.use(authenticate, requireTenantContext);

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
