import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { buildPaginationMeta, getPaginationParams } from "../../shared/utils/pagination";
import type {
  CreateGuardianInput,
  CreateStudentInput,
  LinkGuardianInput,
  ListStudentsQuery,
  SetPrimaryGuardianInput,
  UpdateStudentInput,
} from "./students.schemas";

type DbClient = Prisma.TransactionClient | typeof prisma;

const guardianSelect = Prisma.validator<Prisma.GuardianSelect>()({
  id: true,
  fullName: true,
  phone: true,
  email: true,
  relationship: true,
  address: true,
  createdAt: true,
});

const studentSelect = Prisma.validator<Prisma.StudentSelect>()({
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
    select: guardianSelect,
  },
  guardians: {
    orderBy: [{ isPrimary: "desc" }, { createdAt: "asc" }],
    select: {
      isPrimary: true,
      createdAt: true,
      guardian: {
        select: guardianSelect,
      },
    },
  },
});

type GuardianRecord = Prisma.GuardianGetPayload<{ select: typeof guardianSelect }>;
type StudentRecord = Prisma.StudentGetPayload<{ select: typeof studentSelect }>;

const toGuardianResponse = (guardian: GuardianRecord, authUser?: Pick<AuthenticatedUser, "role">) => ({
  id: guardian.id.toString(),
  fullName: guardian.fullName,
  phone: guardian.phone,
  email: guardian.email,
  relationship: authUser?.role === "ACCOUNTANT" ? null : guardian.relationship,
  address: authUser?.role === "ACCOUNTANT" ? null : guardian.address,
  createdAt: guardian.createdAt.toISOString(),
});

const toStudentResponse = (student: StudentRecord, authUser?: Pick<AuthenticatedUser, "role">) => {
  if (!student.branch) {
    throw new HttpError(500, "Student relations are incomplete");
  }

  const isAccountantView = authUser?.role === "ACCOUNTANT";

  return {
    id: student.id.toString(),
    admissionNo: student.admissionNo,
    fullName: student.fullName,
    gender: student.gender,
    dob: isAccountantView ? null : student.dob?.toISOString().slice(0, 10) ?? null,
    status: student.status,
    branchId: student.branchId.toString(),
    classId: student.classId?.toString() ?? null,
    joinedOn: isAccountantView ? null : student.joinedOn?.toISOString().slice(0, 10) ?? null,
    leftOn: isAccountantView ? null : student.leftOn?.toISOString().slice(0, 10) ?? null,
    notes: isAccountantView ? null : student.notes,
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
    primaryGuardian: student.primaryGuardian
      ? toGuardianResponse(student.primaryGuardian, authUser)
      : null,
    guardians: isAccountantView
      ? []
      : student.guardians.map((link) => ({
          isPrimary: link.isPrimary,
          linkedAt: link.createdAt.toISOString(),
          guardian: toGuardianResponse(link.guardian, authUser),
        })),
  };
};

