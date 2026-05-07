import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");
const dateString = z.string().date();

const dateRangeFields = {
  dateFrom: dateString.optional(),
  dateTo: dateString.optional(),
};

const applyDateRangeValidation = (
  value: { dateFrom?: string | undefined; dateTo?: string | undefined },
  ctx: z.RefinementCtx,
) => {
    if (value.dateFrom && value.dateTo && value.dateFrom > value.dateTo) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["dateFrom"],
        message: "dateFrom must be less than or equal to dateTo",
      });
    }
};

export const dashboardReportQuerySchema = z
  .object({
    ...dateRangeFields,
    branchId: numericId.optional(),
    classId: numericId.optional(),
  })
  .superRefine(applyDateRangeValidation);

export const studentsExportQuerySchema = z.object({
  branchId: numericId.optional(),
  classId: numericId.optional(),
  status: z.enum(["ACTIVE", "INACTIVE", "SUSPENDED", "GRADUATED"]).optional(),
});

export const paymentsExportQuerySchema = z
  .object({
    ...dateRangeFields,
    branchId: numericId.optional(),
    classId: numericId.optional(),
    status: z.enum(["PENDING", "COMPLETED", "FAILED", "VOIDED", "EXPIRED"]).optional(),
  })
  .superRefine(applyDateRangeValidation);

export const attendanceExportQuerySchema = z
  .object({
    ...dateRangeFields,
    branchId: numericId.optional(),
    classId: numericId.optional(),
    status: z.enum(["PRESENT", "ABSENT", "LATE", "EXCUSED"]).optional(),
  })
  .superRefine(applyDateRangeValidation);

export const attendanceSummaryQuerySchema = z
  .object({
    ...dateRangeFields,
    branchId: numericId.optional(),
    classId: numericId.optional(),
  })
  .superRefine(applyDateRangeValidation);

export const monthlyFinanceSummaryQuerySchema = z.object({
  branchId: numericId.optional(),
  classId: numericId.optional(),
  year: z.coerce.number().int().min(2000).max(2100).optional(),
});

export const teacherDashboardQuerySchema = z.object({
  teacherId: numericId.optional(),
  date: dateString.optional(),
});

export type DashboardReportQuery = z.infer<typeof dashboardReportQuerySchema>;
export type StudentsExportQuery = z.infer<typeof studentsExportQuerySchema>;
export type PaymentsExportQuery = z.infer<typeof paymentsExportQuerySchema>;
export type AttendanceExportQuery = z.infer<typeof attendanceExportQuerySchema>;
export type AttendanceSummaryQuery = z.infer<typeof attendanceSummaryQuerySchema>;
export type MonthlyFinanceSummaryQuery = z.infer<typeof monthlyFinanceSummaryQuerySchema>;
export type TeacherDashboardQuery = z.infer<typeof teacherDashboardQuerySchema>;
