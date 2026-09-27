import { Prisma } from "@prisma/client";
import type { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { jsonRecord } from "../../shared/utils/json-record";
import { schoolDate } from "../attendance/register.service";
import { classScope } from "../teacher-workspace/teacher.access";
import { createAssessmentInput, resultsInput, transitionInput, assessmentQuery } from "./assessments.schemas";

type DB = Prisma.TransactionClient;
async function staff(db: DB, actor: AuthenticatedUser) {
  if (!["ADMIN", "TEACHER"].includes(actor.role)) throw new HttpError(403, "Staff access required");
  const user = await db.user.findFirst({ where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId),
    role: actor.role, status: "ACTIVE", organization: { status: { in: ["ACTIVE", "TRIAL"] } } } });
  if (!user) throw new HttpError(403, "Account unavailable");
  return { ...actor, branchId: user.branchId?.toString() ?? null };
}
const scope = (actor: AuthenticatedUser): Prisma.AssessmentWhereInput => ({
  orgId: BigInt(actor.orgId), class: { is: classScope(actor) },
});
const details = Prisma.validator<Prisma.AssessmentInclude>()({
  class: { select: { id: true, name: true } },
  subject: { select: { id: true, name: true } },
  createdBy: { select: { fullName: true } },
  results: { orderBy: { studentId: "asc" }, include: {
    student: { select: { id: true, fullName: true, admissionNo: true } },
  } },
});
async function record(db: DB, actor: AuthenticatedUser, id: string) {
  const row = await db.assessment.findFirst({ where: { ...scope(actor), id: BigInt(id) }, include: details });
  if (!row) throw new HttpError(404, "Assessment not found");
  return row;
}
async function write<T>(actor: AuthenticatedUser, fn: (db: DB, live: AuthenticatedUser) => Promise<T>) {
  try {
    return await prisma.$transaction(async db => {
      // School writers share this lock: roster/class changes cannot race publication.
      await db.$queryRaw`SELECT id FROM organizations WHERE id = ${BigInt(actor.orgId)} FOR UPDATE`;
      return fn(db, await staff(db, actor));
    }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted, timeout: 20000 });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2003", "P2034"].includes(e.code))
      throw new HttpError(409, "Related data changed. Reload before trying again.");
    throw e;
  }
}
async function audit(db: DB, actor: AuthenticatedUser, id: bigint, action: string, revision: number, reason?: string) {
  await db.auditLog.create({ data: { orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId),
    action: `assessment.${action}`, entityType: "Assessment", entityId: String(id),
    metadata: { revision, ...(reason ? { reason } : {}) } } });
}
export async function assessmentOptions(actor: AuthenticatedUser) {
  const live = await staff(prisma, actor), orgId = BigInt(actor.orgId);
  return {
    classes: await prisma.class.findMany({ where: classScope(live), select: { id: true, name: true }, orderBy: { name: "asc" } }),
    subjects: await prisma.subject.findMany({ where: { orgId, isActive: true }, select: { id: true, name: true }, orderBy: { name: "asc" } }),
  };
}
export async function listAssessments(actor: AuthenticatedUser, query: z.infer<typeof assessmentQuery>) {
  const live = await staff(prisma, actor);
  const where: Prisma.AssessmentWhereInput = { ...scope(live),
    ...(query.classId ? { classId: BigInt(query.classId) } : {}), ...(query.status ? { status: query.status } : {}) };
  return { items: await prisma.assessment.findMany({ where, orderBy: [{ assessedOn: "desc" }, { id: "desc" }],
    skip: (query.page - 1) * 20, take: 20,
    include: { class: { select: { name: true } }, subject: { select: { name: true } }, _count: { select: { results: true } } } }),
    meta: { page: query.page, totalItems: await prisma.assessment.count({ where }), pageSize: 20 } };
}
export async function assessmentDetail(actor: AuthenticatedUser, id: string) {
  return record(prisma, await staff(prisma, actor), id);
}
export async function createAssessment(actor: AuthenticatedUser, input: z.infer<typeof createAssessmentInput>) {
  return write(actor, async (db, live) => {
    if (live.role !== "TEACHER") throw new HttpError(403, "The assigned teacher creates assessments");
    const orgId = BigInt(live.orgId);
    const group = await db.class.findFirst({ where: { ...classScope(live), id: BigInt(input.classId) } });
    if (!group) throw new HttpError(404, "Assigned class not found");
    const previous = await db.assessment.findUnique({ where: {
      orgId_createdById_clientId: { orgId, createdById: BigInt(live.userId), clientId: input.clientId },
    } });
    if (previous) {
      if (String(previous.classId) !== input.classId || String(previous.subjectId) !== input.subjectId ||
          previous.title !== input.title || previous.maxScore !== input.maxScore ||
          previous.assessedOn.toISOString().slice(0, 10) !== input.assessedOn)
        throw new HttpError(409, "This request ID was already used for another assessment");
      return record(db, live, String(previous.id));
    }
    if (input.assessedOn > schoolDate()) throw new HttpError(422, "Assessment date cannot be in the future");
    if (!await db.subject.findFirst({ where: { id: BigInt(input.subjectId), orgId, isActive: true } }))
      throw new HttpError(422, "Choose an active school subject");
    const students = await db.student.findMany({ where: { orgId, classId: group.id, status: "ACTIVE" }, select: { id: true }, take: 501 });
    if (!students.length || students.length > 500) throw new HttpError(422, "A class must have between 1 and 500 active learners");
    const row = await db.assessment.create({ data: { orgId, classId: group.id, subjectId: BigInt(input.subjectId),
      createdById: BigInt(live.userId), clientId: input.clientId, title: input.title,
      assessedOn: new Date(input.assessedOn), maxScore: input.maxScore,
    } });
    await db.assessmentResult.createMany({ data: students.map(s => ({ orgId, assessmentId: row.id, studentId: s.id })) });
    await audit(db, live, row.id, "created", row.revision);
    return record(db, live, String(row.id));
  });
}
export async function saveAssessment(actor: AuthenticatedUser, id: string, input: z.infer<typeof resultsInput>) {
  return write(actor, async (db, live) => {
    if (live.role !== "TEACHER") throw new HttpError(403, "Only the assigned teacher records marks");
    const row = await record(db, live, id);
    if (row.revision !== input.revision) throw new HttpError(409, "This assessment changed. Reopen it before saving.");
    if (row.status !== "DRAFT") throw new HttpError(409, "Only drafts can be edited");
    const roster = new Set(row.results.map(r => String(r.studentId)));
    if (input.results.length !== roster.size || input.results.some(r => !roster.has(r.studentId)))
      throw new HttpError(422, "Save the complete original assessment roster");
    if (input.results.some(r => r.score !== null && r.score > row.maxScore))
      throw new HttpError(422, "A score cannot exceed the assessment maximum");
    for (const result of input.results) await db.assessmentResult.update({
      where: { assessmentId_studentId: { assessmentId: row.id, studentId: BigInt(result.studentId) } },
      data: { score: result.score, feedback: result.feedback },
    });
    await db.assessment.update({ where: { id: row.id }, data: { revision: { increment: 1 } } });
    await audit(db, live, row.id, "saved", row.revision + 1);
    return record(db, live, id);
  });
}
export async function transitionAssessment(actor: AuthenticatedUser, id: string, input: z.infer<typeof transitionInput>) {
  return write(actor, async (db, live) => {
    const row = await record(db, live, id), { action } = input;
    if (row.revision !== input.revision) throw new HttpError(409, "This assessment changed. Reopen it before continuing.");
    if (action === "submit" ? live.role !== "TEACHER" : live.role !== "ADMIN")
      throw new HttpError(403, "This action is not permitted for your role");
    const expected = action === "submit" ? "DRAFT" : action === "retract" ? "PUBLISHED" : "SUBMITTED";
    if (row.status !== expected) throw new HttpError(409, "This action is not available in the current state");
    if (["submit", "publish"].includes(action) && (!row.results.length || row.results.some(r => r.score === null)))
      throw new HttpError(422, "Record a score for every learner before submitting or publishing");
    if (action === "publish") {
      const snapshot = { title: row.title, assessedOn: row.assessedOn.toISOString().slice(0, 10),
        subject: row.subject, class: row.class, maxScore: row.maxScore,
        teacher: row.createdBy.fullName,
        results: row.results.map(r => ({ studentId: String(r.studentId), studentName: r.student.fullName,
          score: r.score, feedback: r.feedback })),
      };
      await db.assessmentRelease.create({ data: { orgId: row.orgId, assessmentId: row.id,
        revision: row.revision + 1, publishedById: BigInt(live.userId),
        snapshot: jsonRecord(snapshot) as Prisma.InputJsonValue } });
    }
    if (action === "retract") await db.assessmentRelease.updateMany({
      where: { assessmentId: row.id, orgId: row.orgId, retractedAt: null },
      data: { retractedAt: new Date(), retractionReason: input.reason! },
    });
    await db.assessment.update({ where: { id: row.id }, data: {
      status: action === "submit" ? "SUBMITTED" : action === "publish" ? "PUBLISHED" : "DRAFT",
      revision: { increment: 1 }, reviewNote: input.reason ?? null,
    } });
    await audit(db, live, row.id, action, row.revision + 1, input.reason);
    return record(db, live, id);
  });
}

