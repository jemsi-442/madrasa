import type { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";

export function availableFamilyGuardian(orgId: bigint, branchId: bigint | null): Prisma.GuardianWhereInput {
  return { orgId, userId: null, ...(branchId ? {
    studentLinks: {
      some: { orgId, student: { orgId, branchId } },
      every: { orgId, student: { orgId, branchId } },
    },
  } : {}) };
}

export const familyGuardiansQuery = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(10),
  search: z.string().trim().max(150).default(""),
}).strict();

export async function listAvailableFamilyGuardians(orgId: string, branchId: string | null | undefined, query: z.infer<typeof familyGuardiansQuery>) {
  const childScope: Prisma.StudentGuardianWhereInput = {
    orgId: BigInt(orgId),
    student: { orgId: BigInt(orgId), ...(branchId ? { branchId: BigInt(branchId) } : {}) },
  };
  const where: Prisma.GuardianWhereInput = {
    ...availableFamilyGuardian(BigInt(orgId), branchId ? BigInt(branchId) : null),
    ...(query.search ? { OR: [
      { fullName: { contains: query.search } },
      { phone: { contains: query.search } },
      { studentLinks: { some: { AND: [childScope, { student: { OR: [
        { fullName: { contains: query.search } },
        { admissionNo: { contains: query.search } },
      ] } }] } } },
    ] } : {}),
  };
  const totalItems = await prisma.guardian.count({ where });
  const rows = await prisma.guardian.findMany({ where, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
    orderBy: [{ fullName: "asc" }, { id: "asc" }], select: { id: true, fullName: true, phone: true,
      studentLinks: { where: childScope, take: 3, orderBy: { studentId: "asc" },
        select: { student: { select: { fullName: true, admissionNo: true } } } },
    } });
  return { items: rows.map(row => {
    const children = row.studentLinks.map(({ student }) => `${student.fullName} (${student.admissionNo})`).join(", ");
    return { id: String(row.id), fullName: row.fullName,
      contactLabel: `${row.fullName} - ${row.phone}`,
      childrenSummary: children ? `Linked children (up to 3): ${children}` : "No linked children",
      displayName: `${row.fullName} - ${row.phone}${children ? ` | Children (up to 3): ${children}` : " | No linked children"}` };
  }),
    meta: { page: query.page, pageSize: query.pageSize, totalItems, totalPages: Math.ceil(totalItems / query.pageSize) } };
}
