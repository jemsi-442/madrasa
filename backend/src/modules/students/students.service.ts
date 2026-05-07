import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { CreateGuardianInput, CreateStudentInput, ListStudentsQuery } from "./students.schemas";

const toGuardianResponse = (guardian: {
  id: bigint;
  fullName: string;
  phone: string;
  email: string | null;
  relationship: string | null;
  address: string | null;
  createdAt: Date;
}) => ({
  id: guardian.id.toString(),
  fullName: guardian.fullName,
  phone: guardian.phone,
  email: guardian.email,
  relationship: guardian.relationship,
  address: guardian.address,
  createdAt: guardian.createdAt.toISOString(),
});

const toStudentResponse = (student: {
  id: bigint;
  admissionNo: string;
  fullName: string;
  gender: string;
  dob: Date | null;
  status: string;
  branchId: bigint;
  classId: bigint | null;
  joinedOn: Date | null;
  leftOn: Date | null;
  notes: string | null;
  createdAt: Date;
  branch?: { id: bigint; name: string } | null;
  currentClass?: { id: bigint; name: string; academicYear: string } | null;
  primaryGuardian?: {
    id: bigint;
    fullName: string;
    phone: string;
    email: string | null;
    relationship: string | null;
    address: string | null;
    createdAt: Date;
  } | null;
}) => {
  if (!student.branch || !student.primaryGuardian) {
    throw new HttpError(500, "Student relations are incomplete");
  }

  return {
  id: student.id.toString(),
  admissionNo: student.admissionNo,
  fullName: student.fullName,
  gender: student.gender,
  dob: student.dob?.toISOString().slice(0, 10) ?? null,
  status: student.status,
  branchId: student.branchId.toString(),
  classId: student.classId?.toString() ?? null,
  joinedOn: student.joinedOn?.toISOString().slice(0, 10) ?? null,
  leftOn: student.leftOn?.toISOString().slice(0, 10) ?? null,
  notes: student.notes,
  createdAt: student.createdAt.toISOString(),
  branch: {
    id: student.branch.id.toString(),
    name: student.branch.name,
  },
  currentClass: student.currentClass
    ? {
        id: student.currentClass.id.toString(),
        name: student.currentClass.name,
        academicYear: student.currentClass.academicYear,
      }
    : null,
  primaryGuardian: toGuardianResponse(student.primaryGuardian),
  };
};

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

const ensureClassBelongsToOrg = async (orgId: bigint, classId: bigint) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: classId,
      orgId,
    },
    select: { id: true },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found for this organization");
  }
};

const ensureGuardianBelongsToOrg = async (orgId: bigint, guardianId: bigint) => {
  const guardian = await prisma.guardian.findFirst({
    where: {
      id: guardianId,
      orgId,
    },
    select: { id: true },
  });

  if (!guardian) {
    throw new HttpError(404, "Guardian not found for this organization");
  }
};

export const createGuardian = async (orgId: string, input: CreateGuardianInput) => {
  const guardian = await prisma.guardian.create({
    data: {
      orgId: BigInt(orgId),
      fullName: input.fullName,
      phone: input.phone,
      email: input.email ?? null,
      relationship: input.relationship ?? null,
      address: input.address ?? null,
    },
    select: {
      id: true,
      fullName: true,
      phone: true,
      email: true,
      relationship: true,
      address: true,
      createdAt: true,
    },
  });

  return toGuardianResponse(guardian);
};

export const listGuardians = async (orgId: string) => {
  const guardians = await prisma.guardian.findMany({
    where: {
      orgId: BigInt(orgId),
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      fullName: true,
      phone: true,
      email: true,
      relationship: true,
      address: true,
      createdAt: true,
    },
  });

  return guardians.map(toGuardianResponse);
};

