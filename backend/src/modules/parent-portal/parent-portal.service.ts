import { Prisma } from "@prisma/client";

import { initiatePayment } from "../payments/payments.service";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type { InitiateParentPaymentInput, ParentStudentAttendanceQuery } from "./parent-portal.schemas";

const toMoneyString = (value: Prisma.Decimal | string | number) => new Prisma.Decimal(value).toFixed(2);

const toDateString = (value: Date) => value.toISOString().slice(0, 10);

const toParentPaymentResponse = (payment: {
  id: bigint;
  orgId: bigint;
  invoiceId: bigint;
  provider: string;
  reference: string | null;
  externalReference: string | null;
  providerTxnRef: string | null;
  requestId: string | null;
  amount: Prisma.Decimal;
  currency: string;
  status: string;
  paymentType: string;
  channel: string | null;
  apiVersion: string | null;
  expiresAt: Date | null;
  paidAt: Date | null;
  createdAt: Date;
  invoice: {
    id: bigint;
    invoiceNo: string;
  };
}) => ({
  id: payment.id.toString(),
  orgId: payment.orgId.toString(),
  invoiceId: payment.invoiceId.toString(),
  provider: payment.provider,
  reference: payment.reference,
  externalReference: payment.externalReference,
  providerTxnRef: payment.providerTxnRef,
  requestId: payment.requestId,
  amount: toMoneyString(payment.amount),
  currency: payment.currency,
  status: payment.status,
  paymentType: payment.paymentType,
  channel: payment.channel,
  apiVersion: payment.apiVersion,
  expiresAt: payment.expiresAt?.toISOString() ?? null,
  paidAt: payment.paidAt?.toISOString() ?? null,
  createdAt: payment.createdAt.toISOString(),
  invoice: {
    id: payment.invoice.id.toString(),
    invoiceNo: payment.invoice.invoiceNo,
  },
});

const buildReceiptNo = (paymentId: bigint, paidAt: Date | null, createdAt: Date) => {
  const basisDate = paidAt ?? createdAt;
  const stamp = `${basisDate.getUTCFullYear()}${String(basisDate.getUTCMonth() + 1).padStart(2, "0")}${String(
    basisDate.getUTCDate(),
  ).padStart(2, "0")}`;
  const serial = paymentId.toString().padStart(6, "0");

  return `RCP-${stamp}-${serial}`;
};

const toParentPaymentReceiptResponse = (record: {
  id: bigint;
  orgId: bigint;
  invoiceId: bigint;
  reference: string | null;
  externalReference: string | null;
  providerTxnRef: string | null;
  amount: Prisma.Decimal;
  currency: string;
  status: string;
  channel: string | null;
  paidAt: Date | null;
  createdAt: Date;
  organization: {
    id: bigint;
    name: string;
    code: string;
  };
  invoice: {
    id: bigint;
    invoiceNo: string;
    amountDue: Prisma.Decimal;
    amountPaid: Prisma.Decimal;
    dueDate: Date;
    status: string;
    branch: { id: bigint; name: string } | null;
    student: { id: bigint; fullName: string; admissionNo: string };
  };
}) => ({
  receiptNo: buildReceiptNo(record.id, record.paidAt, record.createdAt),
  payment: {
    id: record.id.toString(),
    orgId: record.orgId.toString(),
    invoiceId: record.invoiceId.toString(),
    amount: toMoneyString(record.amount),
    currency: record.currency,
    status: record.status,
    channel: record.channel,
    reference: record.reference,
    externalReference: record.externalReference,
    providerTxnRef: record.providerTxnRef,
    paidAt: record.paidAt?.toISOString() ?? null,
    createdAt: record.createdAt.toISOString(),
  },
  organization: {
    id: record.organization.id.toString(),
    name: record.organization.name,
    code: record.organization.code,
  },
  branch: record.invoice.branch
    ? {
        id: record.invoice.branch.id.toString(),
        name: record.invoice.branch.name,
      }
    : null,
  student: {
    id: record.invoice.student.id.toString(),
    fullName: record.invoice.student.fullName,
    admissionNo: record.invoice.student.admissionNo,
  },
  invoice: {
    id: record.invoice.id.toString(),
    invoiceNo: record.invoice.invoiceNo,
    amountDue: toMoneyString(record.invoice.amountDue),
    amountPaid: toMoneyString(record.invoice.amountPaid),
    balanceRemaining: toMoneyString(record.invoice.amountDue.minus(record.invoice.amountPaid)),
    dueDate: toDateString(record.invoice.dueDate),
    status: record.invoice.status,
  },
});

