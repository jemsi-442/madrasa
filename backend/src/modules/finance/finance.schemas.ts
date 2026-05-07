import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");
const amountString = z.string().regex(/^\d+(\.\d{1,2})?$/, "amount must be a valid decimal string");
const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(10),
});

export const createFeeStructureSchema = z.object({
  name: z.string().min(2, "name must be at least 2 characters"),
  amount: amountString,
  billingCycle: z.enum(["ONE_TIME", "MONTHLY", "TERMLY"]),
  branchId: numericId.optional(),
  classId: numericId.optional(),
  isActive: z.boolean().optional(),
});

export const listFeeStructuresQuerySchema = paginationSchema.extend({
  branchId: numericId.optional(),
  classId: numericId.optional(),
  isActive: z
    .enum(["true", "false"])
    .transform((value) => value === "true")
    .optional(),
  search: z.string().min(1).max(100).optional(),
});

export const createInvoiceSchema = z.object({
  studentId: numericId,
  feeStructureId: numericId.optional(),
  amountDue: amountString.optional(),
  dueDate: z.string().date(),
  currency: z.literal("TZS").optional(),
});

export const listInvoicesQuerySchema = paginationSchema.extend({
  studentId: numericId.optional(),
  branchId: numericId.optional(),
  status: z.enum(["PENDING", "PARTIALLY_PAID", "PAID", "OVERDUE", "CANCELLED"]).optional(),
  search: z.string().min(1).max(100).optional(),
});

export const createExpenseSchema = z.object({
  title: z.string().min(2, "title must be at least 2 characters"),
  description: z.string().optional(),
  amount: amountString,
  expenseDate: z.string().date(),
  branchId: numericId.optional(),
  currency: z.literal("TZS").optional(),
});

export const listExpensesQuerySchema = paginationSchema.extend({
  branchId: numericId.optional(),
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
  search: z.string().min(1).max(100).optional(),
});

export type CreateFeeStructureInput = z.infer<typeof createFeeStructureSchema>;
export type ListFeeStructuresQuery = z.infer<typeof listFeeStructuresQuerySchema>;
export type CreateInvoiceInput = z.infer<typeof createInvoiceSchema>;
export type ListInvoicesQuery = z.infer<typeof listInvoicesQuerySchema>;
export type CreateExpenseInput = z.infer<typeof createExpenseSchema>;
export type ListExpensesQuery = z.infer<typeof listExpensesQuerySchema>;
