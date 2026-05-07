import bcrypt from "bcryptjs";
import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { CreateUserInput, ListUsersQuery } from "./users.schemas";

const toUserResponse = (user: {
  id: bigint;
  fullName: string;
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
  } | null;
}) => ({
  id: user.id.toString(),
  fullName: user.fullName,
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

export const createUser = async (orgId: string, input: CreateUserInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : null;
  const parsedGuardianId = input.guardianId ? BigInt(input.guardianId) : null;
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
      await tx.guardian.update({
        where: { id: parsedGuardianId },
        data: {
          userId: createdUser.id,
        },
      });
    }

    return tx.user.findUniqueOrThrow({
      where: { id: createdUser.id },
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
        guardianProfile: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            email: true,
          },
        },
      },
    });
  });

  return toUserResponse(user);
};

export const listUsers = async (orgId: string, query: ListUsersQuery) => {
  const where: Prisma.UserWhereInput = {
    orgId: BigInt(orgId),
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
    },
  });

  return users.map(toUserResponse);
};