const toStudentSummary = (student: {
  id: bigint;
  fullName: string;
  admissionNo: string;
  gender: string;
  status: string;
  joinedOn: Date | null;
  branch: { id: bigint; name: string };
  currentClass: { id: bigint; name: string; academicYear: string } | null;
}) => ({
  id: student.id.toString(),
  fullName: student.fullName,
  admissionNo: student.admissionNo,
  gender: student.gender,
  status: student.status,
  joinedOn: student.joinedOn ? toDateString(student.joinedOn) : null,
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
});

export const resolveParentPortalUserId = (
  authUser: AuthenticatedUser,
  requestedParentUserId?: string,
) => {
  if (authUser.role === "ADMIN") {
    if (!requestedParentUserId) {
      throw new HttpError(422, "parentUserId is required when an admin requests parent portal data");
    }

    return requestedParentUserId;
  }

  if (authUser.role === "PARENT") {
    if (requestedParentUserId && requestedParentUserId !== authUser.userId) {
      throw new HttpError(403, "Parents can only access their own portal data");
    }

    return authUser.userId;
  }

  throw new HttpError(403, "You are not allowed to access parent portal data");
};

const loadParentGuardian = async (orgId: string, userId: string) => {
  const guardian = await prisma.guardian.findFirst({
    where: {
      orgId: BigInt(orgId),
      userId: BigInt(userId),
    },
    select: {
      id: true,
      fullName: true,
      phone: true,
      email: true,
      relationship: true,
      address: true,
      studentLinks: {
        orderBy: [{ createdAt: "desc" }],
        select: {
          isPrimary: true,
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
              gender: true,
              status: true,
              joinedOn: true,
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
            },
          },
        },
      },
    },
  });

  if (!guardian) {
    throw new HttpError(404, "Parent profile is not linked to a guardian record");
  }

  return guardian;
};

const ensureParentOwnsStudent = async (orgId: string, userId: string, studentId: string) => {
  const guardian = await loadParentGuardian(orgId, userId);
  const match = guardian.studentLinks.find((link) => link.student.id.toString() === studentId);

  if (!match) {
    throw new HttpError(404, "Student not found for this parent account");
  }

  return {
    guardian,
    student: match.student,
  };
};

const ensureParentOwnsPayment = async (
  orgId: string,
  userId: string,
  studentId: string,
  paymentId: string,
) => {
  await ensureParentOwnsStudent(orgId, userId, studentId);

  const payment = await prisma.payment.findFirst({
    where: {
      id: BigInt(paymentId),
      orgId: BigInt(orgId),
      invoice: {
        studentId: BigInt(studentId),
      },
    },
    include: {
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
        },
      },
    },
  });

  if (!payment) {
    throw new HttpError(404, "Payment not found for this student");
  }

  return payment;
};

const splitGuardianName = (fullName: string) => {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  const firstname = parts[0] ?? "Parent";
  const lastname = parts.slice(1).join(" ") || firstname;

  return { firstname, lastname };
};

export const getParentPortalProfile = async (orgId: string, userId: string) => {
  const guardian = await loadParentGuardian(orgId, userId);

  return {
    guardian: {
      id: guardian.id.toString(),
      fullName: guardian.fullName,
      phone: guardian.phone,
      email: guardian.email,
      relationship: guardian.relationship,
      address: guardian.address,
    },
    students: guardian.studentLinks.map((link) => ({
      ...toStudentSummary(link.student),
      isPrimary: link.isPrimary,
    })),
  };
};

export const listParentStudents = async (orgId: string, userId: string) => {
  const guardian = await loadParentGuardian(orgId, userId);

  return guardian.studentLinks.map((link) => ({
    ...toStudentSummary(link.student),
    isPrimary: link.isPrimary,
  }));
};

