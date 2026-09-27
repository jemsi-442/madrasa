import { Prisma } from "@prisma/client";
import { isDeepStrictEqual } from "node:util";
import type { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { jsonRecord } from "../../shared/utils/json-record";
import { classScope, studentScope } from "../teacher-workspace/teacher.access";
import { schoolDate } from "../attendance/register.service";
import { transitionInput } from "../assessments/assessments.schemas";
import { listQuery, periodInput, prepareInput, saveInput } from "./student-reports.schemas";

type DB = Prisma.TransactionClient;
type Actor = AuthenticatedUser;
const day = (d: Date) => d.toISOString().slice(0, 10);
async function liveAccount(db: DB, actor: Actor) {
  const user = await db.user.findFirst({ where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId),
    role: actor.role, status: "ACTIVE", organization: { status: { in: ["ACTIVE", "TRIAL"] } } } });
  if (!user) throw new HttpError(403, "Account unavailable");
  return { ...actor, branchId: user.branchId?.toString() ?? null };
}
async function staff(db: DB, actor: Actor) {
  if (!["ADMIN", "TEACHER"].includes(actor.role)) throw new HttpError(403, "Staff access required");
  return liveAccount(db, actor);
}
async function write<T>(actor: Actor, work: (db: DB, live: Actor) => Promise<T>) {
  try {
    return await prisma.$transaction(async db => {
      await db.$queryRaw`SELECT id FROM organizations WHERE id = ${BigInt(actor.orgId)} FOR UPDATE`;
      return work(db, await staff(db, actor));
    }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted, timeout: 20000 });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2003", "P2034"].includes(e.code))
      throw new HttpError(409, "Related records changed. Reload before continuing.");
    throw e;
  }
}
async function audit(db: DB, actor: Actor, id: bigint, action: string, reason?: string) {
  await db.auditLog.create({ data: { orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId),
    action: `student-report.${action}`, entityType: "StudentReport", entityId: String(id),
    metadata: reason ? { reason } : {} } });
}
const scope = (actor: Actor): Prisma.StudentReportWhereInput => ({ orgId: BigInt(actor.orgId), class: { is: classScope(actor) } });
const include = Prisma.validator<Prisma.StudentReportInclude>()({ period: true,
  class: { select: { id: true, name: true } }, student: { select: { id: true, fullName: true, admissionNo: true } },
  preparedBy: { select: { fullName: true } }, releases: { where: { retractedAt: null }, orderBy: { id: "desc" }, take: 1 },
});
type Row = Prisma.StudentReportGetPayload<{ include: typeof include }>;
async function record(db: DB, actor: Actor, id: string) {
  const row = await db.studentReport.findFirst({ where: { ...scope(actor), id: BigInt(id) }, include });
  if (!row) throw new HttpError(404, "Report not found");
  return row;
}
type AssessmentSnapshot = { title: string; assessedOn: string; maxScore: number;
  subject: { id: string; name: string }; teacher: string;
  results: { studentId: string; score: number; feedback: string }[] };
