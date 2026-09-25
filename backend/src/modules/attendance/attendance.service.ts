import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  BulkMarkAttendanceInput,
  ClassAttendanceQuery,
  StudentAttendanceQuery,
} from "./attendance.schemas";

import { attendanceConflict, schoolDate } from "./register.service";

const toAttendanceResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint;
  classId: bigint;
  studentId: bigint;
  date: Date;
  status: string;
  reason: string | null;
  checkInTime: string | null;
  version: number;
  markedById: bigint;
  createdAt: Date;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  markedBy?: { id: bigint; fullName: string; role: string } | null;
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  branchId: record.branchId.toString(),
  classId: record.classId.toString(),
  studentId: record.studentId.toString(),
  date: record.date.toISOString().slice(0, 10),
  status: record.status,
  reason: record.reason,
  checkInTime: record.checkInTime,
  version: record.version,
  markedById: record.markedById.toString(),
  createdAt: record.createdAt.toISOString(),
  student: record.student
    ? {
        id: record.student.id.toString(),
        fullName: record.student.fullName,
        admissionNo: record.student.admissionNo,
      }
    : null,
  markedBy: record.markedBy
    ? {
        id: record.markedBy.id.toString(),
        fullName: record.markedBy.fullName,
        role: record.markedBy.role,
      }
    : null,
});

const ensureClassBelongsToOrg = async (orgId: bigint, classId: bigint, teacherId?: bigint) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: classId,
      orgId,
      ...(teacherId ? { teacherId } : {}),
    },
    select: {
      id: true,
      branchId: true,
      name: true,
    },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found for this organization");
  }

  return classRecord;
};

const ensureStudentBelongsToClass = async (orgId: bigint, classId: bigint, studentId: bigint) => {
  const student = await prisma.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: {
      id: true,
      classId: true,
      status: true,
      branchId: true,
    },
  });

  if (!student) {
    throw new HttpError(404, `Student ${studentId.toString()} not found for this organization`);
  }

  if (student.status !== "ACTIVE") {
    throw new HttpError(409, `Student ${studentId.toString()} is not active`);
  }

  if (student.classId !== classId) {
    throw new HttpError(409, `Student ${studentId.toString()} is not assigned to this class`);
  }

  return student;
};

export const bulkMarkAttendance = async (
  authUser: AuthenticatedUser,
  input: BulkMarkAttendanceInput,
) => {
  if (authUser.role !== "TEACHER") throw new HttpError(403, "Only assigned teachers can use this endpoint");
  if (input.date > schoolDate()) throw new HttpError(422, "Attendance cannot be recorded for a future date");
  const parsedOrgId = BigInt(authUser.orgId);
  const parsedClassId = BigInt(input.classId);
  const parsedMarkedById = BigInt(authUser.userId);
  const attendanceDate = new Date(input.date);
  const seenStudentIds = new Set<string>();

  for (const record of input.records) {
    if (seenStudentIds.has(record.studentId)) {
      throw new HttpError(409, `Duplicate studentId in attendance payload: ${record.studentId}`);
    }

    seenStudentIds.add(record.studentId);
  }

  const classRecord = await ensureClassBelongsToOrg(
    parsedOrgId,
    parsedClassId,
    authUser.role === "TEACHER" ? BigInt(authUser.userId) : undefined,
  );

  for (const record of input.records) {
    await ensureStudentBelongsToClass(parsedOrgId, parsedClassId, BigInt(record.studentId));
  }

  const results = await prisma.$transaction(async (tx) => {
    const saved = [];
    const changes: Prisma.InputJsonValue[] = [];
    for (const record of [...input.records].sort((a, b) => BigInt(a.studentId) < BigInt(b.studentId) ? -1 : 1)) {
      const studentId = BigInt(record.studentId);
      const before = await tx.attendanceRecord.findUnique({
        where: { orgId_studentId_date: { orgId: parsedOrgId, studentId, date: attendanceDate } },
      });
      if (before && before.classId !== parsedClassId)
        throw new HttpError(409, "Attendance already exists in another class");
      const values = {
        status: record.status, reason: record.reason ?? null, markedById: parsedMarkedById,
        checkInTime: ["PRESENT", "LATE"].includes(record.status) ? before?.checkInTime ?? null : null,
      };
      if (before) {
        const updated = await tx.attendanceRecord.updateMany({
          where: { id: before.id, orgId: parsedOrgId, version: before.version },
          data: { ...values, version: { increment: 1 } },
        });
        if (updated.count !== 1) throw new HttpError(409, "Attendance changed. Reload the register.");
      } else {
        await tx.attendanceRecord.create({ data: {
          orgId: parsedOrgId, branchId: classRecord.branchId, classId: parsedClassId,
          studentId, date: attendanceDate, ...values,
        } });
      }
      const result = await tx.attendanceRecord.findUniqueOrThrow({
        where: { orgId_studentId_date: { orgId: parsedOrgId, studentId, date: attendanceDate } },
        include: {
          student: { select: { id: true, fullName: true, admissionNo: true } },
          markedBy: { select: { id: true, fullName: true, role: true } },
        },
      });
      changes.push({
        studentId: record.studentId,
        before: before ? { status: before.status, reason: before.reason, checkInTime: before.checkInTime, version: before.version } : null,
        after: { status: result.status, reason: result.reason, checkInTime: result.checkInTime, version: result.version },
      });
      saved.push(result);
    }
    await tx.auditLog.create({ data: {
      orgId: parsedOrgId, actorUserId: parsedMarkedById, action: "attendance.bulk.saved",
      entityType: "ClassAttendance", entityId: input.classId,
      metadata: { date: input.date, changes },
    } });
    return saved;
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }).catch((error: unknown) => {
    if (attendanceConflict(error))
      throw new HttpError(409, "Attendance changed. Reload the register.");
    throw error;
  });

  return results.map(toAttendanceResponse);
};

export const getClassAttendance = async (
  authUser: AuthenticatedUser,
  classId: string,
  query: ClassAttendanceQuery,
) => {
  const parsedOrgId = BigInt(authUser.orgId);
  const parsedClassId = BigInt(classId);

  await ensureClassBelongsToOrg(
    parsedOrgId,
    parsedClassId,
    authUser.role === "TEACHER" ? BigInt(authUser.userId) : undefined,
  );

  const where: Prisma.AttendanceRecordWhereInput = {
    orgId: parsedOrgId,
    classId: parsedClassId,
  };

  if (query.date) {
    where.date = new Date(query.date);
  }

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "desc" }, { studentId: "asc" }],
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      markedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map(toAttendanceResponse);
};

export const getStudentAttendance = async (
  authUser: AuthenticatedUser,
  studentId: string,
  query: StudentAttendanceQuery,
) => {
  const parsedOrgId = BigInt(authUser.orgId);
  const parsedStudentId = BigInt(studentId);

  const student = await prisma.student.findFirst({
    where: {
      id: parsedStudentId,
      orgId: parsedOrgId,
      ...(authUser.role === "TEACHER" ? { currentClass: { teacherId: BigInt(authUser.userId) } } : {}),
    },
    select: { id: true },
  });

  if (!student) {
    throw new HttpError(404, "Student not found");
  }

  const where: Prisma.AttendanceRecordWhereInput = {
    orgId: parsedOrgId,
    studentId: parsedStudentId,
  };

  if (query.dateFrom || query.dateTo) {
    where.date = {};

    if (query.dateFrom) {
      where.date.gte = new Date(query.dateFrom);
    }

    if (query.dateTo) {
      where.date.lte = new Date(query.dateTo);
    }
  }

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "desc" }],
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      markedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map(toAttendanceResponse);
};
