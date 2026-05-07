import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");
const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(10),
});

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

export const listPaymentsQuerySchema = paginationSchema.extend({
  invoiceId: numericId.optional(),
  studentId: numericId.optional(),
  branchId: numericId.optional(),
  status: z.enum(["PENDING", "COMPLETED", "FAILED", "VOIDED", "EXPIRED"]).optional(),
  channel: z.enum(["mpesa", "airtel_money", "tigo_pesa"]).optional(),
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
  search: z.string().min(1).max(100).optional(),
});

export type InitiatePaymentInput = z.infer<typeof initiatePaymentSchema>;
export type ListPaymentsQuery = z.infer<typeof listPaymentsQuerySchema>;
