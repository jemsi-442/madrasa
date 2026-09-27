import { Router, type Request, type Response } from "express";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import { schoolDate } from "../attendance/register.service";
import { academicQuery } from "../assessments/assessments.schemas";
import { readPublishedAcademics } from "../assessments/assessments.service";
import { pageQuery, reportId } from "../student-reports/student-reports.schemas";
import { readPublishedReports, readPublishedReport, type LearningReport } from "../student-reports/student-reports.service";
import { reportPdf } from "../student-reports/report-pdf";
import { loadLearnerStudent, listLearnerAnnouncements } from "./learner.service";
import { attendanceSummary, readQuran } from "./learner-records";

const emptyQuery = z.object({}).strict();
const monthQuery = z.object({ month: z.string().regex(/^(20\d{2}|2100)-(0[1-9]|1[0-2])$/).optional() }).strict();
const date = z.string().regex(/^20\d{2}-\d{2}-\d{2}$/).refine(v => {
  const parsed = new Date(v);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === v;
});
const weekQuery = z.object({ date: date.optional() }).strict();
type Student = Awaited<ReturnType<typeof self>>;

async function self(actor: AuthenticatedUser) {
  const student = await loadLearnerStudent(actor);
  return { id: student.id, fullName: student.fullName, admissionNo: student.admissionNo,
    currentClass: student.currentClass, branch: student.branch, programCategory: student.programCategory };
}
async function attendance(actor: AuthenticatedUser, student: Student, month = schoolDate().slice(0, 7)) {
  const [year, number] = month.split("-").map(Number);
  const records = await prisma.attendanceRecord.findMany({ where: { orgId: BigInt(actor.orgId), studentId: student.id,
    date: { gte: new Date(Date.UTC(year!, number! - 1, 1)), lt: new Date(Date.UTC(year!, number!, 1)) } },
    orderBy: { date: "desc" }, select: { id: true, date: true, status: true, reason: true, checkInTime: true,
      class: { select: { name: true } } } });
  return { month, summary: attendanceSummary(records), records };
}
async function timetable(actor: AuthenticatedUser, student: Student, day = schoolDate()) {
  const start = new Date(day);
  start.setUTCDate(start.getUTCDate() - ((start.getUTCDay() + 6) % 7));
  const end = new Date(start); end.setUTCDate(end.getUTCDate() + 6);
  const slots = student.currentClass ? await prisma.classTimetableSlot.findMany({
    where: { orgId: BigInt(actor.orgId), classId: student.currentClass.id, cancelledAt: null,
      validFrom: { lte: end }, validUntil: { gte: start } },
    orderBy: [{ weekday: "asc" }, { startsAt: "asc" }],
    select: { id: true, weekday: true, startsAt: true, endsAt: true, validFrom: true, validUntil: true,
      subject: true, room: true },
  }) : [];
  const sessions = slots.flatMap(slot => {
    const occurrence = new Date(start); occurrence.setUTCDate(start.getUTCDate() + slot.weekday - 1);
    if (occurrence < slot.validFrom || occurrence > slot.validUntil) return [];
    const { validFrom: _from, validUntil: _until, ...safe } = slot;
    return [{ ...safe, date: occurrence.toISOString().slice(0, 10) }];
  });
  return { student, today: schoolDate(), weekStart: start.toISOString().slice(0, 10),
    weekEnd: end.toISOString().slice(0, 10), sessions };
}

export const learnerWorkspaceRouter = Router();
learnerWorkspaceRouter.use(requireActiveSchoolAccount);
const handle = (fn: (req: Request) => Promise<unknown>) => asyncHandler(async (req: Request, res: Response) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ success: true, data: jsonRecord(await fn(req)) });
});
learnerWorkspaceRouter.get("/overview", handle(async req => {
  emptyQuery.parse(req.query);
  const actor = req.authUser!, student = await self(actor), orgId = BigInt(actor.orgId);
  const register = await attendance(actor, student);
  const quran = await readQuran(orgId, student.id, 1);
  const academics = await readPublishedAcademics(orgId, student, Number(schoolDate().slice(0, 4)));
  const schedule = await timetable(actor, student);
  const reports = await readPublishedReports(orgId, student, 1);
  return { student, today: schedule.today, month: register.month, attendance: register.summary,
    quran: { memorisedAyahs: quran.memorisedAyahs, totalAyahs: quran.totalAyahs, percent: quran.percent },
    academics: { average: academics.average, subjects: academics.subjects, year: academics.year },
    sessions: schedule.sessions.filter(s => s.date === schedule.today),
    latestReport: reports.items[0] ?? null, announcements: (await listLearnerAnnouncements(actor)).slice(0, 5) };
}));
learnerWorkspaceRouter.get("/classes", handle(async req => {
  const query = weekQuery.parse(req.query);
  return timetable(req.authUser!, await self(req.authUser!), query.date);
}));
learnerWorkspaceRouter.get("/attendance", handle(async req => {
  const query = monthQuery.parse(req.query);
  return attendance(req.authUser!, await self(req.authUser!), query.month);
}));
learnerWorkspaceRouter.get("/quran", handle(async req => {
  const query = pageQuery.parse(req.query), student = await self(req.authUser!);
  return readQuran(BigInt(req.authUser!.orgId), student.id, query.page);
}));
learnerWorkspaceRouter.get("/academic", handle(async req => {
  const query = academicQuery.parse(req.query), student = await self(req.authUser!);
  return readPublishedAcademics(BigInt(req.authUser!.orgId), student, query.year);
}));
learnerWorkspaceRouter.get("/reports", handle(async req => {
  const query = pageQuery.parse(req.query), student = await self(req.authUser!);
  return readPublishedReports(BigInt(req.authUser!.orgId), student, query.page);
}));
learnerWorkspaceRouter.get("/reports/:id/pdf", handle(async req => {
  emptyQuery.parse(req.query);
  const id = reportId.parse(req.params.id), student = await self(req.authUser!);
  const row = await readPublishedReport(BigInt(req.authUser!.orgId), student.id, id);
  const pdf = await reportPdf(row.snapshot as unknown as LearningReport, `R-${row.id}`, row.createdAt);
  return { fileName: `learning-report-${row.id}.pdf`, contentType: "application/pdf", base64: pdf.toString("base64") };
}));
