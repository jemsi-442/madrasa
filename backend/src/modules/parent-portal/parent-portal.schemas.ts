import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "studentId must be a numeric string");
const amountChannel = z.enum(["mpesa", "airtel_money", "tigo_pesa"]);

export const parentStudentAttendanceQuerySchema = z.object({
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
  parentUserId: z.string().regex(/^\d+$/, "parentUserId must be a numeric string").optional(),
});

export const parentPortalActorQuerySchema = z.object({
  parentUserId: z.string().regex(/^\d+$/, "parentUserId must be a numeric string").optional(),
});

export const parentStudentParamsSchema = z.object({
  studentId: numericId,
});

export const parentPaymentParamsSchema = z.object({
  studentId: numericId,
  paymentId: z.string().regex(/^\d+$/, "paymentId must be a numeric string"),
});

export const initiateParentPaymentSchema = z.object({
  invoiceId: numericId,
  payerPhone: z.string().min(10, "payerPhone must be at least 10 characters"),
  channel: amountChannel.default("mpesa"),
});

export type ParentStudentAttendanceQuery = z.infer<typeof parentStudentAttendanceQuerySchema>;
export type ParentStudentParams = z.infer<typeof parentStudentParamsSchema>;
export type ParentPaymentParams = z.infer<typeof parentPaymentParamsSchema>;
export type InitiateParentPaymentInput = z.infer<typeof initiateParentPaymentSchema>;