export const getParentStudentAttendance = async (
  orgId: string,
  userId: string,
  studentId: string,
  query: ParentStudentAttendanceQuery,
) => {
  await ensureParentOwnsStudent(orgId, userId, studentId);

  const where: Prisma.AttendanceRecordWhereInput = {
    orgId: BigInt(orgId),
    studentId: BigInt(studentId),
  };

  if (query.dateFrom || query.dateTo) {
    where.date = {};

    if (query.dateFrom) {
      where.date.gte = new Date(`${query.dateFrom}T00:00:00.000Z`);
    }

    if (query.dateTo) {
      where.date.lte = new Date(`${query.dateTo}T23:59:59.999Z`);
    }
  }

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      date: true,
      status: true,
      reason: true,
      class: {
        select: {
          id: true,
          name: true,
          academicYear: true,
        },
      },
      markedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map((record) => ({
    id: record.id.toString(),
    date: toDateString(record.date),
    status: record.status,
    reason: record.reason,
    class: {
      id: record.class.id.toString(),
      name: record.class.name,
      academicYear: record.class.academicYear,
    },
    markedBy: {
      id: record.markedBy.id.toString(),
      fullName: record.markedBy.fullName,
      role: record.markedBy.role,
    },
  }));
};

export const getParentStudentFinance = async (orgId: string, userId: string, studentId: string) => {
  await ensureParentOwnsStudent(orgId, userId, studentId);

  const invoices = await prisma.invoice.findMany({
    where: {
      orgId: BigInt(orgId),
      studentId: BigInt(studentId),
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
      feeStructure: {
        select: {
          id: true,
          name: true,
        },
      },
      payments: {
        orderBy: [{ createdAt: "desc" }],
        select: {
          id: true,
          amount: true,
          currency: true,
          status: true,
          channel: true,
          reference: true,
          externalReference: true,
          paidAt: true,
          createdAt: true,
        },
      },
    },
  });

  return invoices.map((invoice) => ({
    id: invoice.id.toString(),
    invoiceNo: invoice.invoiceNo,
    amountDue: toMoneyString(invoice.amountDue),
    amountPaid: toMoneyString(invoice.amountPaid),
    balanceRemaining: toMoneyString(invoice.amountDue.minus(invoice.amountPaid)),
    currency: invoice.currency,
    dueDate: toDateString(invoice.dueDate),
    status: invoice.status,
    issuedAt: invoice.issuedAt.toISOString(),
    feeStructure: invoice.feeStructure
      ? {
          id: invoice.feeStructure.id.toString(),
          name: invoice.feeStructure.name,
        }
      : null,
    payments: invoice.payments.map((payment) => ({
      id: payment.id.toString(),
      amount: toMoneyString(payment.amount),
      currency: payment.currency,
      status: payment.status,
      channel: payment.channel,
      reference: payment.reference,
      externalReference: payment.externalReference,
      paidAt: payment.paidAt?.toISOString() ?? null,
      createdAt: payment.createdAt.toISOString(),
    })),
  }));
};

