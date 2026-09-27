import { Prisma } from "@prisma/client";
import { Router, type Request, type Response } from "express";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import { schoolDate } from "../attendance/register.service";
import { listParentAnnouncements } from "./parent-portal.service";
import { attendanceSummary, memorised, readQuran } from "../learner/learner-records";
import catalog from "../teacher-workspace/quran-catalog.json";

const monthSchema = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).refine(v => Number(v.slice(0, 4)) >= 2000 && Number(v.slice(0, 4)) <= 2100);
const monthQuery = z.object({ month: monthSchema.optional() }).strict();
const pageQuery = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1) }).strict();
const idSchema = z.string().regex(/^[1-9]\d*$/);
const totalAyahs = catalog.chapters.reduce((sum, chapter) => sum + chapter.ayahCount, 0);
const studentFields = Prisma.validator<Prisma.StudentSelect>()({
  id: true, fullName: true, admissionNo: true, gender: true, dob: true,
  status: true, joinedOn: true, branchId: true, classId: true,
  branch: { select: { id: true, name: true } },
  currentClass: { select: { id: true, name: true, level: true, academicYear: true,
    teacher: { select: { fullName: true } } } },
});
const sessionFields = Prisma.validator<Prisma.QuranSessionSelect>()({
  id: true, studentId: true, surahId: true, ayahFrom: true, ayahTo: true,
  learnedOn: true, activity: true, observation: true,
  teacher: { select: { fullName: true } },
});

async function guardian(actor: AuthenticatedUser) {
  if (actor.role !== "PARENT") throw new HttpError(403, "Parent account required");
  const orgId = BigInt(actor.orgId);
  const record = await prisma.guardian.findFirst({ where: { orgId, userId: BigInt(actor.userId) },
    select: { id: true, fullName: true, phone: true, email: true, relationship: true,
      studentLinks: { where: { orgId, student: { orgId } }, orderBy: { studentId: "asc" },
        select: { student: { select: studentFields } } } } });
  if (!record) throw new HttpError(404, "The school office has not linked your guardian profile yet");
  return record;
}
async function child(actor: AuthenticatedUser, id: string) {
  const parent = await guardian(actor);
  const student = parent.studentLinks.find(link => String(link.student.id) === id)?.student;
  if (!student) throw new HttpError(404, "Child not found for this parent account");
  return { parent, student };
}
function period(month = schoolDate().slice(0, 7)) {
  const [year, number] = month.split("-").map(Number);
  return { month, from: new Date(Date.UTC(year!, number! - 1, 1)), until: new Date(Date.UTC(year!, number!, 1)) };
}

async function overview(actor: AuthenticatedUser, month?: string) {
  const parent = await guardian(actor), orgId = BigInt(actor.orgId), window = period(month);
  const ids = parent.studentLinks.map(link => link.student.id);
  const attendance = await prisma.attendanceRecord.findMany({ where: { orgId, studentId: { in: ids }, date: { gte: window.from, lt: window.until } }, select: { studentId: true, status: true } });
  const sessions = await prisma.quranSession.findMany({ where: { orgId, studentId: { in: ids }, voidedAt: null, activity: "MEMORIZATION", observation: "INDEPENDENT" }, select: sessionFields });
  const { studentLinks, ...profile } = parent;
  return { guardian: profile, month: window.month,
    children: studentLinks.map(({ student }) => {
      const count = memorised(sessions.filter(row => row.studentId === student.id)).size;
      return { ...student, attendance: attendanceSummary(attendance.filter(row => row.studentId === student.id)),
        quran: { memorisedAyahs: count, totalAyahs, percent: Math.round(count * 1000 / totalAyahs) / 10 } };
    }), announcements: (await listParentAnnouncements(actor.orgId, actor.userId)).slice(0, 5),
  };
}

async function profile(actor: AuthenticatedUser, id: string) {
  const { parent, student } = await child(actor, id), orgId = BigInt(actor.orgId);
  const today = new Date(schoolDate());
  const enrollments = await prisma.enrollment.findMany({ where: { orgId, studentId: student.id },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 20,
    select: { id: true, academicYear: true, status: true, createdAt: true, class: { select: { name: true } } } });
  const timetable = student.classId ? await prisma.classTimetableSlot.findMany({
    where: { orgId, classId: student.classId, cancelledAt: null, validFrom: { lte: today }, validUntil: { gte: today } },
    orderBy: [{ weekday: "asc" }, { startsAt: "asc" }],
    select: { weekday: true, startsAt: true, endsAt: true, subject: true, room: true },
  }) : [];
  return { student, guardian: { fullName: parent.fullName, phone: parent.phone, email: parent.email, relationship: parent.relationship }, enrollments, timetable };
}

async function attendance(actor: AuthenticatedUser, id: string, month?: string) {
  const { student } = await child(actor, id), window = period(month);
  const records = await prisma.attendanceRecord.findMany({ where: { orgId: BigInt(actor.orgId), studentId: student.id,
    date: { gte: window.from, lt: window.until } }, orderBy: { date: "desc" },
    select: { id: true, date: true, status: true, reason: true, checkInTime: true,
      class: { select: { name: true } }, markedBy: { select: { fullName: true } } } });
  return { student, month: window.month, summary: attendanceSummary(records), records };
}

async function quran(actor: AuthenticatedUser, id: string, page: number) {
  const { student } = await child(actor, id);
  return { student, ...await readQuran(BigInt(actor.orgId), student.id, page) };
}

export const familyWorkspaceRouter = Router();
familyWorkspaceRouter.use(requireRole("PARENT"));
const handle = (fn: (req: Request) => Promise<unknown>) => asyncHandler(async (req: Request, res: Response) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: jsonRecord(await fn(req)) });
});
familyWorkspaceRouter.get("/overview", handle(req => overview(req.authUser!, monthQuery.parse(req.query).month)));
familyWorkspaceRouter.get("/children/:id/profile", handle(req => { z.object({}).strict().parse(req.query); return profile(req.authUser!, idSchema.parse(req.params.id)); }));
familyWorkspaceRouter.get("/children/:id/attendance", handle(req => attendance(req.authUser!, idSchema.parse(req.params.id), monthQuery.parse(req.query).month)));
familyWorkspaceRouter.get("/children/:id/quran", handle(req => quran(req.authUser!, idSchema.parse(req.params.id), pageQuery.parse(req.query).page)));
