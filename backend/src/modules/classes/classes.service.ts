import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type {
  CreateClassInput,
  CreateEnrollmentInput,
  ListClassesQuery,
  ListEnrollmentsQuery,
} from "./classes.schemas";

const toClassResponse = (classRecord: {
  id: bigint;
  orgId: bigint;
  branchId: bigint;
  name: string;
  level: string;
  academicYear: string;
  teacherId: bigint | null;
  capacity: number | null;
  createdAt: Date;
  branch?: { id: bigint; name: string } | null;
  teacher?: { id: bigint; fullName: string; email: string | null; phone: string | null } | null;
  _count?: { currentStudents: number; enrollments: number };
}) => ({
  id: classRecord.id.toString(),
  orgId: classRecord.orgId.toString(),
  branchId: classRecord.branchId.toString(),
  name: classRecord.name,
  level: classRecord.level,
  academicYear: classRecord.academicYear,
  teacherId: classRecord.teacherId?.toString() ?? null,
  capacity: classRecord.capacity,
  createdAt: classRecord.createdAt.toISOString(),
  branch: classRecord.branch
    ? {
        id: classRecord.branch.id.toString(),
        name: classRecord.branch.name,
      }
    : null,
  teacher: classRecord.teacher
    ? {
        id: classRecord.teacher.id.toString(),
        fullName: classRecord.teacher.fullName,
        email: classRecord.teacher.email,
        phone: classRecord.teacher.phone,
      }
    : null,
  stats: classRecord._count
    ? {
        currentStudents: classRecord._count.currentStudents,
        enrollments: classRecord._count.enrollments,
      }
    : null,
});

const toEnrollmentResponse = (enrollment: {
  id: bigint;
  orgId: bigint;
  studentId: bigint;
  classId: bigint;
  academicYear: string;
  status: string;
  createdAt: Date;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  class?: { id: bigint; name: string; level: string; academicYear: string } | null;
}) => ({
  id: enrollment.id.toString(),
  orgId: enrollment.orgId.toString(),
  studentId: enrollment.studentId.toString(),
  classId: enrollment.classId.toString(),
  academicYear: enrollment.academicYear,
  status: enrollment.status,
  createdAt: enrollment.createdAt.toISOString(),
  student: enrollment.student
    ? {
        id: enrollment.student.id.toString(),
        fullName: enrollment.student.fullName,
        admissionNo: enrollment.student.admissionNo,
      }
    : null,
  class: enrollment.class
    ? {
        id: enrollment.class.id.toString(),
        name: enrollment.class.name,
        level: enrollment.class.level,
        academicYear: enrollment.class.academicYear,
      }
    : null,
});

const ensureBranchBelongsToOrg = async (orgId: bigint, branchId: bigint) => {
  const branch = await prisma.branch.findFirst({
    where: {
      id: branchId,
      orgId,
    },
    select: { id: true },
  });

  if (!branch) {
    throw new HttpError(404, "Branch not found for this organization");
  }
};

const ensureTeacherBelongsToOrg = async (orgId: bigint, teacherId: bigint) => {
  const teacher = await prisma.user.findFirst({
    where: {
      id: teacherId,
      orgId,
      role: "TEACHER",
      status: "ACTIVE",
    },
    select: { id: true },
  });

  if (!teacher) {
    throw new HttpError(404, "Teacher not found for this organization");
  }
};

const ensureStudentBelongsToOrg = async (orgId: bigint, studentId: bigint) => {
  const student = await prisma.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: {
      id: true,
      branchId: true,
      status: true,
    },
  });

  if (!student) {
    throw new HttpError(404, "Student not found for this organization");
  }

  if (student.status !== "ACTIVE") {
    throw new HttpError(409, "Only active students can be enrolled");
  }

  return student;
};

const ensureClassBelongsToOrg = async (orgId: bigint, classId: bigint) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: classId,
      orgId,
    },
    select: {
      id: true,
      branchId: true,
      academicYear: true,
    },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found for this organization");
  }

  return classRecord;
};

export const createClass = async (orgId: string, input: CreateClassInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = BigInt(input.branchId);
  const parsedTeacherId = input.teacherId ? BigInt(input.teacherId) : null;

  await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);

  if (parsedTeacherId) {
    await ensureTeacherBelongsToOrg(parsedOrgId, parsedTeacherId);
  }

  const classRecord = await prisma.class.create({
    data: {
      orgId: parsedOrgId,
      branchId: parsedBranchId,
      name: input.name,
      level: input.level,
      academicYear: input.academicYear,
      teacherId: parsedTeacherId,
      capacity: input.capacity ?? null,
    },
    select: {
      id: true,
      orgId: true,
      branchId: true,
      name: true,
      level: true,
      academicYear: true,
      teacherId: true,
      capacity: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      _count: {
        select: {
          currentStudents: true,
          enrollments: true,
        },
      },
    },
  });

  return toClassResponse(classRecord);
};

