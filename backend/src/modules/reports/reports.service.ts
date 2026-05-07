import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  AttendanceExportQuery,
  AttendanceSummaryQuery,
  DashboardReportQuery,
  MonthlyFinanceSummaryQuery,
  PaymentsExportQuery,
  StudentsExportQuery,
  TeacherDashboardQuery,
} from "./reports.schemas";

type ScopeInput = {
  branchId?: string | undefined;
  classId?: string | undefined;
};

type ReportScope = {
  orgId: bigint;
  branchId: bigint | null;
  classId: bigint | null;
};

type DateRangeInput = {
  dateFrom?: string | undefined;
  dateTo?: string | undefined;
};

const toMoneyString = (value: Prisma.Decimal | string | number | null | undefined) =>
  value == null ? "0.00" : new Prisma.Decimal(value).toFixed(2);

const toDateOnly = (value: Date | null | undefined) => (value ? value.toISOString().slice(0, 10) : "");

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

const ensureClassBelongsToOrg = async (orgId: bigint, classId: bigint) => {
  const classRecord = await prisma.class.findFirst({
    where: {
      id: classId,
      orgId,
    },
    select: {
      id: true,
      branchId: true,
    },
  });

  if (!classRecord) {
    throw new HttpError(404, "Class not found for this organization");
  }

  return classRecord;
};

const ensureTeacherBelongsToOrg = async (orgId: bigint, teacherId: bigint) => {
  const teacher = await prisma.user.findFirst({
    where: {
      id: teacherId,
      orgId,
      role: "TEACHER",
      status: "ACTIVE",
    },
    select: {
      id: true,
      fullName: true,
      branchId: true,
    },
  });

  if (!teacher) {
    throw new HttpError(404, "Teacher not found for this organization");
  }

  return teacher;
};

const resolveReportScope = async (authUser: AuthenticatedUser, input: ScopeInput): Promise<ReportScope> => {
  const orgId = BigInt(authUser.orgId);
  const requestedBranchId = input.branchId ? BigInt(input.branchId) : null;
  const teacherBranchId = authUser.role === "TEACHER" && authUser.branchId ? BigInt(authUser.branchId) : null;

  if (requestedBranchId) {
    await ensureBranchBelongsToOrg(orgId, requestedBranchId);
  }

  if (teacherBranchId && requestedBranchId && teacherBranchId !== requestedBranchId) {
    throw new HttpError(403, "Teachers can only access reports for their own branch");
  }

  const branchId = teacherBranchId ?? requestedBranchId;
  let classId: bigint | null = null;

  if (input.classId) {
    classId = BigInt(input.classId);
    const classRecord = await ensureClassBelongsToOrg(orgId, classId);

    if (branchId && classRecord.branchId !== branchId) {
      throw new HttpError(409, "Class and branch filters must belong to the same branch scope");
    }
  }

  return {
    orgId,
    branchId,
    classId,
  };
};

const buildDateRange = (dateFrom?: string, dateTo?: string): Prisma.DateTimeFilter | undefined => {
  const range: Prisma.DateTimeFilter = {};

  if (dateFrom) {
    range.gte = new Date(`${dateFrom}T00:00:00.000Z`);
  }

  if (dateTo) {
    range.lte = new Date(`${dateTo}T23:59:59.999Z`);
  }

  return Object.keys(range).length > 0 ? range : undefined;
};

