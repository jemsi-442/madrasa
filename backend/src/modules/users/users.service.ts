import bcrypt from "bcryptjs";
import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { CreateUserInput, ListUsersQuery } from "./users.schemas";
import { availableFamilyGuardian } from "./family-guardians";

const toUserResponse = (user: {
  id: bigint;
  fullName: string;
  familyLoginId?: string | null;
  email: string | null;
  phone: string | null;
  role: string;
  status: string;
  orgId: bigint;
  branchId: bigint | null;
  createdAt: Date;
  guardianProfile?: {
    id: bigint;
    fullName: string;
    phone: string;
    email: string | null;
    studentLinks?: { student: { id: bigint; fullName: string; admissionNo: string } }[];
  } | null;
  learnerProfile?: {
    id: bigint;
    admissionNo: string;
    fullName: string;
    programCategory: string;
  } | null;
}) => ({
  id: user.id.toString(),
  fullName: user.fullName,
  familyLoginId: user.familyLoginId ?? null,
  email: user.email,
  phone: user.phone,
  role: user.role,
  status: user.status,
  orgId: user.orgId.toString(),
  branchId: user.branchId?.toString() ?? null,
  createdAt: user.createdAt.toISOString(),
  guardianProfile: user.guardianProfile
    ? {
        id: user.guardianProfile.id.toString(),
        fullName: user.guardianProfile.fullName,
        phone: user.guardianProfile.phone,
        email: user.guardianProfile.email,
        children: (user.guardianProfile.studentLinks ?? []).map(({ student }) => ({
          id: student.id.toString(), fullName: student.fullName, admissionNo: student.admissionNo,
        })),
      }
    : null,
  learnerProfile: user.learnerProfile
    ? {
        id: user.learnerProfile.id.toString(),
        admissionNo: user.learnerProfile.admissionNo,
        fullName: user.learnerProfile.fullName,
        programCategory: user.learnerProfile.programCategory,
      }
    : null,
});

const ensureBranchBelongsToOrg = async (orgId: bigint, branchId: bigint) => {
  const branch = await prisma.branch.findFirst({
    where: {
      id: branchId,
      orgId,
    },
    select: {
      id: true,
    },
  });

  if (!branch) {
    throw new HttpError(404, "Branch not found for this organization");
  }
};

const ensureGuardianAvailableForParentAccount = async (orgId: bigint, guardianId: bigint) => {
  const guardian = await prisma.guardian.findFirst({
    where: {
      id: guardianId,
      orgId,
    },
    select: {
      id: true,
      userId: true,
    },
  });

  if (!guardian) {
    throw new HttpError(404, "Guardian not found for this organization");
  }

  if (guardian.userId) {
    throw new HttpError(409, "This guardian is already linked to a parent account");
  }
};

const ensureStudentAvailableForLearnerAccount = async (orgId: bigint, studentId: bigint) => {
  const student = await prisma.student.findFirst({
    where: {
      id: studentId,
      orgId,
    },
    select: {
      id: true,
      learnerUserId: true,
    },
  });

  if (!student) {
    throw new HttpError(404, "Student not found for this organization");
  }

  if (student.learnerUserId) {
    throw new HttpError(409, "This student is already linked to a learner account");
  }
};

