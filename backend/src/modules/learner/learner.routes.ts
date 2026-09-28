import { Router } from "express";

import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import {
  deliverLearnerAssetHandler,
  getLearnerAttendanceHandler,
  openLearnerAssetHandler,
  getLearnerCourseDetailHandler,
  getLearnerFinanceHandler,
  getLearnerHifdhHandler,
  getLearnerLessonDetailHandler,
  initiateLearnerCoursePaymentHandler,
  listLearnerProgressHandler,
  getLearnerProfileHandler,
  getLearnerReceiptsHandler,
  listLearnerCoursesHandler,
  listLearnerAnnouncementsHandler,
  updateLearnerLessonProgressHandler,
} from "./learner.controller";

import { learnerWorkspaceRouter } from "./learner-workspace";

export const learnerRouter = Router();

learnerRouter.get("/assets/:assetId/deliver", asyncHandler(deliverLearnerAssetHandler));
learnerRouter.use(authenticate, requireTenantContext, requireRole("LEARNER"));
learnerRouter.use((_req, res, next) => { res.setHeader("Cache-Control", "no-store"); next(); });

learnerRouter.use("/workspace", learnerWorkspaceRouter);
learnerRouter.get("/me", asyncHandler(getLearnerProfileHandler));
learnerRouter.get("/courses", asyncHandler(listLearnerCoursesHandler));
learnerRouter.get("/courses/:courseId", asyncHandler(getLearnerCourseDetailHandler));
learnerRouter.post("/course-invoices/:invoiceId/payments", asyncHandler(initiateLearnerCoursePaymentHandler));
learnerRouter.get("/lessons/:lessonId", asyncHandler(getLearnerLessonDetailHandler));
learnerRouter.post("/lessons/:lessonId/progress", asyncHandler(updateLearnerLessonProgressHandler));
learnerRouter.get("/assets/:assetId/open", asyncHandler(openLearnerAssetHandler));
learnerRouter.get("/attendance", asyncHandler(getLearnerAttendanceHandler));
learnerRouter.get("/progress", asyncHandler(listLearnerProgressHandler));
learnerRouter.get("/finance", asyncHandler(getLearnerFinanceHandler));
learnerRouter.get("/receipts", asyncHandler(getLearnerReceiptsHandler));
learnerRouter.get("/hifdh", asyncHandler(getLearnerHifdhHandler));
learnerRouter.get("/announcements", asyncHandler(listLearnerAnnouncementsHandler));