const escapeCsvValue = (value: string | number | boolean | null | undefined) => {
  const normalized = value == null ? "" : String(value);

  if (/[",\n]/.test(normalized)) {
    return `"${normalized.replace(/"/g, "\"\"")}"`;
  }

  return normalized;
};

const buildCsv = (rows: Array<Array<string | number | boolean | null | undefined>>) =>
  rows.map((row) => row.map(escapeCsvValue).join(",")).join("\n");

const buildStudentWhere = (
  scope: ReportScope,
  extra?: Pick<StudentsExportQuery, "status">,
): Prisma.StudentWhereInput => {
  const where: Prisma.StudentWhereInput = {
    orgId: scope.orgId,
  };

  if (scope.branchId) {
    where.branchId = scope.branchId;
  }

  if (scope.classId) {
    where.classId = scope.classId;
  }

  if (extra?.status) {
    where.status = extra.status;
  }

  return where;
};

const buildAttendanceWhere = (scope: ReportScope, query: DateRangeInput): Prisma.AttendanceRecordWhereInput => {
  const where: Prisma.AttendanceRecordWhereInput = {
    orgId: scope.orgId,
  };

  if (scope.branchId) {
    where.branchId = scope.branchId;
  }

  if (scope.classId) {
    where.classId = scope.classId;
  }

  const range = buildDateRange(query.dateFrom, query.dateTo);

  if (range) {
    where.date = range;
  }

  return where;
};

const buildHifdhWhere = (scope: ReportScope, query: DateRangeInput): Prisma.HifdhProgressWhereInput => {
  const where: Prisma.HifdhProgressWhereInput = {
    orgId: scope.orgId,
  };

  if (scope.branchId || scope.classId) {
    where.student = {};

    if (scope.branchId) {
      where.student.branchId = scope.branchId;
    }

    if (scope.classId) {
      where.student.classId = scope.classId;
    }
  }

  const range = buildDateRange(query.dateFrom, query.dateTo);

  if (range) {
    where.assessedOn = range;
  }

  return where;
};

const buildInvoiceWhere = (scope: ReportScope, query?: DateRangeInput): Prisma.InvoiceWhereInput => {
  const where: Prisma.InvoiceWhereInput = {
    orgId: scope.orgId,
  };

  if (scope.branchId) {
    where.branchId = scope.branchId;
  }

  if (scope.classId) {
    where.student = {
      classId: scope.classId,
    };
  }

  const range = query ? buildDateRange(query.dateFrom, query.dateTo) : undefined;

  if (range) {
    where.createdAt = range;
  }

  return where;
};

const buildExpenseWhere = (scope: ReportScope, query: DateRangeInput): Prisma.ExpenseWhereInput => {
  const where: Prisma.ExpenseWhereInput = {
    orgId: scope.orgId,
  };

  if (scope.branchId) {
    where.branchId = scope.branchId;
  }

  const range = buildDateRange(query.dateFrom, query.dateTo);

  if (range) {
    where.expenseDate = range;
  }

  return where;
};

const buildCompletedPaymentWhere = (scope: ReportScope, query: DateRangeInput): Prisma.PaymentWhereInput => {
  const where: Prisma.PaymentWhereInput = {
    orgId: scope.orgId,
    status: "COMPLETED",
  };

  if (scope.branchId || scope.classId) {
    where.invoice = {};

    if (scope.branchId) {
      where.invoice.branchId = scope.branchId;
    }

    if (scope.classId) {
      where.invoice.student = {
        classId: scope.classId,
      };
    }
  }

  const range = buildDateRange(query.dateFrom, query.dateTo);

  if (range) {
    where.paidAt = range;
  }

  return where;
};

const buildYearRange = (year: number) => ({
  start: new Date(Date.UTC(year, 0, 1, 0, 0, 0, 0)),
  end: new Date(Date.UTC(year, 11, 31, 23, 59, 59, 999)),
});

const MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const buildRecentDateRange = (days: number) => {
  const end = new Date();
  end.setUTCHours(23, 59, 59, 999);

  const start = new Date(end);
  start.setUTCDate(start.getUTCDate() - (days - 1));
  start.setUTCHours(0, 0, 0, 0);

  return { start, end };
};

export const getDashboardReport = async (authUser: AuthenticatedUser, query: DashboardReportQuery) => {
  const scope = await resolveReportScope(authUser, query);
  const studentWhere = buildStudentWhere(scope);
  const attendanceWhere = buildAttendanceWhere(scope, query);
  const hifdhWhere = buildHifdhWhere(scope, query);

  const [
    totalStudents,
    activeStudents,
    inactiveStudents,
    suspendedStudents,
    graduatedStudents,
    totalAttendance,
    presentAttendance,
    absentAttendance,
    lateAttendance,
    excusedAttendance,
    hifdhAggregate,
  ] = await Promise.all([
    prisma.student.count({ where: studentWhere }),
    prisma.student.count({ where: { ...studentWhere, status: "ACTIVE" } }),
    prisma.student.count({ where: { ...studentWhere, status: "INACTIVE" } }),
    prisma.student.count({ where: { ...studentWhere, status: "SUSPENDED" } }),
    prisma.student.count({ where: { ...studentWhere, status: "GRADUATED" } }),
    prisma.attendanceRecord.count({ where: attendanceWhere }),
    prisma.attendanceRecord.count({ where: { ...attendanceWhere, status: "PRESENT" } }),
    prisma.attendanceRecord.count({ where: { ...attendanceWhere, status: "ABSENT" } }),
    prisma.attendanceRecord.count({ where: { ...attendanceWhere, status: "LATE" } }),
    prisma.attendanceRecord.count({ where: { ...attendanceWhere, status: "EXCUSED" } }),
    prisma.hifdhProgress.aggregate({
      where: hifdhWhere,
      _count: {
        _all: true,
      },
      _avg: {
        memorizationScore: true,
        revisionScore: true,
      },
    }),
  ]);

  const attendanceRate = totalAttendance === 0 ? "0.00" : ((presentAttendance / totalAttendance) * 100).toFixed(2);

  let finance:
    | {
        invoices: {
          total: number;
          pending: number;
          paid: number;
          overdue: number;
          amountDue: string;
          amountPaid: string;
          outstandingBalance: string;
        };
        collections: {
          completedPayments: number;
          collectedAmount: string;
        };
        expenses: {
          total: number;
          amount: string;
        };
        netCashFlow: string;
      }
    | null = null;

  if (authUser.role !== "TEACHER") {
    const invoiceWhere = buildInvoiceWhere(scope, query);
    const expenseWhere = buildExpenseWhere(scope, query);
    const completedPaymentWhere = buildCompletedPaymentWhere(scope, query);

    const [
      totalInvoices,
      pendingInvoices,
      paidInvoices,
      overdueInvoices,
      invoiceSums,
      expenseAggregate,
      completedPaymentAggregate,
    ] = await Promise.all([
      prisma.invoice.count({ where: invoiceWhere }),
      prisma.invoice.count({ where: { ...invoiceWhere, status: "PENDING" } }),
      prisma.invoice.count({ where: { ...invoiceWhere, status: "PAID" } }),
      prisma.invoice.count({ where: { ...invoiceWhere, status: "OVERDUE" } }),
      prisma.invoice.aggregate({
        where: invoiceWhere,
        _sum: {
          amountDue: true,
          amountPaid: true,
        },
      }),
      prisma.expense.aggregate({
        where: expenseWhere,
        _count: {
          _all: true,
        },
        _sum: {
          amount: true,
        },
      }),
      prisma.payment.aggregate({
        where: completedPaymentWhere,
        _count: {
          _all: true,
        },
        _sum: {
          amount: true,
        },
      }),
    ]);

    const amountDue = new Prisma.Decimal(invoiceSums._sum.amountDue ?? 0);
    const amountPaid = new Prisma.Decimal(invoiceSums._sum.amountPaid ?? 0);
    const expenseAmount = new Prisma.Decimal(expenseAggregate._sum.amount ?? 0);
    const collectedAmount = new Prisma.Decimal(completedPaymentAggregate._sum.amount ?? 0);

    finance = {
      invoices: {
        total: totalInvoices,
        pending: pendingInvoices,
        paid: paidInvoices,
        overdue: overdueInvoices,
        amountDue: amountDue.toFixed(2),
        amountPaid: amountPaid.toFixed(2),
        outstandingBalance: amountDue.minus(amountPaid).toFixed(2),
      },
      collections: {
        completedPayments: completedPaymentAggregate._count._all,
        collectedAmount: collectedAmount.toFixed(2),
      },
      expenses: {
        total: expenseAggregate._count._all,
        amount: expenseAmount.toFixed(2),
      },
      netCashFlow: collectedAmount.minus(expenseAmount).toFixed(2),
    };
  }

  return {
    filters: {
      branchId: scope.branchId?.toString() ?? null,
      classId: scope.classId?.toString() ?? null,
      dateFrom: query.dateFrom ?? null,
      dateTo: query.dateTo ?? null,
    },
    students: {
      total: totalStudents,
      active: activeStudents,
      inactive: inactiveStudents,
      suspended: suspendedStudents,
      graduated: graduatedStudents,
    },
    attendance: {
      totalRecords: totalAttendance,
      present: presentAttendance,
      absent: absentAttendance,
      late: lateAttendance,
      excused: excusedAttendance,
      attendanceRate,
    },
    hifdh: {
      totalAssessments: hifdhAggregate._count._all,
      averageMemorizationScore: toMoneyString(hifdhAggregate._avg.memorizationScore),
      averageRevisionScore: toMoneyString(hifdhAggregate._avg.revisionScore),
    },
    finance,
  };
};

export const exportStudentsReport = async (authUser: AuthenticatedUser, query: StudentsExportQuery) => {
  const scope = await resolveReportScope(authUser, {
    branchId: query.branchId,
    classId: query.classId,
  });
  const where = buildStudentWhere(scope, query);

  const students = await prisma.student.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      admissionNo: true,
      fullName: true,
      gender: true,
      status: true,
      joinedOn: true,
      branch: {
        select: {
          name: true,
        },
      },
      currentClass: {
        select: {
          name: true,
          academicYear: true,
        },
      },
      primaryGuardian: {
        select: {
          fullName: true,
          phone: true,
        },
      },
      guardians: {
        select: {
          id: true,
        },
      },
    },
  });

  const rows: Array<Array<string | number | boolean | null | undefined>> = [
    [
      "Student ID",
      "Admission No",
      "Full Name",
      "Gender",
      "Status",
      "Branch",
      "Class",
      "Academic Year",
      "Joined On",
      "Primary Guardian",
      "Guardian Phone",
      "Guardian Count",
    ],
    ...students.map((student) => [
      student.id.toString(),
      student.admissionNo,
      student.fullName,
      student.gender,
      student.status,
      student.branch.name,
      student.currentClass?.name ?? "",
      student.currentClass?.academicYear ?? "",
      toDateOnly(student.joinedOn),
      student.primaryGuardian.fullName,
      student.primaryGuardian.phone,
      student.guardians.length,
    ]),
  ];

  const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");

  return {
    fileName: `students-report-${stamp}.csv`,
    contentType: "text/csv; charset=utf-8",
    content: buildCsv(rows),
  };
};

