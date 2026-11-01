import { Router } from "express";
import { deliverTeacherMedia, openTeacherMedia } from "./teacher-media";

import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import {
  createCourseAccessGrantHandler,
  createCourseAccessRequestHandler,
  createCourseHandler,
  createCourseLessonHandler,
  createCourseModuleHandler,
  createLessonAssetHandler,
  createSubjectHandler,
  listCourseAccessRequestsHandler,
  listCourseLessonsHandler,
  listCourseModulesHandler,
  listLessonAssetsHandler,
  listCoursesHandler,
  listSubjectsHandler,
  updateCourseAccessRequestStatusHandler,
  updateCourseLessonHandler,
  updateCourseModuleHandler,
  updateCourseHandler,
  updateLessonAssetHandler,
} from "./learning.controller";

export const subjectsRouter = Router();
export const coursesRouter = Router();
export const teachingCoursesRouter = Router();

subjectsRouter.use(authenticate, requireTenantContext);
// Media elements cannot attach a bearer header. The short-lived token is
// validated here and current teacher/course permissions are checked again.
coursesRouter.get("/assets/:assetId/deliver", asyncHandler(async (req, res) => {
  const url = await deliverTeacherMedia(String(req.params.assetId), typeof req.query.token === "string" ? req.query.token : "");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  if (typeof url === "string") res.redirect(302, url);
  else res.sendFile(url.filePath);
}));
coursesRouter.use(authenticate, requireTenantContext);
coursesRouter.get("/assets/:assetId/open", requireRole("TEACHER"), asyncHandler(async (req, res) => {
  const data = await openTeacherMedia(req.authUser!, String(req.params.assetId));
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data });
}));
teachingCoursesRouter.use(authenticate, requireTenantContext, requireRole("TEACHER"));

subjectsRouter.get("/", requireRole("ADMIN", "TEACHER"), asyncHandler(listSubjectsHandler));
subjectsRouter.post("/", requireRole("ADMIN"), asyncHandler(createSubjectHandler));

coursesRouter.get("/", requireRole("ADMIN", "TEACHER"), asyncHandler(listCoursesHandler));
coursesRouter.get("/access-requests", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listCourseAccessRequestsHandler));
coursesRouter.patch("/access-requests/:id/status", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(updateCourseAccessRequestStatusHandler));
coursesRouter.post("/", requireRole("ADMIN"), asyncHandler(createCourseHandler));
coursesRouter.post("/:id/grants", requireRole("ADMIN"), asyncHandler(createCourseAccessGrantHandler));
coursesRouter.post("/:id/access-requests", requireRole("LEARNER"), asyncHandler(createCourseAccessRequestHandler));
coursesRouter.get("/:id/modules", requireRole("ADMIN", "TEACHER"), asyncHandler(listCourseModulesHandler));
coursesRouter.post("/:id/modules", requireRole("ADMIN", "TEACHER"), asyncHandler(createCourseModuleHandler));
coursesRouter.patch("/modules/:moduleId", requireRole("ADMIN", "TEACHER"), asyncHandler(updateCourseModuleHandler));
coursesRouter.get("/modules/:moduleId/lessons", requireRole("ADMIN", "TEACHER"), asyncHandler(listCourseLessonsHandler));
coursesRouter.post("/modules/:moduleId/lessons", requireRole("ADMIN", "TEACHER"), asyncHandler(createCourseLessonHandler));
coursesRouter.patch("/lessons/:lessonId", requireRole("ADMIN", "TEACHER"), asyncHandler(updateCourseLessonHandler));
coursesRouter.get("/lessons/:lessonId/assets", requireRole("ADMIN", "TEACHER"), asyncHandler(listLessonAssetsHandler));
coursesRouter.post("/lessons/:lessonId/assets", requireRole("ADMIN", "TEACHER"), asyncHandler(createLessonAssetHandler));
coursesRouter.patch("/assets/:assetId", requireRole("ADMIN", "TEACHER"), asyncHandler(updateLessonAssetHandler));
coursesRouter.patch("/:id", requireRole("ADMIN"), asyncHandler(updateCourseHandler));

teachingCoursesRouter.get("/", asyncHandler(listCoursesHandler));
