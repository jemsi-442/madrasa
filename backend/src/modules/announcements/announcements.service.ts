import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  CreateAnnouncementInput,
  ListAnnouncementsQuery,
  ListPublicAnnouncementsQuery,
} from "./announcements.schemas";

const toAnnouncementResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint | null;
  title: string;
  message: string;
  audience: string;
  publishAt: Date;
  expiresAt: Date | null;
  createdAt: Date;
  branch?: { id: bigint; name: string } | null;
  createdBy: { id: bigint; fullName: string; role: string };
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  branchId: record.branchId?.toString() ?? null,
  title: record.title,
  message: record.message,
  audience: record.audience,
  publishAt: record.publishAt.toISOString(),
  expiresAt: record.expiresAt?.toISOString() ?? null,
  createdAt: record.createdAt.toISOString(),
  branch: record.branch
    ? {
        id: record.branch.id.toString(),
        name: record.branch.name,
      }
    : null,
  createdBy: {
    id: record.createdBy.id.toString(),
    fullName: record.createdBy.fullName,
    role: record.createdBy.role,
  },
});

type AnnouncementAudience = "ALL" | "PARENTS" | "TEACHERS" | "ACCOUNTANTS";

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

export const createAnnouncement = async (
  authUser: AuthenticatedUser,
  input: CreateAnnouncementInput,
) => {
  const parsedOrgId = BigInt(authUser.orgId);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : null;

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);
  }

  const record = await prisma.announcement.create({
    data: {
      orgId: parsedOrgId,
      branchId: parsedBranchId,
      title: input.title,
      message: input.message,
      audience: input.audience,
      publishAt: new Date(input.publishAt),
      expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
      createdById: BigInt(authUser.userId),
    },
    select: {
      id: true,
      orgId: true,
      branchId: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return toAnnouncementResponse(record);
};

const allowedAnnouncementAudiences = (authUser: AuthenticatedUser) => {
  if (authUser.role === "ADMIN") {
    return ["ALL", "PARENTS", "TEACHERS", "ACCOUNTANTS"] as AnnouncementAudience[];
  }

  if (authUser.role === "TEACHER") {
    return ["ALL", "TEACHERS"] as AnnouncementAudience[];
  }

  if (authUser.role === "ACCOUNTANT") {
    return ["ALL", "ACCOUNTANTS"] as AnnouncementAudience[];
  }

  return ["ALL"] as AnnouncementAudience[];
};

export const listAnnouncements = async (authUser: AuthenticatedUser, query: ListAnnouncementsQuery) => {
  const allowedAudiences = allowedAnnouncementAudiences(authUser);
  const where: Prisma.AnnouncementWhereInput = {
    orgId: BigInt(authUser.orgId),
  };

  if (query.branchId) {
    const requestedBranchId = BigInt(query.branchId);

    if (authUser.role !== "ADMIN" && authUser.branchId && requestedBranchId !== BigInt(authUser.branchId)) {
      throw new HttpError(403, "You are not allowed to load announcements for another branch");
    }

    where.branchId = requestedBranchId;
  } else if (authUser.role !== "ADMIN" && authUser.branchId) {
    where.OR = [
      { branchId: null },
      { branchId: BigInt(authUser.branchId) },
    ];
  }

  if (query.audience) {
    if (!allowedAudiences.includes(query.audience)) {
      throw new HttpError(403, "You are not allowed to load this announcement audience");
    }

    where.audience = query.audience;
  } else if (authUser.role !== "ADMIN") {
    where.audience = {
      in: [...allowedAudiences],
    };
  }

  if (query.activeOnly) {
    const now = new Date();
    where.publishAt = { lte: now };
    where.OR = [
      { expiresAt: null },
      { expiresAt: { gte: now } },
    ];
  }

  const records = await prisma.announcement.findMany({
    where,
    orderBy: [{ publishAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      orgId: true,
      branchId: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map(toAnnouncementResponse);
};

export const getAnnouncementById = async (authUser: AuthenticatedUser, id: string) => {
  const allowedAudiences = allowedAnnouncementAudiences(authUser);
  const record = await prisma.announcement.findFirst({
    where: {
      id: BigInt(id),
      orgId: BigInt(authUser.orgId),
      ...(authUser.role !== "ADMIN"
        ? {
            audience: {
              in: [...allowedAudiences],
            },
            ...(authUser.branchId
              ? {
                  OR: [
                    { branchId: null },
                    { branchId: BigInt(authUser.branchId) },
                  ],
                }
              : {}),
          }
        : {}),
    },
    select: {
      id: true,
      orgId: true,
      branchId: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  if (!record) {
    throw new HttpError(404, "Announcement not found");
  }

  return toAnnouncementResponse(record);
};

export const listPublicAnnouncements = async (query: ListPublicAnnouncementsQuery) => {
  const now = new Date();

  const records = await prisma.announcement.findMany({
    where: {
      audience: "ALL",
      publishAt: { lte: now },
      OR: [{ expiresAt: null }, { expiresAt: { gte: now } }],
      ...(query.branchId ? { branchId: BigInt(query.branchId) } : {}),
    },
    orderBy: [{ publishAt: "desc" }, { createdAt: "desc" }],
    take: query.limit ?? 6,
    select: {
      id: true,
      orgId: true,
      branchId: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map(toAnnouncementResponse);
};