export const exportPaymentsReport = async (authUser: AuthenticatedUser, query: PaymentsExportQuery) => {
  const scope = await resolveReportScope(authUser, query);
  const where: Prisma.PaymentWhereInput = {
    orgId: scope.orgId,
  };

  if (query.status) {
    where.status = query.status;
  }

  const range = buildDateRange(query.dateFrom, query.dateTo);

  if (range) {
    where.createdAt = range;
  }

  if (scope.branchId || scope.classId) {
    where.invoice = {};

    if (scope.branchId) {
      where.invoice.branchId = scope.branchId;
    }

    if (scope.classId) {
      where.invoice.student = {
        classId: scope.classId,
      };
    }
  }

  const payments = await prisma.payment.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      reference: true,
      externalReference: true,
      providerTxnRef: true,
      amount: true,
      currency: true,
      status: true,
      channel: true,
      paymentType: true,
      createdAt: true,
      paidAt: true,
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          branch: {
            select: {
              name: true,
            },
          },
          student: {
            select: {
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  const rows: Array<Array<string | number | boolean | null | undefined>> = [
    [
      "Payment ID",
      "Invoice No",
      "Student Name",
      "Admission No",
      "Branch",
      "Amount",
      "Currency",
      "Status",
      "Channel",
      "Payment Type",
      "Reference",
      "External Reference",
      "Provider Txn Ref",
      "Created At",
      "Paid At",
    ],
    ...payments.map((payment) => [
      payment.id.toString(),
      payment.invoice.invoiceNo,
      payment.invoice.student.fullName,
      payment.invoice.student.admissionNo,
      payment.invoice.branch?.name ?? "",
      toMoneyString(payment.amount),
      payment.currency,
      payment.status,
      payment.channel ?? "",
      payment.paymentType,
      payment.reference ?? "",
      payment.externalReference ?? "",
      payment.providerTxnRef ?? "",
      payment.createdAt.toISOString(),
      payment.paidAt?.toISOString() ?? "",
    ]),
  ];

  const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");

  return {
    fileName: `payments-report-${stamp}.csv`,
    contentType: "text/csv; charset=utf-8",
    content: buildCsv(rows),
  };
};

export const exportAttendanceReport = async (authUser: AuthenticatedUser, query: AttendanceExportQuery) => {
  const scope = await resolveReportScope(authUser, query);
  const where = buildAttendanceWhere(scope, query);

  if (query.status) {
    where.status = query.status;
  }

  if (authUser.role === "TEACHER") {
    where.class = {
      teacherId: BigInt(authUser.userId),
    };
  }

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "desc" }, { classId: "asc" }, { studentId: "asc" }],
    select: {
      id: true,
      date: true,
      status: true,
      reason: true,
      branch: {
        select: {
          name: true,
        },
      },
      class: {
        select: {
          name: true,
          level: true,
          academicYear: true,
        },
      },
      student: {
        select: {
          fullName: true,
          admissionNo: true,
        },
      },
      markedBy: {
        select: {
          fullName: true,
          role: true,
        },
      },
    },
  });

  const rows: Array<Array<string | number | boolean | null | undefined>> = [
    [
      "Attendance ID",
      "Date",
      "Branch",
      "Class",
      "Level",
      "Academic Year",
      "Student Name",
      "Admission No",
      "Status",
      "Reason",
      "Marked By",
      "Marked By Role",
    ],
    ...records.map((record) => [
      record.id.toString(),
      toDateOnly(record.date),
      record.branch.name,
      record.class.name,
      record.class.level,
      record.class.academicYear,
      record.student.fullName,
      record.student.admissionNo,
      record.status,
      record.reason ?? "",
      record.markedBy.fullName,
      record.markedBy.role,
    ]),
  ];

  const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");

  return {
    fileName: `attendance-report-${stamp}.csv`,
    contentType: "text/csv; charset=utf-8",
    content: buildCsv(rows),
  };
};

