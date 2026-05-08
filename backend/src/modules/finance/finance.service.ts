import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import { buildPaginationMeta, getPaginationParams } from "../../shared/utils/pagination";
import type {
  CreateExpenseInput,
  CreateFeeStructureInput,
  CreateInvoiceInput,
  ListExpensesQuery,
  ListFeeStructuresQuery,
  ListInvoicesQuery,
} from "./finance.schemas";

const toMoneyString = (value: Prisma.Decimal | string | number) => new Prisma.Decimal(value).toFixed(2);

const toFeeStructureResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint | null;
  classId: bigint | null;
  name: string;
  amount: Prisma.Decimal;
  billingCycle: string;
  isActive: boolean;
  createdAt: Date;
  branch?: { id: bigint; name: string } | null;
  class?: { id: bigint; name: string; level: string } | null;
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  branchId: record.branchId?.toString() ?? null,
  classId: record.classId?.toString() ?? null,
  name: record.name,
  amount: toMoneyString(record.amount),
  billingCycle: record.billingCycle,
  isActive: record.isActive,
  createdAt: record.createdAt.toISOString(),
  branch: record.branch
    ? { id: record.branch.id.toString(), name: record.branch.name }
    : null,
  class: record.class
    ? { id: record.class.id.toString(), name: record.class.name, level: record.class.level }
    : null,
});

const toInvoiceResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint;
  studentId: bigint;
  feeStructureId: bigint | null;
  invoiceNo: string;
  amountDue: Prisma.Decimal;
  amountPaid: Prisma.Decimal;
  currency: string;
  dueDate: Date;
  status: string;
  issuedAt: Date;
  createdAt: Date;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  feeStructure?: { id: bigint; name: string } | null;
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  branchId: record.branchId.toString(),
  studentId: record.studentId.toString(),
  feeStructureId: record.feeStructureId?.toString() ?? null,
  invoiceNo: record.invoiceNo,
  amountDue: toMoneyString(record.amountDue),
  amountPaid: toMoneyString(record.amountPaid),
  currency: record.currency,
  dueDate: record.dueDate.toISOString().slice(0, 10),
  status: record.status,
  issuedAt: record.issuedAt.toISOString(),
  createdAt: record.createdAt.toISOString(),
  student: record.student
    ? {
        id: record.student.id.toString(),
        fullName: record.student.fullName,
        admissionNo: record.student.admissionNo,
      }
    : null,
  feeStructure: record.feeStructure
    ? {
        id: record.feeStructure.id.toString(),
        name: record.feeStructure.name,
      }
    : null,
});

const toExpenseResponse = (record: {
  id: bigint;
  orgId: bigint;
  branchId: bigint | null;
  title: string;
  description: string | null;
  amount: Prisma.Decimal;
  currency: string;
  expenseDate: Date;
  createdAt: Date;
  recordedById: bigint | null;
  branch?: { id: bigint; name: string } | null;
  recordedBy?: { id: bigint; fullName: string; role: string } | null;
}) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  branchId: record.branchId?.toString() ?? null,
  title: record.title,
  description: record.description,
  amount: toMoneyString(record.amount),
  currency: record.currency,
  expenseDate: record.expenseDate.toISOString().slice(0, 10),
  createdAt: record.createdAt.toISOString(),
  recordedById: record.recordedById?.toString() ?? null,
  branch: record.branch
    ? { id: record.branch.id.toString(), name: record.branch.name }
    : null,
  recordedBy: record.recordedBy
    ? { id: record.recordedBy.id.toString(), fullName: record.recordedBy.fullName, role: record.recordedBy.role }
    : null,
});

const ensureBranchBelongsToOrg = async (orgId: bigint, branchId: bigint) => {
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, orgId },
    select: { id: true },
  });

  if (!branch) {
    throw new HttpError(404, "Branch not found for this organization");
  }
};

