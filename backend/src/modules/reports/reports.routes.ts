import { Router } from "express";

import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import {
  exportMonthlyFinanceSummaryReportHandler,
  getAttendanceSummaryReportHandler,
  exportAttendanceReportHandler,
  exportPaymentsReportHandler,
  exportStudentsReportHandler,
  getDashboardReportHandler,
  getFinanceHomeReportHandler,
  getMonthlyFinanceSummaryReportHandler,
  getTeacherDashboardReportHandler,
} from "./reports.controller";

export const reportsRouter = Router();

reportsRouter.use(authenticate, requireTenantContext);

reportsRouter.get(
  "/dashboard",
  requireRole("ADMIN"),
  asyncHandler(getDashboardReportHandler),
);
reportsRouter.get(
  "/finance/home",
  requireRole("ADMIN", "ACCOUNTANT"),
  asyncHandler(getFinanceHomeReportHandler),
);
reportsRouter.get(
  "/students/export",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(exportStudentsReportHandler),
);
reportsRouter.get(
  "/payments/export",
  requireRole("ADMIN", "ACCOUNTANT"),
  asyncHandler(exportPaymentsReportHandler),
);
reportsRouter.get(
  "/attendance/export",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(exportAttendanceReportHandler),
);
reportsRouter.get(
  "/attendance/summary",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(getAttendanceSummaryReportHandler),
);
reportsRouter.get(
  "/finance/monthly-summary",
  requireRole("ADMIN", "ACCOUNTANT"),
  asyncHandler(getMonthlyFinanceSummaryReportHandler),
);
reportsRouter.get(
  "/finance/monthly-summary/export",
  requireRole("ADMIN", "ACCOUNTANT"),
  asyncHandler(exportMonthlyFinanceSummaryReportHandler),
);
reportsRouter.get(
  "/teacher-dashboard",
  requireRole("ADMIN", "TEACHER"),
  asyncHandler(getTeacherDashboardReportHandler),
);
