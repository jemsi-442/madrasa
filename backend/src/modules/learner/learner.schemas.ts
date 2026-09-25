import { z } from "zod";

export const learnerAttendanceQuerySchema = z.object({
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
});

export type LearnerAttendanceQuery = z.infer<typeof learnerAttendanceQuerySchema>;

export const initiateLearnerCoursePaymentSchema = z.object({
  payerPhone: z.string().min(10, "payerPhone must be at least 10 characters"),
  channel: z.enum(["mpesa", "airtel_money", "tigo_pesa"]).default("mpesa"),
});

export type InitiateLearnerCoursePaymentInput = z.infer<typeof initiateLearnerCoursePaymentSchema>;

export const updateLearnerLessonProgressSchema = z.object({
  progressPercent: z
    .number({ invalid_type_error: "progressPercent must be a number" })
    .int("progressPercent must be a whole number")
    .min(0, "progressPercent must be at least 0")
    .max(100, "progressPercent cannot exceed 100"),
  watchSeconds: z
    .number({ invalid_type_error: "watchSeconds must be a number" })
    .int("watchSeconds must be a whole number")
    .min(0, "watchSeconds cannot be negative")
    .optional(),
  markCompleted: z.boolean().optional(),
});

export type UpdateLearnerLessonProgressInput = z.infer<typeof updateLearnerLessonProgressSchema>;
