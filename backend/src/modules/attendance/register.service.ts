import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { jsonRecord } from "../../shared/utils/json-record";
import type { RegisterQuery, RegisterSave } from "./register.schemas";

export const attendanceConflict = (error: unknown) =>
  (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code)) ||
  (error instanceof Prisma.PrismaClientUnknownRequestError && /MysqlError \{ code: 1020,/.test(error.message));

export const schoolDate = (now = new Date()) =>
  new Date(now.getTime() + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);

const authorizedClass = async (
  tx: Prisma.TransactionClient, actor: AuthenticatedUser, classId: string,
) => {
  if (actor.role !== "ADMIN" && actor.role !== "TEACHER") throw new HttpError(403, "Not permitted");
  const record = await tx.class.findFirst({
    where: { id: BigInt(classId), orgId: BigInt(actor.orgId),
      ...(actor.role === "TEACHER" ? { teacherId: BigInt(actor.userId) } : {}) },
    select: { id: true, branchId: true, name: true, academicYear: true,
      teacher: { select: { id: true, fullName: true } } },
  });
  if (!record) throw new HttpError(404, "Class not found");
  return record;
};

const attendanceFields = {
  id: true, classId: true, status: true, reason: true, checkInTime: true,
  version: true, updatedAt: true, markedBy: { select: { fullName: true } },
} satisfies Prisma.AttendanceRecordSelect;

export const getRegister = async (actor: AuthenticatedUser, query: RegisterQuery) =>
  prisma.$transaction(async (tx) => {
    const group = await authorizedClass(tx, actor, query.classId);
    const orgId = BigInt(actor.orgId), date = new Date(query.date);
    const students = await tx.student.findMany({
      where: { orgId, OR: [
        { classId: group.id, status: "ACTIVE", OR: [{ joinedOn: null }, { joinedOn: { lte: date } }] },
        { attendance: { some: { orgId, classId: group.id, date } } },
      ] },
      orderBy: [{ fullName: "asc" }, { id: "asc" }],
      select: { id: true, fullName: true, admissionNo: true, classId: true, status: true,
        attendance: { where: { orgId, date }, select: attendanceFields } },
    });
    const items = students.map(student => {
      const saved = student.attendance[0];
      const otherClass = saved != null && saved.classId !== group.id;
      const current = student.classId === group.id && student.status === "ACTIVE";
      return {
        id: student.id, fullName: student.fullName, admissionNo: student.admissionNo,
        current, editable: !otherClass && (current || actor.role === "ADMIN"),
        recordedElsewhere: otherClass,
        attendance: otherClass || !saved ? null : saved,
      };
    });
    const records = await tx.attendanceRecord.findMany({
      where: { orgId, classId: group.id, date: {
        gte: new Date(date.getTime() - 6 * 86400000), lte: date,
      } }, select: { date: true, status: true },
    });
    const counts = (rows: { status: string }[]) => ({
      present: rows.filter(r => r.status === "PRESENT").length,
      absent: rows.filter(r => r.status === "ABSENT").length,
      late: rows.filter(r => r.status === "LATE").length,
      excused: rows.filter(r => r.status === "EXCUSED").length,
      total: rows.length,
    });
    const summary = counts(records.filter(r => r.date.getTime() === date.getTime()));
    const timeline = Array.from({ length: 7 }, (_, index) => {
      const day = new Date(date.getTime() - (6 - index) * 86400000).toISOString().slice(0, 10);
      return { date: day, ...counts(records.filter(r => r.date.toISOString().slice(0, 10) === day)) };
    });
    return jsonRecord({
      class: group, date: query.date, today: schoolDate(), items,
      summary: { ...summary, unmarked: items.filter(r => !r.attendance && !r.recordedElsewhere).length },
      timeline,
    });
  });

export const saveRegister = async (actor: AuthenticatedUser, input: RegisterSave) => {
  if (input.date > schoolDate()) throw new HttpError(422, "Attendance cannot be recorded for a future date");
  try {
    return await prisma.$transaction(async (tx) => {
      const group = await authorizedClass(tx, actor, input.classId);
      const orgId = BigInt(actor.orgId), date = new Date(input.date);
      const changes: Prisma.InputJsonValue[] = [];
      // Stable lock order prevents two bulk requests from locking students in opposite order.
      for (const row of [...input.records].sort((a, b) =>
        BigInt(a.studentId) < BigInt(b.studentId) ? -1 : 1)) {
        const studentId = BigInt(row.studentId);
        const student = await tx.student.findFirst({ where: { id: studentId, orgId } });
        if (!student) throw new HttpError(404, "Student not found");
        const before = await tx.attendanceRecord.findUnique({
          where: { orgId_studentId_date: { orgId, studentId, date } },
        });
        if (before && before.classId !== group.id)
          throw new HttpError(409, "Attendance was already recorded in another class. Review the original register.");
        const current = student.classId === group.id && student.status === "ACTIVE";
        if (!current && !(actor.role === "ADMIN" && before))
          throw new HttpError(409, "The student is no longer active in this class. Reload the register.");
        if (!before && student.joinedOn && student.joinedOn > date)
          throw new HttpError(409, "The selected date is before the student joined");
        if ((before?.version ?? 0) !== row.version)
          throw new HttpError(409, "Attendance has changed since you opened it. Reload the register before saving.");
        const reason = row.reason || null, checkInTime = row.checkInTime ?? null;
        if (before && before.status === row.status && before.reason === reason && before.checkInTime === checkInTime) continue;
        if (before && !input.correctionReason)
          throw new HttpError(422, "Add a reason for correcting saved attendance");
        const values = { status: row.status, reason, checkInTime, markedById: BigInt(actor.userId) };
        let recordId: bigint;
        if (before) {
          const result = await tx.attendanceRecord.updateMany({
            where: { id: before.id, orgId, version: row.version },
            data: { ...values, version: { increment: 1 } },
          });
          if (result.count !== 1) throw new HttpError(409, "Attendance changed. Reload the register.");
          recordId = before.id;
        } else {
          recordId = (await tx.attendanceRecord.create({
            data: { orgId, branchId: group.branchId, classId: group.id, studentId, date, ...values },
          })).id;
        }
        const snapshot = (r: { status: string; reason: string | null; checkInTime: string | null }) =>
          ({ status: r.status, reason: r.reason, checkInTime: r.checkInTime });
        changes.push({ recordId: recordId.toString(), studentId: row.studentId,
          before: before ? { ...snapshot(before), version: before.version } : null,
          after: { ...snapshot(values), version: row.version + 1 } });
      }
      if (changes.length) await tx.auditLog.create({ data: {
        orgId, actorUserId: BigInt(actor.userId), action: "attendance.register.saved",
        entityType: "ClassAttendance", entityId: input.classId,
        metadata: { date: input.date, correctionReason: input.correctionReason ?? null, changes },
      } });
      return { saved: changes.length };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted });
  } catch (error) {
    if (attendanceConflict(error))
      throw new HttpError(409, "Attendance changed while saving. Reload the register.");
    throw error;
  }
};

export const getRegisterHistory = async (actor: AuthenticatedUser, query: RegisterQuery) => {
  await authorizedClass(prisma, actor, query.classId);
  const entries = await prisma.auditLog.findMany({
    where: { orgId: BigInt(actor.orgId), entityType: "ClassAttendance", entityId: query.classId,
      action: { in: ["attendance.register.saved", "attendance.bulk.saved"] },
      metadata: { path: "$.date", equals: query.date } },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 50,
    select: { id: true, createdAt: true, actorUser: { select: { fullName: true } }, metadata: true },
  });
  return jsonRecord(entries);
};