export const getMonthlyFinanceSummaryReport = async (
  authUser: AuthenticatedUser,
  query: MonthlyFinanceSummaryQuery,
) => {
  const scope = await resolveReportScope(authUser, query);
  const year = query.year ?? new Date().getUTCFullYear();
  const yearRange = buildYearRange(year);

  const invoiceWhere = buildInvoiceWhere(scope);
  invoiceWhere.issuedAt = {
    gte: yearRange.start,
    lte: yearRange.end,
  };

  const expenseWhere = buildExpenseWhere(scope, {});
  expenseWhere.expenseDate = {
    gte: yearRange.start,
    lte: yearRange.end,
  };

  const paymentWhere = buildCompletedPaymentWhere(scope, {});
  paymentWhere.paidAt = {
    gte: yearRange.start,
    lte: yearRange.end,
  };

  const [invoices, completedPayments, expenses] = await Promise.all([
    prisma.invoice.findMany({
      where: invoiceWhere,
      select: {
        amountDue: true,
        amountPaid: true,
        issuedAt: true,
      },
    }),
    prisma.payment.findMany({
      where: paymentWhere,
      select: {
        amount: true,
        paidAt: true,
      },
    }),
    prisma.expense.findMany({
      where: expenseWhere,
      select: {
        amount: true,
        expenseDate: true,
      },
    }),
  ]);

  const months = MONTH_LABELS.map((label, index) => ({
    month: index + 1,
    label,
    invoicesIssued: 0,
    invoicedAmount: new Prisma.Decimal(0),
    paymentsCollected: 0,
    collectedAmount: new Prisma.Decimal(0),
    expensesRecorded: 0,
    expenseAmount: new Prisma.Decimal(0),
  }));

  for (const invoice of invoices) {
    const monthIndex = invoice.issuedAt.getUTCMonth();
    months[monthIndex]!.invoicesIssued += 1;
    months[monthIndex]!.invoicedAmount = months[monthIndex]!.invoicedAmount.plus(invoice.amountDue);
  }

  for (const payment of completedPayments) {
    if (!payment.paidAt) {
      continue;
    }

    const monthIndex = payment.paidAt.getUTCMonth();
    months[monthIndex]!.paymentsCollected += 1;
    months[monthIndex]!.collectedAmount = months[monthIndex]!.collectedAmount.plus(payment.amount);
  }

  for (const expense of expenses) {
    const monthIndex = expense.expenseDate.getUTCMonth();
    months[monthIndex]!.expensesRecorded += 1;
    months[monthIndex]!.expenseAmount = months[monthIndex]!.expenseAmount.plus(expense.amount);
  }

  const totalInvoiced = months.reduce((sum, month) => sum.plus(month.invoicedAmount), new Prisma.Decimal(0));
  const totalCollected = months.reduce((sum, month) => sum.plus(month.collectedAmount), new Prisma.Decimal(0));
  const totalExpenses = months.reduce((sum, month) => sum.plus(month.expenseAmount), new Prisma.Decimal(0));

  return {
    year,
    filters: {
      branchId: scope.branchId?.toString() ?? null,
      classId: scope.classId?.toString() ?? null,
    },
    totals: {
      invoicesIssued: invoices.length,
      invoicedAmount: totalInvoiced.toFixed(2),
      paymentsCollected: completedPayments.length,
      collectedAmount: totalCollected.toFixed(2),
      expensesRecorded: expenses.length,
      expenseAmount: totalExpenses.toFixed(2),
      outstandingBalance: totalInvoiced.minus(totalCollected).toFixed(2),
      netCashFlow: totalCollected.minus(totalExpenses).toFixed(2),
    },
    months: months.map((month) => ({
      month: month.month,
      label: month.label,
      invoicesIssued: month.invoicesIssued,
      invoicedAmount: month.invoicedAmount.toFixed(2),
      paymentsCollected: month.paymentsCollected,
      collectedAmount: month.collectedAmount.toFixed(2),
      expensesRecorded: month.expensesRecorded,
      expenseAmount: month.expenseAmount.toFixed(2),
      outstandingBalance: month.invoicedAmount.minus(month.collectedAmount).toFixed(2),
      netCashFlow: month.collectedAmount.minus(month.expenseAmount).toFixed(2),
    })),
  };
};