const ensureBranchBelongsToOrg = async (db: DbClient, orgId: bigint, branchId: bigint) => {
  const branch = await db.branch.findFirst({
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

const ensureClassBelongsToOrg = async (db: DbClient, orgId: bigint, classId: bigint) => {
  const classRecord = await db.class.findFirst({
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

const ensureGuardianBelongsToOrg = async (db: DbClient, orgId: bigint, guardianId: bigint) => {
  const guardian = await db.guardian.findFirst({
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

const ensureStudentBelongsToOrg = async (db: DbClient, orgId: bigint, studentId: bigint) => {
  const student = await db.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: {
      id: true,
      primaryGuardianId: true,
    },
  });

  if (!student) {
    throw new HttpError(404, "Student not found");
  }

  return student;
};

const getStudentRecord = async (db: DbClient, orgId: bigint, studentId: bigint) => {
  const student = await db.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: studentSelect,
  });

  if (!student) {
    throw new HttpError(404, "Student not found");
  }

  return student;
};

const getTeacherScopedStudentRecord = async (db: DbClient, authUser: AuthenticatedUser, studentId: bigint) => {
  const student = await db.student.findFirst({
    where: {
      id: studentId,
      orgId: BigInt(authUser.orgId),
      currentClass: {
        teacherId: BigInt(authUser.userId),
      },
    },
    select: studentSelect,
  });

  if (!student) {
    throw new HttpError(404, "Student not found");
  }

  return student;
};

const getStudentByIdOrThrow = async (db: DbClient, studentId: bigint) =>
  db.student.findUniqueOrThrow({
    where: {
      id: studentId,
    },
    select: studentSelect,
  });

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
    select: guardianSelect,
  });

  return toGuardianResponse(guardian);
};

export const listGuardians = async (orgId: string) => {
  const guardians = await prisma.guardian.findMany({
    where: {
      orgId: BigInt(orgId),
    },
    orderBy: [{ createdAt: "desc" }],
    select: guardianSelect,
  });

  return guardians.map((guardian) => toGuardianResponse(guardian));
};

export const createStudent = async (orgId: string, input: CreateStudentInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = BigInt(input.branchId);
  const parsedClassId = input.classId ? BigInt(input.classId) : null;

  await ensureBranchBelongsToOrg(prisma, parsedOrgId, parsedBranchId);

  if (parsedClassId) {
    await ensureClassBelongsToOrg(prisma, parsedOrgId, parsedClassId);
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
    let primaryGuardianId: bigint;

    if (input.primaryGuardianId) {
      primaryGuardianId = BigInt(input.primaryGuardianId);
      await ensureGuardianBelongsToOrg(tx, parsedOrgId, primaryGuardianId);
    } else {
      primaryGuardianId = (
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

    return getStudentByIdOrThrow(tx, createdStudent.id);
  });

  return toStudentResponse(student);
};

export const updateStudent = async (orgId: string, studentId: string, input: UpdateStudentInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(studentId);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : undefined;
  const parsedClassId =
    input.classId === undefined ? undefined : input.classId === null ? null : BigInt(input.classId);

  await ensureStudentBelongsToOrg(prisma, parsedOrgId, parsedStudentId);

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(prisma, parsedOrgId, parsedBranchId);
  }

  if (parsedClassId) {
    await ensureClassBelongsToOrg(prisma, parsedOrgId, parsedClassId);
  }

  if (input.admissionNo) {
    const existingStudent = await prisma.student.findFirst({
      where: {
        orgId: parsedOrgId,
        admissionNo: input.admissionNo,
        NOT: {
          id: parsedStudentId,
        },
      },
      select: { id: true },
    });

    if (existingStudent) {
      throw new HttpError(409, "A student with this admission number already exists");
    }
  }

  const data: Prisma.StudentUncheckedUpdateInput = {};

  if (input.admissionNo !== undefined) {
    data.admissionNo = input.admissionNo;
  }

  if (input.fullName !== undefined) {
    data.fullName = input.fullName;
  }

  if (input.gender !== undefined) {
    data.gender = input.gender;
  }

  if (parsedBranchId !== undefined) {
    data.branchId = parsedBranchId;
  }

  if (parsedClassId !== undefined) {
    data.classId = parsedClassId;
  }

  if (input.dob !== undefined) {
    data.dob = input.dob === null ? null : new Date(input.dob);
  }

  if (input.joinedOn !== undefined) {
    data.joinedOn = input.joinedOn === null ? null : new Date(input.joinedOn);
  }

  if (input.leftOn !== undefined) {
    data.leftOn = input.leftOn === null ? null : new Date(input.leftOn);
  }

  if (input.notes !== undefined) {
    data.notes = input.notes;
  }

  if (input.status !== undefined) {
    data.status = input.status;
  }

  await prisma.student.update({
    where: {
      id: parsedStudentId,
    },
    data,
  });

  const updatedStudent = await getStudentByIdOrThrow(prisma, parsedStudentId);
  return toStudentResponse(updatedStudent);
};

export const linkGuardianToStudent = async (orgId: string, studentId: string, input: LinkGuardianInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(studentId);
  const parsedGuardianId = BigInt(input.guardianId);

  await ensureStudentBelongsToOrg(prisma, parsedOrgId, parsedStudentId);
  await ensureGuardianBelongsToOrg(prisma, parsedOrgId, parsedGuardianId);

  const existingLink = await prisma.studentGuardian.findUnique({
    where: {
      studentId_guardianId: {
        studentId: parsedStudentId,
        guardianId: parsedGuardianId,
      },
    },
    select: {
      id: true,
    },
  });

  if (existingLink) {
    throw new HttpError(409, "Guardian is already linked to this student");
  }

  const student = await prisma.$transaction(async (tx) => {
    if (input.isPrimary) {
      await tx.studentGuardian.updateMany({
        where: {
          studentId: parsedStudentId,
        },
        data: {
          isPrimary: false,
        },
      });
    }

    await tx.studentGuardian.create({
      data: {
        orgId: parsedOrgId,
        studentId: parsedStudentId,
        guardianId: parsedGuardianId,
        isPrimary: input.isPrimary ?? false,
      },
    });

    if (input.isPrimary) {
      await tx.student.update({
        where: {
          id: parsedStudentId,
        },
        data: {
          primaryGuardianId: parsedGuardianId,
        },
      });
    }

    return getStudentByIdOrThrow(tx, parsedStudentId);
  });

  return toStudentResponse(student);
};

export const setPrimaryGuardian = async (
  orgId: string,
  studentId: string,
  input: SetPrimaryGuardianInput,
) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(studentId);
  const parsedGuardianId = BigInt(input.guardianId);

  await ensureStudentBelongsToOrg(prisma, parsedOrgId, parsedStudentId);

  const link = await prisma.studentGuardian.findFirst({
    where: {
      orgId: parsedOrgId,
      studentId: parsedStudentId,
      guardianId: parsedGuardianId,
    },
    select: {
      id: true,
    },
  });

  if (!link) {
    throw new HttpError(404, "Guardian is not linked to this student");
  }

  const student = await prisma.$transaction(async (tx) => {
    await tx.studentGuardian.updateMany({
      where: {
        studentId: parsedStudentId,
      },
      data: {
        isPrimary: false,
      },
    });

    await tx.studentGuardian.updateMany({
      where: {
        studentId: parsedStudentId,
        guardianId: parsedGuardianId,
      },
      data: {
        isPrimary: true,
      },
    });

    await tx.student.update({
      where: {
        id: parsedStudentId,
      },
      data: {
        primaryGuardianId: parsedGuardianId,
      },
    });

    return getStudentByIdOrThrow(tx, parsedStudentId);
  });

  return toStudentResponse(student);
};

export const unlinkGuardianFromStudent = async (orgId: string, studentId: string, guardianId: string) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(studentId);
  const parsedGuardianId = BigInt(guardianId);

  const student = await ensureStudentBelongsToOrg(prisma, parsedOrgId, parsedStudentId);

  const link = await prisma.studentGuardian.findFirst({
    where: {
      orgId: parsedOrgId,
      studentId: parsedStudentId,
      guardianId: parsedGuardianId,
    },
    select: {
      id: true,
      isPrimary: true,
    },
  });

  if (!link) {
    throw new HttpError(404, "Guardian is not linked to this student");
  }

  const totalLinks = await prisma.studentGuardian.count({
    where: {
      orgId: parsedOrgId,
      studentId: parsedStudentId,
    },
  });

  if (totalLinks <= 1) {
    throw new HttpError(409, "A student must have at least one guardian");
  }

  if (link.isPrimary || student.primaryGuardianId === parsedGuardianId) {
    throw new HttpError(409, "Set another primary guardian before removing the current primary guardian");
  }

  const updatedStudent = await prisma.$transaction(async (tx) => {
    await tx.studentGuardian.delete({
      where: {
        id: link.id,
      },
    });

    return getStudentByIdOrThrow(tx, parsedStudentId);
  });

  return toStudentResponse(updatedStudent);
};