export const createStudent = async (orgId: string, input: CreateStudentInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = BigInt(input.branchId);
  const parsedClassId = input.classId ? BigInt(input.classId) : null;

  await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);

  if (parsedClassId) {
    await ensureClassBelongsToOrg(parsedOrgId, parsedClassId);
  }

  const existingStudent = await prisma.student.findFirst({
    where: {
      orgId: parsedOrgId,
      admissionNo: input.admissionNo,
    },
    select: { id: true },
  });

  if (existingStudent) {
    throw new HttpError(409, "A student with this admission number already exists");
  }

  const student = await prisma.$transaction(async (tx) => {
    const primaryGuardianId = input.primaryGuardianId
      ? BigInt(input.primaryGuardianId)
      : (
          await tx.guardian.create({
            data: {
              orgId: parsedOrgId,
              fullName: input.guardian!.fullName,
              phone: input.guardian!.phone,
              email: input.guardian!.email ?? null,
              relationship: input.guardian!.relationship ?? null,
              address: input.guardian!.address ?? null,
            },
            select: { id: true },
          })
        ).id;

    if (input.primaryGuardianId) {
      await ensureGuardianBelongsToOrg(parsedOrgId, primaryGuardianId);
    }

    const createdStudent = await tx.student.create({
      data: {
        orgId: parsedOrgId,
        branchId: parsedBranchId,
        admissionNo: input.admissionNo,
        fullName: input.fullName,
        gender: input.gender,
        dob: input.dob ? new Date(input.dob) : null,
        classId: parsedClassId,
        primaryGuardianId,
        joinedOn: input.joinedOn ? new Date(input.joinedOn) : null,
        notes: input.notes ?? null,
      },
      select: {
        id: true,
      },
    });

    await tx.studentGuardian.create({
      data: {
        orgId: parsedOrgId,
        studentId: createdStudent.id,
        guardianId: primaryGuardianId,
        isPrimary: true,
      },
    });

    return tx.student.findUniqueOrThrow({
      where: {
        id: createdStudent.id,
      },
      select: {
        id: true,
        admissionNo: true,
        fullName: true,
        gender: true,
        dob: true,
        status: true,
        branchId: true,
        classId: true,
        joinedOn: true,
        leftOn: true,
        notes: true,
        createdAt: true,
        branch: {
          select: {
            id: true,
            name: true,
          },
        },
        currentClass: {
          select: {
            id: true,
            name: true,
            academicYear: true,
          },
        },
        primaryGuardian: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            email: true,
            relationship: true,
            address: true,
            createdAt: true,
          },
        },
      },
    });
  });

  return toStudentResponse(student);
};

export const listStudents = async (orgId: string, query: ListStudentsQuery) => {
  const where: Prisma.StudentWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.branchId) {
    where.branchId = BigInt(query.branchId);
  }

  if (query.classId) {
    where.classId = BigInt(query.classId);
  }

  if (query.status) {
    where.status = query.status;
  }

  const students = await prisma.student.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      admissionNo: true,
      fullName: true,
      gender: true,
      dob: true,
      status: true,
      branchId: true,
      classId: true,
      joinedOn: true,
      leftOn: true,
      notes: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      currentClass: {
        select: {
          id: true,
          name: true,
          academicYear: true,
        },
      },
      primaryGuardian: {
        select: {
          id: true,
          fullName: true,
          phone: true,
          email: true,
          relationship: true,
          address: true,
          createdAt: true,
        },
      },
    },
  });

  return students.map(toStudentResponse);
};

export const getStudentById = async (orgId: string, studentId: string) => {
  const student = await prisma.student.findFirst({
    where: {
      id: BigInt(studentId),
      orgId: BigInt(orgId),
    },
    select: {
      id: true,
      admissionNo: true,
      fullName: true,
      gender: true,
      dob: true,
      status: true,
      branchId: true,
      classId: true,
      joinedOn: true,
      leftOn: true,
      notes: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      currentClass: {
        select: {
          id: true,
          name: true,
          academicYear: true,
        },
      },
      primaryGuardian: {
        select: {
          id: true,
          fullName: true,
          phone: true,
          email: true,
          relationship: true,
          address: true,
          createdAt: true,
        },
      },
    },
  });

  if (!student) {
    throw new HttpError(404, "Student not found");
  }

  return toStudentResponse(student);
};
