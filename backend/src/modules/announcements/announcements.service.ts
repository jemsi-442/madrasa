import type { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { CreateAnnouncementInput, ListAnnouncementsQuery } from "./announcements.schemas";

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
  orgId: string,
  createdByUserId: string,
  input: CreateAnnouncementInput,
) => {
  const parsedOrgId = BigInt(orgId);
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
      createdById: BigInt(createdByUserId),
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

export const listAnnouncements = async (orgId: string, query: ListAnnouncementsQuery) => {
  const where: Prisma.AnnouncementWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.branchId) {
    where.branchId = BigInt(query.branchId);
  }

  if (query.audience) {
    where.audience = query.audience;
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

export const getAnnouncementById = async (orgId: string, id: string) => {
  const record = await prisma.announcement.findFirst({
    where: {
      id: BigInt(id),
      orgId: BigInt(orgId),
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