export const listClasses = async (orgId: string, query: ListClassesQuery) => {
  const where: Prisma.ClassWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.branchId) {
    where.branchId = BigInt(query.branchId);
  }

  if (query.academicYear) {
    where.academicYear = query.academicYear;
  }

  if (query.teacherId) {
    where.teacherId = BigInt(query.teacherId);
  }

  const classes = await prisma.class.findMany({
    where,
    orderBy: [{ academicYear: "desc" }, { name: "asc" }],
    select: {
      id: true,
      orgId: true,
      branchId: true,
      name: true,
      level: true,
      academicYear: true,
      teacherId: true,
      capacity: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      _count: {
        select: {
          currentStudents: true,
          enrollments: true,
        },
      },
    },
  });

  return classes.map(toClassResponse);
};

export const getClassById = async (orgId: string, classId: string) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: BigInt(classId),
      orgId: BigInt(orgId),
    },
    select: {
      id: true,
      orgId: true,
      branchId: true,
      name: true,
      level: true,
      academicYear: true,
      teacherId: true,
      capacity: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      teacher: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      _count: {
        select: {
          currentStudents: true,
          enrollments: true,
        },
      },
    },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found");
  }

  return toClassResponse(classRecord);
};

export const createEnrollment = async (orgId: string, input: CreateEnrollmentInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(input.studentId);
  const parsedClassId = BigInt(input.classId);

  const student = await ensureStudentBelongsToOrg(parsedOrgId, parsedStudentId);
  const classRecord = await ensureClassBelongsToOrg(parsedOrgId, parsedClassId);

  if (student.branchId !== classRecord.branchId) {
    throw new HttpError(409, "Student and class must belong to the same branch");
  }

  if (classRecord.academicYear !== input.academicYear) {
    throw new HttpError(409, "Enrollment academic year must match the class academic year");
  }

  const existingAcademicYearEnrollment = await prisma.enrollment.findFirst({
    where: {
      orgId: parsedOrgId,
      studentId: parsedStudentId,
      academicYear: input.academicYear,
      status: "ACTIVE",
    },
    select: {
      id: true,
      classId: true,
    },
  });

  if (existingAcademicYearEnrollment && existingAcademicYearEnrollment.classId !== parsedClassId) {
    throw new HttpError(409, "Student already has an active enrollment for this academic year");
  }

  const enrollment = await prisma.$transaction(async (tx) => {
    const createdEnrollment = await tx.enrollment.create({
      data: {
        orgId: parsedOrgId,
        studentId: parsedStudentId,
        classId: parsedClassId,
        academicYear: input.academicYear,
        status: input.status,
      },
      select: {
        id: true,
      },
    });

    if (input.status === "ACTIVE") {
      await tx.student.update({
        where: {
          id: parsedStudentId,
        },
        data: {
          classId: parsedClassId,
        },
      });
    }

    return tx.enrollment.findUniqueOrThrow({
      where: {
        id: createdEnrollment.id,
      },
      select: {
        id: true,
        orgId: true,
        studentId: true,
        classId: true,
        academicYear: true,
        status: true,
        createdAt: true,
        student: {
          select: {
            id: true,
            fullName: true,
            admissionNo: true,
          },
        },
        class: {
          select: {
            id: true,
            name: true,
            level: true,
            academicYear: true,
          },
        },
      },
    });
  });

  return toEnrollmentResponse(enrollment);
};

export const listEnrollments = async (orgId: string, query: ListEnrollmentsQuery) => {
  const where: Prisma.EnrollmentWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.studentId) {
    where.studentId = BigInt(query.studentId);
  }

  if (query.classId) {
    where.classId = BigInt(query.classId);
  }

  if (query.academicYear) {
    where.academicYear = query.academicYear;
  }

  if (query.status) {
    where.status = query.status;
  }

  const enrollments = await prisma.enrollment.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      orgId: true,
      studentId: true,
      classId: true,
      academicYear: true,
      status: true,
      createdAt: true,
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      class: {
        select: {
          id: true,
          name: true,
          level: true,
          academicYear: true,
        },
      },
    },
  });

  return enrollments.map(toEnrollmentResponse);
};