export const createUser = async (orgId: string, input: CreateUserInput, actorBranchId?: string | null) => {
  const parsedOrgId = BigInt(orgId);
  if (actorBranchId && input.branchId && BigInt(input.branchId) !== BigInt(actorBranchId)) {
    throw new HttpError(403, "Account branch is outside your scope");
  }
  const parsedBranchId = actorBranchId ? BigInt(actorBranchId) : input.branchId ? BigInt(input.branchId) : null;
  const scopeBranch = actorBranchId ? BigInt(actorBranchId) : null;
  const parsedGuardianId = input.guardianId ? BigInt(input.guardianId) : null;
  const parsedStudentId = input.studentId ? BigInt(input.studentId) : null;
  const uniqueIdentityFilters: Prisma.UserWhereInput[] = [];

  if (input.email) {
    uniqueIdentityFilters.push({ email: input.email });
  }

  if (input.phone) {
    uniqueIdentityFilters.push({ phone: input.phone });
  }

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);
  }

  if (parsedGuardianId) {
    await ensureGuardianAvailableForParentAccount(parsedOrgId, parsedGuardianId);
    if (!await prisma.guardian.findFirst({ where: { id: parsedGuardianId, ...availableFamilyGuardian(parsedOrgId, scopeBranch) }, select: { id: true } })) {
      throw new HttpError(404, "Guardian is not available in your scope");
    }
  }

  if (parsedStudentId) {
    await ensureStudentAvailableForLearnerAccount(parsedOrgId, parsedStudentId);
  }

  const existingUser = await prisma.user.findFirst({
    where: {
      orgId: parsedOrgId,
      OR: uniqueIdentityFilters,
    },
    select: { id: true },
  });

  if (existingUser) {
    throw new HttpError(409, "A user with this email or phone already exists");
  }

  const passwordHash = await bcrypt.hash(input.password, 12);

  const user = await prisma.$transaction(async (tx) => {
    const createdUser = await tx.user.create({
      data: {
        orgId: parsedOrgId,
        branchId: parsedBranchId,
        fullName: input.fullName,
        email: input.email ?? null,
        phone: input.phone ?? null,
        passwordHash,
        role: input.role,
        status: "ACTIVE",
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        orgId: true,
        branchId: true,
        createdAt: true,
      },
    });

    if (parsedGuardianId) {
      // Claim the link atomically: the earlier availability check can race.
      const linked = await tx.guardian.updateMany({
        where: { id: parsedGuardianId, ...availableFamilyGuardian(parsedOrgId, scopeBranch) },
        data: {
          userId: createdUser.id,
        },
      });
      if (linked.count !== 1) {
        throw new HttpError(409, "Guardian is no longer available for this parent account");
      }
    }

    if (parsedStudentId) {
      const linked = await tx.student.updateMany({
        where: { id: parsedStudentId, orgId: parsedOrgId, learnerUserId: null, ...(scopeBranch ? { branchId: scopeBranch } : {}) },
        data: {
          learnerUserId: createdUser.id,
        },
      });
      if (linked.count !== 1) {
        throw new HttpError(409, "Student is no longer available for this learner account");
      }
    }

    return tx.user.findUniqueOrThrow({
      where: { id: createdUser.id },
      select: {
        familyLoginId: true,
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        orgId: true,
        branchId: true,
        createdAt: true,
        guardianProfile: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            email: true,
          },
        },
        learnerProfile: {
          select: {
            id: true,
            admissionNo: true,
            fullName: true,
            programCategory: true,
          },
        },
      },
    });
  }).catch((error: unknown) => {
    const changedRecord = error instanceof Prisma.PrismaClientUnknownRequestError
      && /MysqlError \{ code: 1020,/.test(error.message);
    if (changedRecord || (error instanceof Prisma.PrismaClientKnownRequestError
      && ["P2002", "P2034"].includes(error.code))) {
      throw new HttpError(409, "Account or profile changed during creation. Refresh the records before trying again");
    }
    throw error;
  });

  return toUserResponse(user);
};

export const listUsers = async (orgId: string, query: ListUsersQuery, branchId?: string | null) => {
  const where: Prisma.UserWhereInput = {
    orgId: BigInt(orgId),
    ...(branchId ? { branchId: BigInt(branchId) } : {}),
  };

  if (query.role) {
    where.role = query.role;
  }

  if (query.status) {
    where.status = query.status;
  }

  const users = await prisma.user.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    select: {
      familyLoginId: true,
      id: true,
      fullName: true,
      email: true,
      phone: true,
      role: true,
      status: true,
      orgId: true,
      branchId: true,
      createdAt: true,
      guardianProfile: {
        select: {
          id: true,
          fullName: true,
          phone: true,
          email: true,
          studentLinks: {
            where: { orgId: BigInt(orgId), guardian: { orgId: BigInt(orgId) },
              student: { orgId: BigInt(orgId), ...(branchId ? { branchId: BigInt(branchId) } : {}) } },
            orderBy: { studentId: "asc" },
            select: { student: { select: { id: true, fullName: true, admissionNo: true } } },
          },
        },
      },
      learnerProfile: {
        select: {
          id: true,
          admissionNo: true,
          fullName: true,
          programCategory: true,
        },
      },
    },
  });

  return users.map(toUserResponse);
};