export const exportMonthlyFinanceSummaryReport = async (
  authUser: AuthenticatedUser,
  query: MonthlyFinanceSummaryQuery,
) => {
  const report = await getMonthlyFinanceSummaryReport(authUser, query);

  const rows: Array<Array<string | number | boolean | null | undefined>> = [
    [
      "Month",
      "Invoices Issued",
      "Invoiced Amount",
      "Payments Collected",
      "Collected Amount",
      "Expenses Recorded",
      "Expense Amount",
      "Outstanding Balance",
      "Net Cash Flow",
    ],
    ...report.months.map((month) => [
      month.label,
      month.invoicesIssued,
      month.invoicedAmount,
      month.paymentsCollected,
      month.collectedAmount,
      month.expensesRecorded,
      month.expenseAmount,
      month.outstandingBalance,
      month.netCashFlow,
    ]),
    [],
    [
      "TOTAL",
      report.totals.invoicesIssued,
      report.totals.invoicedAmount,
      report.totals.paymentsCollected,
      report.totals.collectedAmount,
      report.totals.expensesRecorded,
      report.totals.expenseAmount,
      report.totals.outstandingBalance,
      report.totals.netCashFlow,
    ],
  ];

  return {
    fileName: `finance-monthly-summary-${report.year}.csv`,
    contentType: "text/csv; charset=utf-8",
    content: buildCsv(rows),
  };
};