type Snapshot = { title: string; assessedOn: string; subject: { id: string; name: string };
  class: { id: string; name: string }; maxScore: number; teacher: string;
  results: { studentId: string; studentName: string; score: number; feedback: string }[] };
export async function parentAcademics(actor: AuthenticatedUser, id: string, year: number) {
  if (actor.role !== "PARENT") throw new HttpError(403, "Parent account required");
  const orgId = BigInt(actor.orgId);
  const student = await prisma.student.findFirst({ where: { id: BigInt(id), orgId,
    guardians: { some: { orgId, guardian: { orgId, userId: BigInt(actor.userId),
      user: { orgId, role: "PARENT", status: "ACTIVE", organization: { status: { in: ["ACTIVE", "TRIAL"] } } } } } },
  }, select: { id: true, fullName: true, admissionNo: true } });
  if (!student) throw new HttpError(404, "Child not found");
  return readPublishedAcademics(orgId, student, year);
}

// Called only after the parent or learner student scope has been authorized.
export async function readPublishedAcademics(orgId: bigint, student: { id: bigint; fullName: string; admissionNo: string }, year: number) {
  const id = String(student.id);
  const releases = await prisma.assessmentRelease.findMany({ where: { orgId, retractedAt: null,
    assessment: { orgId, status: "PUBLISHED", assessedOn: { gte: new Date(Date.UTC(year, 0, 1)), lt: new Date(Date.UTC(year + 1, 0, 1)) },
      results: { some: { orgId, studentId: student.id } } } },
    select: { id: true, snapshot: true, createdAt: true }, orderBy: [{ createdAt: "desc" }, { id: "desc" }],
  });
  const records = releases.flatMap(release => {
    const snapshot = release.snapshot as unknown as Snapshot;
    const own = snapshot.results.find(r => r.studentId === id);
    if (!own) return [];
    // Never serialize the full snapshot: it contains other children's marks.
    return [{ id: release.id, publishedAt: release.createdAt, title: snapshot.title,
      assessedOn: snapshot.assessedOn, subject: snapshot.subject, class: snapshot.class,
      teacher: snapshot.teacher, score: own.score, maxScore: snapshot.maxScore,
      percent: Math.round(own.score * 10000 / snapshot.maxScore) / 100, feedback: own.feedback }];
  });
  const mean = (items: typeof records) => items.length ? Math.round(items.reduce((s, r) => s + r.score * 100 / r.maxScore, 0) / items.length * 100) / 100 : null;
  const subjects = [...new Set(records.map(r => r.subject.id))].map(subjectId => {
    const items = records.filter(r => r.subject.id === subjectId);
    return { ...items[0]!.subject, average: mean(items), assessments: items.length };
  });
  return { student, year, records, subjects, average: mean(records),
    policy: "Each published assessment contributes equally after converting its score to a percentage. This is not a term grade or class rank." };
}