const ensureClassBelongsToOrg = async (orgId: bigint, classId: bigint) => {
  const classRecord = await prisma.class.findFirst({
    where: { id: classId, orgId },
    select: { id: true, branchId: true },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found for this organization");
  }

  return classRecord;
};

const ensureStudentBelongsToOrg = async (orgId: bigint, studentId: bigint) => {
  const student = await prisma.student.findFirst({
    where: { id: studentId, orgId },
    select: { id: true, branchId: true },
  });

  if (!student) {
    throw new HttpError(404, "Student not found for this organization");
  }

  return student;
};

const generateInvoiceNo = () => {
  const date = new Date();
  const stamp = `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, "0")}${String(
    date.getUTCDate(),
  ).padStart(2, "0")}`;
  const random = Math.floor(Math.random() * 100000)
    .toString()
    .padStart(5, "0");

  return `INV-${stamp}-${random}`;
};

export const createFeeStructure = async (orgId: string, input: CreateFeeStructureInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : null;
  const parsedClassId = input.classId ? BigInt(input.classId) : null;

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);
  }

  if (parsedClassId) {
    const classRecord = await ensureClassBelongsToOrg(parsedOrgId, parsedClassId);

    if (parsedBranchId && classRecord.branchId !== parsedBranchId) {
      throw new HttpError(409, "Class and branch must belong to the same branch scope");
    }
  }

  const record = await prisma.feeStructure.create({
    data: {
      orgId: parsedOrgId,
      branchId: parsedBranchId,
      classId: parsedClassId,
      name: input.name,
      amount: new Prisma.Decimal(input.amount),
      billingCycle: input.billingCycle,
      isActive: input.isActive ?? true,
    },
    include: {
      branch: { select: { id: true, name: true } },
      class: { select: { id: true, name: true, level: true } },
    },
  });

  return toFeeStructureResponse(record);
};

export const listFeeStructures = async (orgId: string, query: ListFeeStructuresQuery) => {
  const where: Prisma.FeeStructureWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.branchId) where.branchId = BigInt(query.branchId);
  if (query.classId) where.classId = BigInt(query.classId);
  if (typeof query.isActive === "boolean") where.isActive = query.isActive;
  if (query.search) {
    where.name = {
      contains: query.search,
    };
  }

  const { skip, take } = getPaginationParams(query);

  const [records, totalItems] = await Promise.all([
    prisma.feeStructure.findMany({
      where,
      orderBy: [{ createdAt: "desc" }],
      skip,
      take,
      include: {
        branch: { select: { id: true, name: true } },
        class: { select: { id: true, name: true, level: true } },
      },
    }),
    prisma.feeStructure.count({ where }),
  ]);

  return {
    items: records.map(toFeeStructureResponse),
    meta: buildPaginationMeta(totalItems, query),
  };
};

export const createInvoice = async (orgId: string, input: CreateInvoiceInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedStudentId = BigInt(input.studentId);
  const student = await ensureStudentBelongsToOrg(parsedOrgId, parsedStudentId);

  let feeStructureId: bigint | null = null;
  let amountDue: Prisma.Decimal;

  if (input.feeStructureId) {
    feeStructureId = BigInt(input.feeStructureId);
    const feeStructure = await prisma.feeStructure.findFirst({
      where: {
        id: feeStructureId,
        orgId: parsedOrgId,
      },
      select: {
        id: true,
        amount: true,
        branchId: true,
        isActive: true,
      },
    });

    if (!feeStructure) {
      throw new HttpError(404, "Fee structure not found for this organization");
    }

    if (!feeStructure.isActive) {
      throw new HttpError(409, "Fee structure is not active");
    }

    if (feeStructure.branchId && feeStructure.branchId !== student.branchId) {
      throw new HttpError(409, "Student branch does not match fee structure branch");
    }

    amountDue = feeStructure.amount;
  } else {
    if (!input.amountDue) {
      throw new HttpError(422, "amountDue is required when feeStructureId is not provided");
    }

    amountDue = new Prisma.Decimal(input.amountDue);
  }

  const record = await prisma.invoice.create({
    data: {
      orgId: parsedOrgId,
      branchId: student.branchId,
      studentId: parsedStudentId,
      feeStructureId,
      invoiceNo: generateInvoiceNo(),
      amountDue,
      amountPaid: new Prisma.Decimal(0),
      currency: input.currency ?? "TZS",
      dueDate: new Date(input.dueDate),
      status: "PENDING",
    },
    include: {
      student: { select: { id: true, fullName: true, admissionNo: true } },
      feeStructure: { select: { id: true, name: true } },
    },
  });

  return toInvoiceResponse(record);
};