export const getParentStudentHifdhProgress = async (orgId: string, userId: string, studentId: string) => {
  await ensureParentOwnsStudent(orgId, userId, studentId);

  const records = await prisma.hifdhProgress.findMany({
    where: {
      orgId: BigInt(orgId),
      studentId: BigInt(studentId),
    },
    orderBy: [{ assessedOn: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      studentId: true,
      teacherId: true,
      juzNumber: true,
      surahName: true,
      ayahFrom: true,
      ayahTo: true,
      memorizationScore: true,
      revisionScore: true,
      remarks: true,
      assessedOn: true,
      createdAt: true,
      teacher: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map((record) => ({
    id: record.id.toString(),
    studentId: record.studentId.toString(),
    teacherId: record.teacherId.toString(),
    juzNumber: record.juzNumber,
    surahName: record.surahName,
    ayahFrom: record.ayahFrom,
    ayahTo: record.ayahTo,
    memorizationScore: toMoneyString(record.memorizationScore),
    revisionScore: record.revisionScore ? toMoneyString(record.revisionScore) : null,
    remarks: record.remarks,
    assessedOn: toDateString(record.assessedOn),
    createdAt: record.createdAt.toISOString(),
    teacher: {
      id: record.teacher.id.toString(),
      fullName: record.teacher.fullName,
      role: record.teacher.role,
    },
  }));
};

export const initiateParentStudentPayment = async (
  orgId: string,
  userId: string,
  studentId: string,
  input: InitiateParentPaymentInput,
  ipAddress?: string,
) => {
  const { guardian, student } = await ensureParentOwnsStudent(orgId, userId, studentId);

  const invoice = await prisma.invoice.findFirst({
    where: {
      id: BigInt(input.invoiceId),
      orgId: BigInt(orgId),
      studentId: BigInt(student.id),
    },
    select: {
      id: true,
      status: true,
    },
  });

  if (!invoice) {
    throw new HttpError(404, "Invoice not found for this student");
  }

  if (invoice.status === "CANCELLED") {
    throw new HttpError(409, "Cancelled invoices cannot be paid");
  }

  const customer = splitGuardianName(guardian.fullName);

  return initiatePayment(
    {
      orgId,
      userId,
      role: "PARENT",
      branchId: null,
    },
    {
      invoiceId: input.invoiceId,
      payerPhone: input.payerPhone,
      channel: input.channel,
      customer: {
        firstname: customer.firstname,
        lastname: customer.lastname,
        email: guardian.email ?? undefined,
      },
    },
    ipAddress,
  );
};

export const getParentStudentPaymentById = async (
  orgId: string,
  userId: string,
  studentId: string,
  paymentId: string,
) => {
  const payment = await ensureParentOwnsPayment(orgId, userId, studentId, paymentId);
  return toParentPaymentResponse(payment);
};

export const getParentStudentPaymentReceipt = async (
  orgId: string,
  userId: string,
  studentId: string,
  paymentId: string,
) => {
  await ensureParentOwnsStudent(orgId, userId, studentId);

  const payment = await prisma.payment.findFirst({
    where: {
      id: BigInt(paymentId),
      orgId: BigInt(orgId),
      invoice: {
        studentId: BigInt(studentId),
      },
    },
    include: {
      organization: {
        select: {
          id: true,
          name: true,
          code: true,
        },
      },
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          dueDate: true,
          status: true,
          branch: {
            select: {
              id: true,
              name: true,
            },
          },
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  if (!payment) {
    throw new HttpError(404, "Payment not found for this student");
  }

  if (payment.status !== "COMPLETED") {
    throw new HttpError(409, "Receipt is only available for completed payments");
  }

  return toParentPaymentReceiptResponse(payment);
};

export const listParentAnnouncements = async (orgId: string, userId: string) => {
  const guardian = await loadParentGuardian(orgId, userId);
  const branchIds = Array.from(new Set(guardian.studentLinks.map((link) => link.student.branch.id)));
  const now = new Date();

  const announcements = await prisma.announcement.findMany({
    where: {
      orgId: BigInt(orgId),
      audience: {
        in: ["ALL", "PARENTS"],
      },
      publishAt: {
        lte: now,
      },
      OR: [
        { expiresAt: null },
        { expiresAt: { gte: now } },
      ],
      AND: [
        {
          OR: [
            { branchId: null },
            { branchId: { in: branchIds } },
          ],
        },
      ],
    },
    orderBy: [{ publishAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
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

  return announcements.map((announcement) => ({
    id: announcement.id.toString(),
    title: announcement.title,
    message: announcement.message,
    audience: announcement.audience,
    publishAt: announcement.publishAt.toISOString(),
    expiresAt: announcement.expiresAt?.toISOString() ?? null,
    branch: announcement.branch
      ? {
          id: announcement.branch.id.toString(),
          name: announcement.branch.name,
        }
      : null,
    createdBy: {
      id: announcement.createdBy.id.toString(),
      fullName: announcement.createdBy.fullName,
      role: announcement.createdBy.role,
    },
  }));
};
