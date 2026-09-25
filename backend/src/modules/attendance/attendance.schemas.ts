import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");

export const attendanceStatusSchema = z.enum(["PRESENT", "ABSENT", "LATE", "EXCUSED"]);

export const bulkAttendanceRecordSchema = z.object({
  studentId: numericId,
  status: attendanceStatusSchema,
  reason: z.string().max(255, "reason must not exceed 255 characters").optional(),
});

export const bulkMarkAttendanceSchema = z.object({
  classId: numericId,
  date: z.string().date(),
  records: z.array(bulkAttendanceRecordSchema).min(1, "records must contain at least one item").max(1000),
});

export const classAttendanceQuerySchema = z.object({
  date: z.string().date().optional(),
});

export const studentAttendanceQuerySchema = z.object({
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
});

export type BulkMarkAttendanceInput = z.infer<typeof bulkMarkAttendanceSchema>;
export type ClassAttendanceQuery = z.infer<typeof classAttendanceQuerySchema>;
export type StudentAttendanceQuery = z.infer<typeof studentAttendanceQuerySchema>;
