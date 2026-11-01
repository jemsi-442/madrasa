import { Router } from "express";
import { z } from "zod";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { directoryQuery, recordId, sessionInput, sessionQuery, supportInput, timetableInput, voidInput } from "./teacher.schemas";
import { addSupport, resolveSupport, saveQuran, studentQuran, teacherClasses, teacherOverview, teacherStudentProfile, teacherStudents, voidQuran } from "./teacher.service";
import { cancelTimetable, createTimetable, getTimetable } from "./timetable.service";
import catalog from "./quran-catalog.json";
import { passageRosterQuery } from "./teacher.schemas";
import { passageRoster } from "./teacher.service";
import { env } from "../../config/env";
import { QuranContentClient } from "./quran-content";

const quranContent = new QuranContentClient({
  enabled: env.QF_ENABLED, environment: env.QF_ENV,
  clientId: env.QF_CLIENT_ID, clientSecret: env.QF_CLIENT_SECRET,
});

export const teacherWorkspaceRouter = Router();
export const classTimetableRouter = Router();
for (const router of [teacherWorkspaceRouter, classTimetableRouter]) {
  router.use(authenticate, requireTenantContext, requireRole("ADMIN", "TEACHER"));
  router.use(requireActiveSchoolAccount);
}
teacherWorkspaceRouter.use(requireRole("TEACHER"));
teacherWorkspaceRouter.get("/overview", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await teacherOverview(req.authUser!) });
}));
teacherWorkspaceRouter.get("/classes", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await teacherClasses(req.authUser!) });
}));
teacherWorkspaceRouter.get("/students", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await teacherStudents(req.authUser!, directoryQuery.parse(req.query)) });
}));
teacherWorkspaceRouter.get("/students/:id", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await teacherStudentProfile(req.authUser!, recordId.parse(req.params.id)) });
}));
teacherWorkspaceRouter.get("/quran/catalog", (_req, res) => {
  res.json({ success: true, data: { chapters: catalog.chapters, juzs: catalog.juzs } });
});
teacherWorkspaceRouter.get("/quran/content/chapters", asyncHandler(async (req, res) => {
  z.object({}).strict().parse(req.query);
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: await quranContent.chapters() });
}));
teacherWorkspaceRouter.get("/quran/content/chapters/:chapter/verses", asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: await quranContent.verses(req.params.chapter, req.query) });
}));
teacherWorkspaceRouter.get("/quran", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await studentQuran(req.authUser!, sessionQuery.parse(req.query)) });
}));
teacherWorkspaceRouter.get("/quran/roster", asyncHandler(async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: await passageRoster(req.authUser!, passageRosterQuery.parse(req.query)) });
}));
teacherWorkspaceRouter.post("/quran/sessions", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await saveQuran(req.authUser!, sessionInput.parse(req.body)) });
}));
teacherWorkspaceRouter.post("/quran/sessions/:id/void", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await voidQuran(req.authUser!, recordId.parse(req.params.id), voidInput.parse(req.body).reason) });
}));
teacherWorkspaceRouter.post("/support", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await addSupport(req.authUser!, supportInput.parse(req.body)) });
}));
teacherWorkspaceRouter.post("/support/:id/resolve", asyncHandler(async (req, res) => {
  z.object({}).strict().parse(req.body);
  res.json({ success: true, data: await resolveSupport(req.authUser!, recordId.parse(req.params.id)) });
}));
classTimetableRouter.get("/:classId/timetable", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await getTimetable(req.authUser!, recordId.parse(req.params.classId)) });
}));
classTimetableRouter.post("/:classId/timetable", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await createTimetable(req.authUser!, recordId.parse(req.params.classId), timetableInput.parse(req.body)) });
}));
classTimetableRouter.post("/:classId/timetable/:id/cancel", requireRole("ADMIN"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await cancelTimetable(req.authUser!, recordId.parse(req.params.classId),
    recordId.parse(req.params.id), voidInput.parse(req.body).reason) });
}));
