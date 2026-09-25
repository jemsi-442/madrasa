import { createHash } from "node:crypto";
import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import { jsonRecord } from "../../shared/utils/json-record";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { attendanceConflict, schoolDate } from "../attendance/register.service";
import { assignedStudent, classScope, studentScope } from "./teacher.access";
import type { DirectoryQuery, SessionInput, SessionQuery, SupportInput } from "./teacher.schemas";
import catalog from "./quran-catalog.json";

const writeConflict = (error: unknown): never => {
  if (attendanceConflict(error)) throw new HttpError(409, "The record changed while saving. Reload and check the saved records.");
  throw error;
};

const pageMeta = (page: number, size: number, total: number) =>
  ({ page, pageSize: size, totalItems: total, totalPages: Math.ceil(total / size) });
const sessionFields = {
  id: true, surahId: true, ayahFrom: true, ayahTo: true, learnedOn: true, createdAt: true,
  activity: true, observation: true, note: true, voidedAt: true, voidReason: true,
  teacherId: true, teacher: { select: { fullName: true } },
} satisfies Prisma.QuranSessionSelect;
const studentFields = {
  id: true, fullName: true, admissionNo: true, status: true, classId: true,
  currentClass: { select: { name: true } },
  quranSessions: { where: { voidedAt: null }, orderBy: [{ learnedOn: "desc" }, { id: "desc" }],
    take: 1, select: sessionFields },
  supportNotes: { where: { resolvedAt: null }, orderBy: { id: "desc" }, take: 1,
    select: { id: true, note: true, createdAt: true } },
} satisfies Prisma.StudentSelect;

export const teacherClasses = async (actor: AuthenticatedUser) => {
  const today = new Date(schoolDate());
  return jsonRecord(await prisma.class.findMany({
    where: classScope(actor), orderBy: [{ name: "asc" }, { id: "asc" }],
    select: { id: true, name: true, level: true, academicYear: true,
      branch: { select: { name: true } },
      _count: { select: { currentStudents: { where: { status: "ACTIVE", orgId: BigInt(actor.orgId) } } } },
      timetable: { where: { cancelledAt: null, validFrom: { lte: today }, validUntil: { gte: today } },
        orderBy: [{ weekday: "asc" }, { startsAt: "asc" }], select: {
          id: true, weekday: true, startsAt: true, endsAt: true, subject: true,
          focus: true, room: true, validFrom: true, validUntil: true,
        } },
    },
  }));
};

export const teacherStudents = async (actor: AuthenticatedUser, query: DirectoryQuery) => {
  const where: Prisma.StudentWhereInput = {
    ...studentScope(actor),
    ...(query.classId ? { classId: BigInt(query.classId) } : {}),
    ...(query.search ? { OR: [{ fullName: { contains: query.search } }, { admissionNo: { contains: query.search } }] } : {}),
    ...(query.support === "open" ? { supportNotes: { some: { resolvedAt: null } } } : {}),
  };
  const [total, items] = await prisma.$transaction([
    prisma.student.count({ where }),
    prisma.student.findMany({ where, select: studentFields, orderBy: [{ fullName: "asc" }, { id: "asc" }],
      skip: (query.page - 1) * query.pageSize, take: query.pageSize }),
  ]);
  return jsonRecord({ items, meta: pageMeta(query.page, query.pageSize, total) });
};

export const teacherOverview = async (actor: AuthenticatedUser) => {
  const where = studentScope(actor);
  const date = schoolDate();
  const classes = await teacherClasses(actor);
  const students = await prisma.student.count({ where });
  const followUpCount = await prisma.student.count({ where: { ...where, supportNotes: { some: { resolvedAt: null } } } });
  const followUps = await prisma.student.findMany({ where: { ...where, supportNotes: { some: { resolvedAt: null } } },
    select: studentFields, take: 5, orderBy: [{ fullName: "asc" }, { id: "asc" }] });
  const sessionsToday = await prisma.quranSession.count({ where: {
    orgId: BigInt(actor.orgId), teacherId: BigInt(actor.userId), learnedOn: new Date(date),
    voidedAt: null, student: { is: where },
  } });
  const recentSessions = await prisma.quranSession.findMany({ where: {
    orgId: BigInt(actor.orgId), voidedAt: null, student: { is: where },
  }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 5,
  select: { ...sessionFields, student: { select: { id: true, fullName: true, classId: true } } } });
  return jsonRecord({ date, classes, students, followUpCount, followUps, sessionsToday, recentSessions });
};

export const teacherStudentProfile = async (actor: AuthenticatedUser, studentId: string) => {
  const student = await assignedStudent(prisma, actor, studentId);
  const orgId = BigInt(actor.orgId);
  const supportNotes = await prisma.studentSupportNote.findMany({
    where: { orgId, studentId: student.id }, take: 50, orderBy: [{ resolvedAt: "asc" }, { id: "desc" }],
    select: { id: true, note: true, createdAt: true, resolvedAt: true,
      createdBy: { select: { fullName: true } }, resolvedBy: { select: { fullName: true } } },
  });
  const sessions = await prisma.quranSession.findMany({
    where: { orgId, studentId: student.id }, orderBy: [{ learnedOn: "desc" }, { id: "desc" }],
    take: 20, select: sessionFields,
  });
  return jsonRecord({ student, supportNotes, sessions });
};