export const listStudents = async (authUser: AuthenticatedUser, query: ListStudentsQuery) => {
  const where: Prisma.StudentWhereInput = {
    orgId: BigInt(authUser.orgId),
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

  if (query.search) {
    where.OR = [
      {
        fullName: {
          contains: query.search,
        },
      },
      {
        admissionNo: {
          contains: query.search,
        },
      },
      {
        primaryGuardian: {
          fullName: {
            contains: query.search,
          },
        },
      },
      {
        primaryGuardian: {
          phone: {
            contains: query.search,
          },
        },
      },
    ];
  }

  const { skip, take } = getPaginationParams(query);
  const orderBy: Prisma.StudentOrderByWithRelationInput[] =
    query.sortBy === "fullName"
      ? [{ fullName: query.sortDir }, { createdAt: "desc" }]
      : query.sortBy === "admissionNo"
        ? [{ admissionNo: query.sortDir }, { createdAt: "desc" }]
        : query.sortBy === "joinedOn"
          ? [{ joinedOn: query.sortDir }, { createdAt: "desc" }]
          : [{ createdAt: query.sortDir }];

  const [students, totalItems] = await Promise.all([
    prisma.student.findMany({
      where,
      orderBy,
      skip,
      take,
      select: studentSelect,
    }),
    prisma.student.count({ where }),
  ]);

  return {
    items: students.map((student) => toStudentResponse(student, authUser)),
    meta: buildPaginationMeta(totalItems, query),
  };
};

export const getStudentById = async (authUser: AuthenticatedUser, studentId: string) => {
  const parsedStudentId = BigInt(studentId);
  const student =
    authUser.role === "TEACHER"
      ? await getTeacherScopedStudentRecord(prisma, authUser, parsedStudentId)
      : await getStudentRecord(prisma, BigInt(authUser.orgId), parsedStudentId);

  return toStudentResponse(student);
};