export const listInvoices = async (orgId: string, query: ListInvoicesQuery) => {
  const where: Prisma.InvoiceWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.studentId) where.studentId = BigInt(query.studentId);
  if (query.branchId) where.branchId = BigInt(query.branchId);
  if (query.status) where.status = query.status;
  if (query.search) {
    where.OR = [
      {
        invoiceNo: {
          contains: query.search,
        },
      },
      {
        student: {
          fullName: {
            contains: query.search,
          },
        },
      },
      {
        student: {
          admissionNo: {
            contains: query.search,
          },
        },
      },
      {
        feeStructure: {
          name: {
            contains: query.search,
          },
        },
      },
    ];
  }

  const { skip, take } = getPaginationParams(query);
  const orderBy: Prisma.InvoiceOrderByWithRelationInput[] =
    query.sortBy === "dueDate"
      ? [{ dueDate: query.sortDir }, { createdAt: "desc" }]
      : query.sortBy === "amountDue"
        ? [{ amountDue: query.sortDir }, { createdAt: "desc" }]
        : query.sortBy === "invoiceNo"
          ? [{ invoiceNo: query.sortDir }, { createdAt: "desc" }]
          : [{ createdAt: query.sortDir }];

  const [records, totalItems] = await Promise.all([
    prisma.invoice.findMany({
      where,
      orderBy,
      skip,
      take,
      include: {
        student: { select: { id: true, fullName: true, admissionNo: true } },
        feeStructure: { select: { id: true, name: true } },
      },
    }),
    prisma.invoice.count({ where }),
  ]);

  return {
    items: records.map(toInvoiceResponse),
    meta: buildPaginationMeta(totalItems, query),
  };
};

export const createExpense = async (orgId: string, recordedByUserId: string, input: CreateExpenseInput) => {
  const parsedOrgId = BigInt(orgId);
  const parsedBranchId = input.branchId ? BigInt(input.branchId) : null;

  if (parsedBranchId) {
    await ensureBranchBelongsToOrg(parsedOrgId, parsedBranchId);
  }

  const record = await prisma.expense.create({
    data: {
      orgId: parsedOrgId,
      branchId: parsedBranchId,
      title: input.title,
      description: input.description ?? null,
      amount: new Prisma.Decimal(input.amount),
      currency: input.currency ?? "TZS",
      expenseDate: new Date(input.expenseDate),
      recordedById: BigInt(recordedByUserId),
    },
    include: {
      branch: { select: { id: true, name: true } },
      recordedBy: { select: { id: true, fullName: true, role: true } },
    },
  });

  return toExpenseResponse(record);
};

export const listExpenses = async (orgId: string, query: ListExpensesQuery) => {
  const where: Prisma.ExpenseWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.branchId) where.branchId = BigInt(query.branchId);
  if (query.search) {
    where.OR = [
      {
        title: {
          contains: query.search,
        },
      },
      {
        description: {
          contains: query.search,
        },
      },
    ];
  }

  if (query.dateFrom || query.dateTo) {
    where.expenseDate = {};
    if (query.dateFrom) where.expenseDate.gte = new Date(query.dateFrom);
    if (query.dateTo) where.expenseDate.lte = new Date(query.dateTo);
  }

  const { skip, take } = getPaginationParams(query);

  const [records, totalItems] = await Promise.all([
    prisma.expense.findMany({
      where,
      orderBy: [{ expenseDate: "desc" }, { createdAt: "desc" }],
      skip,
      take,
      include: {
        branch: { select: { id: true, name: true } },
        recordedBy: { select: { id: true, fullName: true, role: true } },
      },
    }),
    prisma.expense.count({ where }),
  ]);

  return {
    items: records.map(toExpenseResponse),
    meta: buildPaginationMeta(totalItems, query),
  };
};