export const studentQuran = async (actor: AuthenticatedUser, query: SessionQuery) => {
  const student = await assignedStudent(prisma, actor, query.studentId);
  const where = { orgId: BigInt(actor.orgId), studentId: student.id, surahId: query.surahId };
  const ranges = await prisma.quranSession.findMany({
    where: { ...where, activity: "MEMORIZATION", observation: "INDEPENDENT", voidedAt: null },
    select: { ayahFrom: true, ayahTo: true },
  });
  const memorised = new Set<number>();
  for (const range of ranges) for (let ayah = range.ayahFrom; ayah <= range.ayahTo; ayah++) memorised.add(ayah);
  const [total, sessions] = await prisma.$transaction([
    prisma.quranSession.count({ where }),
    prisma.quranSession.findMany({ where, orderBy: [{ learnedOn: "desc" }, { id: "desc" }],
      skip: (query.page - 1) * 10, take: 10, select: sessionFields }),
  ]);
  return jsonRecord({ student, chapter: catalog.chapters[query.surahId - 1],
    memorisedAyahs: [...memorised].sort((a, b) => a - b), sessions,
    meta: pageMeta(query.page, 10, total) });
};

export const saveQuran = async (actor: AuthenticatedUser, input: SessionInput) => {
  if (input.learnedOn > schoolDate()) throw new HttpError(422, "Choose today or an earlier date");
  const orgId = BigInt(actor.orgId), teacherId = BigInt(actor.userId);
  const requestHash = createHash("sha256").update(JSON.stringify(input)).digest("hex");
  return prisma.$transaction(async tx => {
    const student = await assignedStudent(tx, actor, input.studentId, true);
    if (String(student.classId) !== input.classId) throw new HttpError(409, "The student has moved class. Reload before saving.");
    if (student.joinedOn && new Date(input.learnedOn) < student.joinedOn)
      throw new HttpError(422, "The session date is before the student joined");
    const existing = await tx.quranSession.findUnique({
      where: { orgId_teacherId_clientId: { orgId, teacherId, clientId: input.clientId } },
    });
    if (existing) {
      if (existing.requestHash !== requestHash) throw new HttpError(409, "This save was already used for different details");
      return jsonRecord(existing);
    }
    const saved = await tx.quranSession.create({ data: {
      ...input, studentId: student.id, classId: student.classId!, orgId, teacherId,
      learnedOn: new Date(input.learnedOn), note: input.note || null, requestHash,
    } });
    await tx.auditLog.create({ data: { orgId, actorUserId: teacherId, action: "quran.session.recorded",
      entityType: "QuranSession", entityId: String(saved.id),
      metadata: { studentId: input.studentId, classId: input.classId, clientId: input.clientId } } });
    return jsonRecord(saved);
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }).catch(writeConflict);
};

export const voidQuran = async (actor: AuthenticatedUser, id: string, reason: string) =>
  prisma.$transaction(async tx => {
    const orgId = BigInt(actor.orgId);
    const session = await tx.quranSession.findFirst({ where: { id: BigInt(id), orgId, teacherId: BigInt(actor.userId) } });
    if (!session) throw new HttpError(404, "Learning session not found");
    await assignedStudent(tx, actor, String(session.studentId), true);
    const result = await tx.quranSession.updateMany({ where: { id: session.id, orgId, voidedAt: null },
      data: { voidedAt: new Date(), voidReason: reason } });
    if (result.count) await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
      action: "quran.session.voided", entityType: "QuranSession", entityId: id, metadata: { reason } } });
    return { voided: true };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }).catch(writeConflict);

export const addSupport = async (actor: AuthenticatedUser, input: SupportInput) =>
  prisma.$transaction(async tx => {
    const student = await assignedStudent(tx, actor, input.studentId, true);
    if (String(student.classId) !== input.classId) throw new HttpError(409, "The student has moved class. Reload before saving.");
    const orgId = BigInt(actor.orgId), createdById = BigInt(actor.userId);
    const existing = await tx.studentSupportNote.findUnique({
      where: { orgId_createdById_clientId: { orgId, createdById, clientId: input.clientId } },
    });
    if (existing) {
      if (existing.note !== input.note || existing.studentId !== student.id || String(existing.classId) !== input.classId)
        throw new HttpError(409, "This save was already used for different details");
      return jsonRecord(existing);
    }
    const saved = await tx.studentSupportNote.create({ data: {
      ...input, orgId, createdById, studentId: student.id, classId: student.classId!,
    } });
    await tx.auditLog.create({ data: { orgId, actorUserId: createdById, action: "student.support.created",
      entityType: "StudentSupportNote", entityId: String(saved.id), metadata: { studentId: input.studentId } } });
    return jsonRecord(saved);
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }).catch(writeConflict);

export const resolveSupport = async (actor: AuthenticatedUser, id: string) =>
  prisma.$transaction(async tx => {
    const orgId = BigInt(actor.orgId);
    const note = await tx.studentSupportNote.findFirst({ where: { orgId, id: BigInt(id) } });
    if (!note) throw new HttpError(404, "Follow-up not found");
    await assignedStudent(tx, actor, String(note.studentId), true);
    const result = await tx.studentSupportNote.updateMany({ where: { id: note.id, orgId, resolvedAt: null },
      data: { resolvedAt: new Date(), resolvedById: BigInt(actor.userId) } });
    if (result.count) await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
      action: "student.support.resolved", entityType: "StudentSupportNote", entityId: id } });
    return { resolved: true };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }).catch(writeConflict);