export const getAttendanceSummaryReport = async (
  authUser: AuthenticatedUser,
  query: AttendanceSummaryQuery,
) => {
  const scope = await resolveReportScope(authUser, query);
  const normalizedQuery: DateRangeInput = {
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
  };

  if (!normalizedQuery.dateFrom && !normalizedQuery.dateTo) {
    const recent = buildRecentDateRange(7);
    normalizedQuery.dateFrom = recent.start.toISOString().slice(0, 10);
    normalizedQuery.dateTo = recent.end.toISOString().slice(0, 10);
  }

  const where = buildAttendanceWhere(scope, normalizedQuery);

  if (authUser.role === "TEACHER") {
    where.class = {
      teacherId: BigInt(authUser.userId),
    };
  }

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "asc" }, { classId: "asc" }, { studentId: "asc" }],
    select: {
      date: true,
      status: true,
    },
  });

  const totals = {
    totalRecords: 0,
    present: 0,
    absent: 0,
    late: 0,
    excused: 0,
  };

  const timelineMap = new Map<
    string,
    {
      date: string;
      totalRecords: number;
      present: number;
      absent: number;
      late: number;
      excused: number;
    }
  >();

  for (const record of records) {
    const dateKey = toDateOnly(record.date);

    if (!timelineMap.has(dateKey)) {
      timelineMap.set(dateKey, {
        date: dateKey,
        totalRecords: 0,
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
      });
    }

    const bucket = timelineMap.get(dateKey)!;
    bucket.totalRecords += 1;
    totals.totalRecords += 1;

    switch (record.status) {
      case "PRESENT":
        bucket.present += 1;
        totals.present += 1;
        break;
      case "ABSENT":
        bucket.absent += 1;
        totals.absent += 1;
        break;
      case "LATE":
        bucket.late += 1;
        totals.late += 1;
        break;
      case "EXCUSED":
        bucket.excused += 1;
        totals.excused += 1;
        break;
      default:
        break;
    }
  }

  const attendanceRate =
    totals.totalRecords === 0 ? "0.00" : ((totals.present / totals.totalRecords) * 100).toFixed(2);

  return {
    filters: {
      branchId: scope.branchId?.toString() ?? null,
      classId: scope.classId?.toString() ?? null,
      dateFrom: normalizedQuery.dateFrom ?? null,
      dateTo: normalizedQuery.dateTo ?? null,
    },
    totals: {
      ...totals,
      attendanceRate,
    },
    timeline: Array.from(timelineMap.values()),
  };
};

