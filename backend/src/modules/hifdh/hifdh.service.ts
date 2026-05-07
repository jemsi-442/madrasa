import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type { CreateHifdhProgressInput, ListHifdhProgressQuery } from "./hifdh.schemas";

const toMoneyString = (value: Prisma.Decimal | string | number) => new Prisma.Decimal(value).toFixed(2);

const toHifdhProgressResponse = (record: {
  id: bigint;
  orgId: bigint;
  studentId: bigint;
  teacherId: bigint;
  juzNumber: number;
  surahName: string;
  ayahFrom: number | null;
  ayahTo: number | null;
  memorizationScore: Prisma.Decimal;
  revisionScore: Prisma.Decimal | null;
  remarks: string | null;
  assessedOn: Date;
  createdAt: Date;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  teacher?: { id: bigint; fullName: string; role: string } | null;
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  studentId: record.studentId.toString(),
  teacherId: record.teacherId.toString(),
  juzNumber: record.juzNumber,
  surahName: record.surahName,
  ayahFrom: record.ayahFrom,
  ayahTo: record.ayahTo,
  memorizationScore: toMoneyString(record.memorizationScore),
  revisionScore: record.revisionScore ? toMoneyString(record.revisionScore) : null,
  remarks: record.remarks,
  assessedOn: record.assessedOn.toISOString().slice(0, 10),
  createdAt: record.createdAt.toISOString(),
  student: record.student
    ? {
        id: record.student.id.toString(),
        fullName: record.student.fullName,
        admissionNo: record.student.admissionNo,
      }
    : null,
  teacher: record.teacher
    ? {
        id: record.teacher.id.toString(),
        fullName: record.teacher.fullName,
        role: record.teacher.role,
      }
    : null,
});

const ensureStudentBelongsToOrg = async (orgId: bigint, studentId: bigint) => {
  const student = await prisma.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: {
      id: true,
      status: true,
    },
  });

  if (!student) {
    throw new HttpError(404, "Student not found for this organization");
  }

  if (student.status !== "ACTIVE") {
    throw new HttpError(409, "Hifdh progress can only be recorded for active students");
  }

  return student;
};

const ensureTeacherBelongsToOrg = async (orgId: bigint, teacherId: bigint) => {
  const teacher = await prisma.user.findFirst({
    where: {
      id: teacherId,
      orgId,
      role: {
        in: ["TEACHER", "ADMIN"],
      },
      status: "ACTIVE",
    },
    select: {
      id: true,
      role: true,
    },
  });

  if (!teacher) {
    throw new HttpError(404, "Teacher not found for this organization");
  }

  return teacher;
};

export const createHifdhProgress = async (
  authUser: AuthenticatedUser,
  input: CreateHifdhProgressInput,
) => {
  const parsedOrgId = BigInt(authUser.orgId);
  const parsedStudentId = BigInt(input.studentId);
  const parsedTeacherId = input.teacherId ? BigInt(input.teacherId) : BigInt(authUser.userId);

  await ensureStudentBelongsToOrg(parsedOrgId, parsedStudentId);
  const teacher = await ensureTeacherBelongsToOrg(parsedOrgId, parsedTeacherId);

  if (authUser.role === "TEACHER" && teacher.id !== BigInt(authUser.userId)) {
    throw new HttpError(403, "Teachers can only record hifdh progress under their own account");
  }

  const record = await prisma.hifdhProgress.create({
    data: {
      orgId: parsedOrgId,
      studentId: parsedStudentId,
      teacherId: parsedTeacherId,
      juzNumber: input.juzNumber,
      surahName: input.surahName,
      ayahFrom: input.ayahFrom ?? null,
      ayahTo: input.ayahTo ?? null,
      memorizationScore: new Prisma.Decimal(input.memorizationScore),
      revisionScore: input.revisionScore ? new Prisma.Decimal(input.revisionScore) : null,
      remarks: input.remarks ?? null,
      assessedOn: new Date(input.assessedOn),
    },
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return toHifdhProgressResponse(record);
};

export const listHifdhProgress = async (orgId: string, query: ListHifdhProgressQuery) => {
  const where: Prisma.HifdhProgressWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.studentId) {
    where.studentId = BigInt(query.studentId);
  }

  if (query.teacherId) {
    where.teacherId = BigInt(query.teacherId);
  }

  if (query.juzNumber) {
    where.juzNumber = query.juzNumber;
  }

  if (query.dateFrom || query.dateTo) {
    where.assessedOn = {};

    if (query.dateFrom) {
      where.assessedOn.gte = new Date(`${query.dateFrom}T00:00:00.000Z`);
    }

    if (query.dateTo) {
      where.assessedOn.lte = new Date(`${query.dateTo}T23:59:59.999Z`);
    }
  }

  const records = await prisma.hifdhProgress.findMany({
    where,
    orderBy: [{ assessedOn: "desc" }, { createdAt: "desc" }],
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map(toHifdhProgressResponse);
};

export const getHifdhProgressById = async (orgId: string, id: string) => {
  const record = await prisma.hifdhProgress.findFirst({
    where: {
      id: BigInt(id),
      orgId: BigInt(orgId),
    },
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  if (!record) {
    throw new HttpError(404, "Hifdh progress record not found");
  }

  return toHifdhProgressResponse(record);
};
