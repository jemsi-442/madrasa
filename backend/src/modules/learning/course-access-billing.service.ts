import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";

type InvoiceSummaryRecord = {
  id: bigint;
  invoiceNo: string;
  amountDue: Prisma.Decimal;
  amountPaid: Prisma.Decimal;
  currency: string;
  dueDate: Date;
  status: string;
  issuedAt: Date;
  createdAt: Date;
};

type BillingTx = Prisma.TransactionClient;

const toMoneyString = (value: Prisma.Decimal | string | number) => new Prisma.Decimal(value).toFixed(2);

const generateCourseInvoiceNo = () => {
  const date = new Date();
  const stamp = `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, "0")}${String(
    date.getUTCDate(),
  ).padStart(2, "0")}`;
  const random = Math.floor(Math.random() * 100000)
    .toString()
    .padStart(5, "0");

  return `CRS-${stamp}-${random}`;
};

export const toCourseAccessInvoiceSummary = (invoice: InvoiceSummaryRecord) => ({
  id: invoice.id.toString(),
  invoiceNo: invoice.invoiceNo,
  amountDue: toMoneyString(invoice.amountDue),
  amountPaid: toMoneyString(invoice.amountPaid),
  balanceRemaining: toMoneyString(invoice.amountDue.minus(invoice.amountPaid)),
  currency: invoice.currency,
  dueDate: invoice.dueDate.toISOString().slice(0, 10),
  status: invoice.status,
  issuedAt: invoice.issuedAt.toISOString(),
  createdAt: invoice.createdAt.toISOString(),
});

export const ensureCourseAccessInvoiceForRequest = async (
  tx: BillingTx,
  input: {
    orgId: bigint;
    branchId: bigint;
    studentId: bigint;
    learnerUserId: bigint;
    courseId: bigint;
    courseAccessRequestId: bigint;
    amountDue: Prisma.Decimal;
    currency: string;
    dueDate?: Date;
  },
) => {
  const existing = await tx.invoice.findFirst({
    where: {
      orgId: input.orgId,
      invoiceScope: "COURSE_ACCESS",
      courseAccessRequestId: input.courseAccessRequestId,
      courseId: input.courseId,
      learnerUserId: input.learnerUserId,
      studentId: input.studentId,
      status: {
        in: ["PENDING", "OVERDUE", "PARTIALLY_PAID"],
      },
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      invoiceNo: true,
      amountDue: true,
      amountPaid: true,
      currency: true,
      dueDate: true,
      status: true,
      issuedAt: true,
      createdAt: true,
    },
  });

  if (existing) {
    return existing;
  }

  const dueDate = input.dueDate ?? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  return tx.invoice.create({
    data: {
      orgId: input.orgId,
      branchId: input.branchId,
      studentId: input.studentId,
      learnerUserId: input.learnerUserId,
      courseId: input.courseId,
      courseAccessRequestId: input.courseAccessRequestId,
      invoiceScope: "COURSE_ACCESS",
      invoiceNo: generateCourseInvoiceNo(),
      amountDue: input.amountDue,
      amountPaid: new Prisma.Decimal(0),
      currency: input.currency,
      dueDate,
      status: "PENDING",
    },
    select: {
      id: true,
      invoiceNo: true,
      amountDue: true,
      amountPaid: true,
      currency: true,
      dueDate: true,
      status: true,
      issuedAt: true,
      createdAt: true,
    },
  });
};

export const syncCourseAccessGrantForPaidInvoice = async (
  tx: BillingTx,
  input: {
    invoiceId: bigint;
    actorUserId?: bigint | null;
  },
) => {
  const invoice = await tx.invoice.findUnique({
    where: {
      id: input.invoiceId,
    },
    select: {
      id: true,
      orgId: true,
      invoiceScope: true,
      status: true,
      studentId: true,
      learnerUserId: true,
      courseId: true,
      courseAccessRequestId: true,
      course: {
        select: {
          id: true,
          title: true,
          createdByUserId: true,
        },
      },
      courseAccessRequest: {
        select: {
          id: true,
          reviewedByUserId: true,
          status: true,
          officeNote: true,
        },
      },
    },
  });

  if (
    !invoice ||
    invoice.invoiceScope !== "COURSE_ACCESS" ||
    invoice.status !== "PAID" ||
    !invoice.courseId ||
    !invoice.learnerUserId
  ) {
    return null;
  }

  const grantingUserId =
    input.actorUserId ?? invoice.courseAccessRequest?.reviewedByUserId ?? invoice.course?.createdByUserId ?? null;

  if (!grantingUserId) {
    return null;
  }

  const existingGrant = await tx.courseAccessGrant.findUnique({
    where: {
      courseId_learnerUserId: {
        courseId: invoice.courseId,
        learnerUserId: invoice.learnerUserId,
      },
    },
    select: {
      id: true,
      grantType: true,
      startsAt: true,
    },
  });

  const startsAt = existingGrant?.startsAt ?? new Date();

  const grant = await tx.courseAccessGrant.upsert({
    where: {
      courseId_learnerUserId: {
        courseId: invoice.courseId,
        learnerUserId: invoice.learnerUserId,
      },
    },
    update: {
      studentId: invoice.studentId,
      grantType: "PAYMENT",
      startsAt,
      endsAt: null,
      grantedByUserId: grantingUserId,
    },
    create: {
      orgId: invoice.orgId,
      courseId: invoice.courseId,
      studentId: invoice.studentId,
      learnerUserId: invoice.learnerUserId,
      grantType: "PAYMENT",
      startsAt,
      endsAt: null,
      grantedByUserId: grantingUserId,
    },
    select: {
      id: true,
    },
  });

  if (invoice.courseAccessRequestId) {
    await tx.courseAccessRequest.update({
      where: {
        id: invoice.courseAccessRequestId,
      },
      data: {
        status: "APPROVED",
        reviewedByUserId: invoice.courseAccessRequest?.reviewedByUserId ?? grantingUserId,
        reviewedAt: new Date(),
      },
    });
  }

  await tx.auditLog.create({
    data: {
      orgId: invoice.orgId,
      actorUserId: input.actorUserId ?? null,
      action: "COURSE_ACCESS_GRANT_SYNC_FROM_PAYMENT",
      entityType: "Invoice",
      entityId: invoice.id.toString(),
      metadata: {
        invoiceId: invoice.id.toString(),
        courseId: invoice.courseId.toString(),
        learnerUserId: invoice.learnerUserId.toString(),
        courseAccessRequestId: invoice.courseAccessRequestId?.toString() ?? null,
        grantId: grant.id.toString(),
        courseTitle: invoice.course?.title ?? null,
        previousGrantType: existingGrant?.grantType ?? null,
      } as Prisma.InputJsonValue,
    },
  });

  return grant;
};

export const prismaBilling = prisma;