export type LearningReport = {
  school: string; period: { name: string; startsOn: string; endsOn: string };
  student: { id: string; fullName: string; admissionNo: string }; className: string; teacher: string;
  feedback: string; policy: string;
  assessments: { releaseId: string; title: string; date: string; subject: string; score: number; maxScore: number; feedback: string }[];
  attendance: { present: number; late: number; absent: number; excused: number; recorded: number; rate: number | null };
  quran: { sessions: number; memorisedAyahs: number; reading: number; revision: number; tajweed: number };
};
async function compose(db: DB, row: Pick<Row, "orgId" | "studentId" | "classId" | "period" | "student" | "class" | "preparedBy" | "feedback">): Promise<LearningReport> {
  const range = { gte: row.period.startsOn, lte: row.period.endsOn };
  const released = await db.assessmentRelease.findMany({ where: { orgId: row.orgId, retractedAt: null,
    assessment: { orgId: row.orgId, classId: row.classId, status: "PUBLISHED", assessedOn: range,
      results: { some: { orgId: row.orgId, studentId: row.studentId } } } }, orderBy: { id: "asc" } });
  const assessments = released.flatMap(r => {
    const s = r.snapshot as unknown as AssessmentSnapshot, own = s.results.find(x => x.studentId === String(row.studentId));
    return own ? [{ releaseId: String(r.id), title: s.title, date: s.assessedOn, subject: s.subject.name,
      score: own.score, maxScore: s.maxScore, feedback: own.feedback }] : [];
  });
  const attendance = { present: 0, late: 0, absent: 0, excused: 0, recorded: 0, rate: null as number | null };
  const register = await db.attendanceRecord.groupBy({ by: ["status"], where: {
    orgId: row.orgId, studentId: row.studentId, classId: row.classId, date: range }, _count: true });
  for (const r of register) {
    if (r.status === "PRESENT") attendance.present = r._count;
    if (r.status === "LATE") attendance.late = r._count;
    if (r.status === "ABSENT") attendance.absent = r._count;
    if (r.status === "EXCUSED") attendance.excused = r._count;
    attendance.recorded += r._count;
  }
  const denominator = attendance.present + attendance.late + attendance.absent;
  if (denominator) attendance.rate = Math.round((attendance.present + attendance.late) * 10000 / denominator) / 100;
  const sessions = await db.quranSession.findMany({ where: { orgId: row.orgId, studentId: row.studentId,
    classId: row.classId, learnedOn: range, voidedAt: null },
    select: { activity: true, observation: true, surahId: true, ayahFrom: true, ayahTo: true } });
  const ayahs = new Set<string>();
  for (const s of sessions.filter(s => s.activity === "MEMORIZATION" && s.observation === "INDEPENDENT"))
    for (let a = s.ayahFrom; a <= s.ayahTo; a++) ayahs.add(`${s.surahId}:${a}`);
  const school = await db.organization.findUniqueOrThrow({ where: { id: row.orgId }, select: { name: true } });
  return { school: school.name, period: { name: row.period.name, startsOn: day(row.period.startsOn), endsOn: day(row.period.endsOn) },
    student: { ...row.student, id: String(row.student.id) }, className: row.class.name, teacher: row.preparedBy.fullName,
    feedback: row.feedback, assessments, attendance,
    quran: { sessions: sessions.length, memorisedAyahs: ayahs.size,
      reading: sessions.filter(s => s.activity === "READING").length,
      revision: sessions.filter(s => s.activity === "REVISION").length,
      tajweed: sessions.filter(s => s.activity === "TAJWEED").length },
    policy: "Learning summary for this class and period, not a weighted term grade or class rank. Only published assessments are included. Late counts as present; excused and unmarked days are excluded from the attendance rate. Quran totals describe recorded sessions; unique independently memorised ayahs are not a whole-Quran completion percentage.",
  };
}
const activeRelease: Prisma.ReportReleaseWhereInput = { retractedAt: null, report: { status: "PUBLISHED" },
  sources: { every: { assessmentRelease: { retractedAt: null, assessment: { status: "PUBLISHED" } } } } };
