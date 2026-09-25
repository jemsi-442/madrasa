import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  CreatePublicInquiryInput,
  ListPublicInquiriesQuery,
  UpdatePublicInquiryStatusInput,
} from "./public-inquiries.schemas";

const publicInquiryDelegate = prisma.publicInquiry;

const toPublicInquiryResponse = (record: {
  id: bigint;
  branchId: bigint | null;
  inquiryType: string;
  status: string;
  fullName: string;
  phone: string;
  email: string | null;
  subject: string;
  message: string;
  preferredContact: string | null;
  sourcePage: string;
  createdAt: Date;
  branch: { id: bigint; name: string } | null;
}) => ({
  id: record.id.toString(),
  branchId: record.branchId?.toString() ?? null,
  inquiryType: record.inquiryType,
  status: record.status,
  fullName: record.fullName,
  phone: record.phone,
  email: record.email,
  subject: record.subject,
  message: record.message,
  preferredContact: record.preferredContact,
  sourcePage: record.sourcePage,
  createdAt: record.createdAt.toISOString(),
  branch: record.branch
    ? {
        id: record.branch.id.toString(),
        name: record.branch.name,
      }
    : null,
});

const resolvePublicOrganization = async (orgCode: string) => {
  const organization = await prisma.organization.findUnique({
    where: { code: orgCode },
    select: { id: true },
  });

  if (!organization) {
    throw new HttpError(503, "The public inquiry channel is not configured yet.");
  }

  return organization;
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
    throw new HttpError(404, "Selected branch was not found.");
  }
};

export const createPublicInquiry = async (orgCode: string, input: CreatePublicInquiryInput) => {
  const organization = await resolvePublicOrganization(orgCode);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : null;

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(organization.id, parsedBranchId);
  }

  const record = await publicInquiryDelegate.create({
    data: {
      orgId: organization.id,
      branchId: parsedBranchId,
      inquiryType: input.inquiryType,
      fullName: input.fullName,
      phone: input.phone,
      email: input.email || null,
      subject: input.subject,
      message: input.message,
      preferredContact: input.preferredContact ?? null,
      sourcePage: input.sourcePage,
    },
    select: {
      id: true,
      inquiryType: true,
      sourcePage: true,
      createdAt: true,
    },
  });

  return {
    id: record.id.toString(),
    inquiryType: record.inquiryType,
    sourcePage: record.sourcePage,
    createdAt: record.createdAt.toISOString(),
  };
};

const ensurePublicInquiryAccess = (
  authUser: AuthenticatedUser,
  inquiryType?: ListPublicInquiriesQuery["inquiryType"] | string,
  branchId?: string | null,
) => {
  if (authUser.role === "ACCOUNTANT" && inquiryType && inquiryType !== "FINANCE") {
    throw new HttpError(403, "Accountants can only access finance inquiries");
  }

  if (authUser.role === "ACCOUNTANT" && authUser.branchId && branchId && branchId !== authUser.branchId) {
    throw new HttpError(403, "Accountants can only access inquiries for their own branch");
  }
};

export const listTenantPublicInquiries = async (authUser: AuthenticatedUser, query: ListPublicInquiriesQuery) => {
  ensurePublicInquiryAccess(authUser, query.inquiryType, query.branchId);

  const filters: Prisma.PublicInquiryWhereInput[] = [];
  if (authUser.role === "ACCOUNTANT" && authUser.branchId) {
    filters.push({
      OR: [{ branchId: null }, { branchId: BigInt(authUser.branchId) }],
    });
  }
  if (query.search) {
    filters.push({
      OR: [
        { fullName: { contains: query.search } },
        { phone: { contains: query.search } },
        { email: { contains: query.search } },
        { subject: { contains: query.search } },
        { message: { contains: query.search } },
      ],
    });
  }

  const records = await publicInquiryDelegate.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      ...(authUser.role === "ACCOUNTANT" ? { inquiryType: "FINANCE" } : {}),
      ...(query.branchId ? { branchId: BigInt(query.branchId) } : {}),
      ...(query.inquiryType ? { inquiryType: query.inquiryType } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(filters.length ? { AND: filters } : {}),
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      branchId: true,
      inquiryType: true,
      status: true,
      fullName: true,
      phone: true,
      email: true,
      subject: true,
      message: true,
      preferredContact: true,
      sourcePage: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  return records.map(toPublicInquiryResponse);
};

export const updateTenantPublicInquiryStatus = async (
  authUser: AuthenticatedUser,
  id: string,
  input: UpdatePublicInquiryStatusInput,
) => {
  const existingRecord = await publicInquiryDelegate.findFirst({
    where: {
      id: BigInt(id),
      orgId: BigInt(authUser.orgId),
      ...(authUser.role === "ACCOUNTANT" ? { inquiryType: "FINANCE" } : {}),
      ...(authUser.role === "ACCOUNTANT" && authUser.branchId
        ? {
            OR: [
              { branchId: null },
              { branchId: BigInt(authUser.branchId) },
            ],
          }
        : {}),
    },
    select: {
      id: true,
      branchId: true,
      inquiryType: true,
      status: true,
      fullName: true,
      phone: true,
      email: true,
      subject: true,
      message: true,
      preferredContact: true,
      sourcePage: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  if (!existingRecord) {
    throw new HttpError(404, "Public inquiry not found");
  }

  const updatedRecord = await publicInquiryDelegate.update({
    where: { id: BigInt(id) },
    data: {
      status: input.status,
      resolvedAt: input.status === "CLOSED" ? new Date() : null,
    },
    select: {
      id: true,
      branchId: true,
      inquiryType: true,
      status: true,
      fullName: true,
      phone: true,
      email: true,
      subject: true,
      message: true,
      preferredContact: true,
      sourcePage: true,
      createdAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  return toPublicInquiryResponse(updatedRecord);
};
