import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");

export const initiatePaymentSchema = z.object({
  invoiceId: numericId,
  payerPhone: z.string().min(10, "payerPhone must be at least 10 characters"),
  channel: z.enum(["mpesa", "airtel_money", "tigo_pesa"]).default("mpesa"),
  customer: z.object({
    firstname: z.string().min(2, "firstname must be at least 2 characters"),
    lastname: z.string().min(2, "lastname must be at least 2 characters"),
    email: z.string().email("email must be valid").optional(),
  }),
});

export const listPaymentsQuerySchema = z.object({
  invoiceId: numericId.optional(),
  studentId: numericId.optional(),
  status: z.enum(["PENDING", "COMPLETED", "FAILED", "VOIDED", "EXPIRED"]).optional(),
  channel: z.enum(["mpesa", "airtel_money", "tigo_pesa"]).optional(),
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
});

export type InitiatePaymentInput = z.infer<typeof initiatePaymentSchema>;
export type ListPaymentsQuery = z.infer<typeof listPaymentsQuerySchema>;