async function detail(db: DB, row: Row) {
  const sourcesCurrent = row.status === "PUBLISHED"
    ? !!await db.reportRelease.findFirst({ where: { ...activeRelease, orgId: row.orgId, reportId: row.id } })
    : isDeepStrictEqual(row.draft, jsonRecord(await compose(db, row)));
  return { ...row, sourcesCurrent };
}
export async function options(actor: Actor) {
  const live = await staff(prisma, actor);
  return { classes: await prisma.class.findMany({ where: classScope(live), select: { id: true, name: true }, orderBy: { name: "asc" } }),
    periods: await prisma.reportingPeriod.findMany({ where: { orgId: BigInt(live.orgId) }, orderBy: [{ startsOn: "desc" }, { id: "desc" }] }) };
}
export async function roster(actor: Actor, classId: string) {
  const live = await staff(prisma, actor);
  return prisma.student.findMany({ where: { ...studentScope(live), classId: BigInt(classId) },
    select: { id: true, fullName: true, admissionNo: true }, orderBy: { fullName: "asc" }, take: 500 });
}
export async function createPeriod(actor: Actor, input: z.infer<typeof periodInput>) {
  return write(actor, async (db, live) => {
    if (live.role !== "ADMIN") throw new HttpError(403, "Only administrators set reporting periods");
    const orgId = BigInt(live.orgId);
    const previous = await db.reportingPeriod.findUnique({ where: { orgId_clientId: { orgId, clientId: input.clientId } } });
    if (previous) {
      if (previous.name !== input.name || day(previous.startsOn) !== input.startsOn || day(previous.endsOn) !== input.endsOn)
        throw new HttpError(409, "This request ID belongs to a different period");
      return previous;
    }
    const row = await db.reportingPeriod.create({ data: { ...input, orgId, createdById: BigInt(live.userId),
      startsOn: new Date(input.startsOn), endsOn: new Date(input.endsOn) } });
    await db.auditLog.create({ data: { orgId, actorUserId: BigInt(live.userId), action: "reporting-period.created",
      entityType: "ReportingPeriod", entityId: String(row.id) } });
    return row;
  });
}
export async function list(actor: Actor, query: z.infer<typeof listQuery>) {
  const live = await staff(prisma, actor);
  const where: Prisma.StudentReportWhereInput = { ...scope(live),
    ...(query.periodId ? { periodId: BigInt(query.periodId) } : {}),
    ...(query.classId ? { classId: BigInt(query.classId) } : {}), ...(query.status ? { status: query.status } : {}) };
  return { items: await prisma.studentReport.findMany({ where, orderBy: { id: "desc" }, skip: (query.page - 1) * 20, take: 20,
    select: { id: true, revision: true, status: true, period: { select: { name: true } },
      class: { select: { name: true } }, student: { select: { fullName: true, admissionNo: true } } } }),
    stats: await prisma.studentReport.groupBy({ by: ["status"], where, _count: true }),
    meta: { page: query.page, pageSize: 20, totalItems: await prisma.studentReport.count({ where }) } };
}
export async function get(actor: Actor, id: string) { return detail(prisma, await record(prisma, await staff(prisma, actor), id)); }
export async function prepare(actor: Actor, input: z.infer<typeof prepareInput>) {
  return write(actor, async (db, live) => {
    if (live.role !== "TEACHER") throw new HttpError(403, "The assigned teacher prepares reports");
    const orgId = BigInt(live.orgId);
    const student = await db.student.findFirst({ where: { ...studentScope(live), id: BigInt(input.studentId) },
      include: { currentClass: true } });
    if (!student?.currentClass) throw new HttpError(404, "Assigned student not found");
    const period = await db.reportingPeriod.findFirst({ where: { orgId, id: BigInt(input.periodId) } });
    if (!period) throw new HttpError(404, "Reporting period not found");
    const previous = await db.studentReport.findUnique({ where: { periodId_studentId: { periodId: period.id, studentId: student.id } } });
    if (previous) return detail(db, await record(db, live, String(previous.id)));
    const teacher = await db.user.findUniqueOrThrow({ where: { id: BigInt(live.userId) } });
    const draft = await compose(db, { orgId, studentId: student.id, classId: student.currentClass.id, period,
      student: { id: student.id, fullName: student.fullName, admissionNo: student.admissionNo },
      class: student.currentClass, preparedBy: teacher, feedback: "" });
    const row = await db.studentReport.create({ data: { orgId, periodId: period.id, studentId: student.id,
      classId: student.currentClass.id, preparedById: teacher.id, draft: draft as unknown as Prisma.InputJsonValue }, include });
    await audit(db, live, row.id, "prepared");
    return detail(db, row);
  });
}
export async function save(actor: Actor, id: string, input: z.infer<typeof saveInput>) {
  return write(actor, async (db, live) => {
    if (live.role !== "TEACHER") throw new HttpError(403, "Only the assigned teacher edits reports");
    const row = await record(db, live, id);
    if (row.status !== "DRAFT" || row.revision !== input.revision) throw new HttpError(409, "Reopen the latest draft before saving");
    const teacher = await db.user.findUniqueOrThrow({ where: { id: BigInt(live.userId) } });
    const draft = await compose(db, { ...row, feedback: input.feedback, preparedBy: teacher });
    const updated = await db.studentReport.update({ where: { id: row.id }, data: { feedback: input.feedback,
      preparedById: teacher.id, draft: draft as unknown as Prisma.InputJsonValue, revision: { increment: 1 } }, include });
    await audit(db, live, row.id, "saved");
    return detail(db, updated);
  });
}
export async function transition(actor: Actor, id: string, input: z.infer<typeof transitionInput>) {
  return write(actor, async (db, live) => {
    const row = await record(db, live, id), { action } = input;
    if (action === "submit" ? live.role !== "TEACHER" : live.role !== "ADMIN") throw new HttpError(403, "Action not permitted");
    if (row.revision !== input.revision || row.status !== (action === "submit" ? "DRAFT" : action === "retract" ? "PUBLISHED" : "SUBMITTED"))
      throw new HttpError(409, "Report changed. Reopen it before continuing.");
    if (["submit", "publish"].includes(action)) {
      if (day(row.period.endsOn) > schoolDate()) throw new HttpError(422, "Wait until the reporting period has ended");
      const draft = await compose(db, row);
      if (!isDeepStrictEqual(row.draft, jsonRecord(draft))) throw new HttpError(409, "Source records changed. The teacher must refresh and resubmit this draft.");
      if (!row.feedback.trim() || !(draft.assessments.length || draft.attendance.recorded || draft.quran.sessions))
        throw new HttpError(422, "Add teacher feedback and at least one recorded learning or attendance record");
    }
    if (action === "publish") {
      const release = await db.reportRelease.create({ data: { orgId: row.orgId, reportId: row.id,
        revision: row.revision + 1, publishedById: BigInt(live.userId), snapshot: row.draft as Prisma.InputJsonValue } });
      const snapshot = row.draft as unknown as LearningReport;
      await db.reportAssessmentSource.createMany({ data: snapshot.assessments.map(a => ({ orgId: row.orgId,
        reportReleaseId: release.id, assessmentReleaseId: BigInt(a.releaseId) })) });
    }
    if (action === "retract") await db.reportRelease.updateMany({ where: { orgId: row.orgId, reportId: row.id, retractedAt: null },
      data: { retractedAt: new Date(), retractionReason: input.reason! } });
    const updated = await db.studentReport.update({ where: { id: row.id }, data: {
      status: action === "submit" ? "SUBMITTED" : action === "publish" ? "PUBLISHED" : "DRAFT",
      revision: { increment: 1 }, reviewNote: input.reason ?? null }, include });
    await audit(db, live, row.id, action, input.reason);
    return detail(db, updated);
  });
}
async function child(actor: Actor, id: string) {
  if (actor.role !== "PARENT") throw new HttpError(403, "Parent access required");
  await liveAccount(prisma, actor);
  const orgId = BigInt(actor.orgId);
  const student = await prisma.student.findFirst({ where: { id: BigInt(id), orgId,
    guardians: { some: { orgId, guardian: { orgId, userId: BigInt(actor.userId) } } } }, select: { id: true, fullName: true } });
  if (!student) throw new HttpError(404, "Child not found");
  return student;
}
export async function parentList(actor: Actor, id: string, page: number) {
  const student = await child(actor, id);
  const where: Prisma.ReportReleaseWhereInput = { ...activeRelease, orgId: BigInt(actor.orgId),
    report: { orgId: BigInt(actor.orgId), studentId: student.id, status: "PUBLISHED" } };
  return { student, items: await prisma.reportRelease.findMany({ where, orderBy: { id: "desc" }, take: 20, skip: (page - 1) * 20,
    select: { id: true, createdAt: true, snapshot: true } }),
    meta: { page, pageSize: 20, totalItems: await prisma.reportRelease.count({ where }) } };
}
export async function parentRelease(actor: Actor, studentId: string, id: string) {
  await child(actor, studentId);
  const row = await prisma.reportRelease.findFirst({ where: { ...activeRelease, id: BigInt(id), orgId: BigInt(actor.orgId),
    report: { orgId: BigInt(actor.orgId), studentId: BigInt(studentId), status: "PUBLISHED" } }, select: { id: true, createdAt: true, snapshot: true } });
  if (!row) throw new HttpError(404, "Published report not found");
  return row;
}