export const getTeacherDashboardReport = async (
  authUser: AuthenticatedUser,
  query: TeacherDashboardQuery,
) => {
  const orgId = BigInt(authUser.orgId);
  const requestedTeacherId = query.teacherId ? BigInt(query.teacherId) : null;

  if (authUser.role === "TEACHER" && requestedTeacherId && requestedTeacherId !== BigInt(authUser.userId)) {
    throw new HttpError(403, "Teachers can only access their own dashboard");
  }

  if (authUser.role === "ADMIN" && !requestedTeacherId) {
    throw new HttpError(422, "teacherId is required when an admin requests a teacher dashboard");
  }

  const teacherId = authUser.role === "TEACHER" ? BigInt(authUser.userId) : requestedTeacherId!;
  const teacher = await ensureTeacherBelongsToOrg(orgId, teacherId);
  const effectiveBranchId = authUser.role === "TEACHER" && authUser.branchId ? BigInt(authUser.branchId) : teacher.branchId;
  const selectedDate = query.date ? new Date(`${query.date}T00:00:00.000Z`) : new Date();
  selectedDate.setUTCHours(0, 0, 0, 0);

  const weekStart = new Date(selectedDate);
  weekStart.setUTCDate(weekStart.getUTCDate() - 6);

  const classWhere: Prisma.ClassWhereInput = {
    orgId,
    teacherId,
  };

  if (effectiveBranchId) {
    classWhere.branchId = effectiveBranchId;
  }

  const assignedClasses = await prisma.class.findMany({
    where: classWhere,
    orderBy: [{ academicYear: "desc" }, { name: "asc" }],
    select: {
      id: true,
      name: true,
      level: true,
      academicYear: true,
      capacity: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      _count: {
        select: {
          currentStudents: true,
        },
      },
    },
  });

  const classIds = assignedClasses.map((classRecord) => classRecord.id);

  const [attendanceToday, recentHifdh, hifdhThisWeekCount] = await Promise.all([
    classIds.length === 0
      ? Promise.resolve([] as Array<{ classId: bigint }>)
      : prisma.attendanceRecord.findMany({
          where: {
            orgId,
            classId: {
              in: classIds,
            },
            date: selectedDate,
          },
          select: {
            classId: true,
          },
        }),
    prisma.hifdhProgress.findMany({
      where: {
        orgId,
        teacherId,
        assessedOn: {
          gte: weekStart,
          lte: new Date(`${selectedDate.toISOString().slice(0, 10)}T23:59:59.999Z`),
        },
      },
      orderBy: [{ assessedOn: "desc" }, { createdAt: "desc" }],
      take: 5,
      select: {
        id: true,
        assessedOn: true,
        juzNumber: true,
        surahName: true,
        memorizationScore: true,
        revisionScore: true,
        student: {
          select: {
            id: true,
            fullName: true,
            admissionNo: true,
          },
        },
      },
    }),
    prisma.hifdhProgress.count({
      where: {
        orgId,
        teacherId,
        assessedOn: {
          gte: weekStart,
          lte: new Date(`${selectedDate.toISOString().slice(0, 10)}T23:59:59.999Z`),
        },
      },
    }),
  ]);

  const attendanceCountByClass = new Map<string, number>();

  for (const record of attendanceToday) {
    const key = record.classId.toString();
    attendanceCountByClass.set(key, (attendanceCountByClass.get(key) ?? 0) + 1);
  }

  const classes = assignedClasses.map((classRecord) => {
    const markedToday = attendanceCountByClass.get(classRecord.id.toString()) ?? 0;
    const currentStudents = classRecord._count.currentStudents;

    return {
      id: classRecord.id.toString(),
      name: classRecord.name,
      level: classRecord.level,
      academicYear: classRecord.academicYear,
      capacity: classRecord.capacity,
      branch: {
        id: classRecord.branch.id.toString(),
        name: classRecord.branch.name,
      },
      stats: {
        currentStudents,
        attendanceMarkedToday: markedToday,
        attendancePendingToday: Math.max(currentStudents - markedToday, 0),
      },
    };
  });

  return {
    teacher: {
      id: teacher.id.toString(),
      fullName: teacher.fullName,
      branchId: effectiveBranchId?.toString() ?? null,
    },
    date: selectedDate.toISOString().slice(0, 10),
    summary: {
      assignedClasses: assignedClasses.length,
      assignedStudents: classes.reduce((sum, classRecord) => sum + classRecord.stats.currentStudents, 0),
      attendanceMarkedToday: attendanceToday.length,
      hifdhAssessmentsThisWeek: hifdhThisWeekCount,
    },
    classes,
    recentHifdh: recentHifdh.map((record) => ({
      id: record.id.toString(),
      assessedOn: record.assessedOn.toISOString().slice(0, 10),
      juzNumber: record.juzNumber,
      surahName: record.surahName,
      memorizationScore: toMoneyString(record.memorizationScore),
      revisionScore: toMoneyString(record.revisionScore),
      student: {
        id: record.student.id.toString(),
        fullName: record.student.fullName,
        admissionNo: record.student.admissionNo,
      },
    })),
  };
};
