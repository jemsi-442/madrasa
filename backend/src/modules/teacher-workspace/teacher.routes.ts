import { Router } from "express";
import { z } from "zod";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import { directoryQuery, recordId, sessionInput, sessionQuery, supportInput, timetableInput, voidInput } from "./teacher.schemas";
import { addSupport, resolveSupport, saveQuran, studentQuran, teacherClasses, teacherOverview, teacherStudentProfile, teacherStudents, voidQuran } from "./teacher.service";
import { cancelTimetable, createTimetable, getTimetable } from "./timetable.service";
import catalog from "./quran-catalog.json";

export const teacherWorkspaceRouter = Router();
export const classTimetableRouter = Router();
for (const router of [teacherWorkspaceRouter, classTimetableRouter]) {
  router.use(authenticate, requireTenantContext, requireRole("ADMIN", "TEACHER"));
  router.use(asyncHandler(async (req, _res, next) => {
    const actor = req.authUser!;
    const account = await prisma.user.findFirst({ where: {
      id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: actor.role, status: "ACTIVE",
      organization: { status: { in: ["ACTIVE", "TRIAL"] } },
    }, select: { branchId: true } });
    if (!account) throw new HttpError(403, "This account is no longer available");
    actor.branchId = account.branchId?.toString() ?? null;
    next();
  }));
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
teacherWorkspaceRouter.get("/quran", asyncHandler(async (req, res) => {
  res.json({ success: true, data: await studentQuran(req.authUser!, sessionQuery.parse(req.query)) });
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
