import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  BulkMarkAttendanceInput,
  ClassAttendanceQuery,
  StudentAttendanceQuery,
} from "./attendance.schemas";

const toAttendanceResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint;
  classId: bigint;
  studentId: bigint;
  date: Date;
  status: string;
  reason: string | null;
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
    const saved: Array<Awaited<ReturnType<typeof tx.attendanceRecord.upsert>>> = [];

    for (const record of input.records) {
      const upserted = await tx.attendanceRecord.upsert({
        where: {
          orgId_studentId_date: {
            orgId: parsedOrgId,
            studentId: BigInt(record.studentId),
            date: attendanceDate,
          },
        },
        update: {
          classId: parsedClassId,
          branchId: classRecord.branchId,
          status: record.status,
          reason: record.reason ?? null,
          markedById: parsedMarkedById,
        },
        create: {
          orgId: parsedOrgId,
          branchId: classRecord.branchId,
          classId: parsedClassId,
          studentId: BigInt(record.studentId),
          date: attendanceDate,
          status: record.status,
          reason: record.reason ?? null,
          markedById: parsedMarkedById,
        },
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

      saved.push(upserted);
    }

    return saved;
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
