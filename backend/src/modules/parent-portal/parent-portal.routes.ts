import { Router } from "express";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { familyWorkspaceRouter } from "./family-workspace";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  getParentProfileHandler,
  getParentStudentHifdhHandler,
  getParentStudentPaymentHandler,
  getParentStudentPaymentReceiptHandler,
  getParentStudentAttendanceHandler,
  getParentStudentFinanceHandler,
  initiateParentStudentPaymentHandler,
  listParentAnnouncementsHandler,
  listParentStudentsHandler,
} from "./parent-portal.controller";

export const parentPortalRouter = Router();

parentPortalRouter.use(authenticate, requireTenantContext, requireRole("PARENT", "ADMIN"), requireActiveSchoolAccount);
parentPortalRouter.use("/workspace", familyWorkspaceRouter);

parentPortalRouter.get("/me", asyncHandler(getParentProfileHandler));
parentPortalRouter.get("/students", asyncHandler(listParentStudentsHandler));
parentPortalRouter.get("/students/:studentId/attendance", asyncHandler(getParentStudentAttendanceHandler));
parentPortalRouter.get("/students/:studentId/finance", asyncHandler(getParentStudentFinanceHandler));
parentPortalRouter.get("/students/:studentId/hifdh", asyncHandler(getParentStudentHifdhHandler));
parentPortalRouter.post("/students/:studentId/payments", requireRole("PARENT"), asyncHandler(initiateParentStudentPaymentHandler));
parentPortalRouter.get("/students/:studentId/payments/:paymentId", asyncHandler(getParentStudentPaymentHandler));
parentPortalRouter.get(
  "/students/:studentId/payments/:paymentId/receipt",
  asyncHandler(getParentStudentPaymentReceiptHandler),
);
parentPortalRouter.get("/announcements", asyncHandler(listParentAnnouncementsHandler));
