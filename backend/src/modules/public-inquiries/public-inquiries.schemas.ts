import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "branchId must be a numeric string");

export const createPublicInquirySchema = z.object({
  inquiryType: z.enum(["GENERAL", "ADMISSIONS", "PARENT_SUPPORT", "FINANCE"]),
  fullName: z.string().min(2, "fullName must be at least 2 characters").max(150, "fullName is too long"),
  phone: z.string().min(8, "phone must be at least 8 characters").max(30, "phone is too long"),
  email: z.string().email("email must be valid").max(150, "email is too long").optional().or(z.literal("")),
  subject: z.string().min(4, "subject must be at least 4 characters").max(160, "subject is too long"),
  message: z.string().min(10, "message must be at least 10 characters").max(5000, "message is too long"),
  preferredContact: z.enum(["phone", "email"]).optional(),
  sourcePage: z.enum(["home", "admissions", "contact", "news", "programs", "login", "parent-access", "forgot-password"]),
  branchId: numericId.optional(),
});

export const listPublicInquiriesQuerySchema = z.object({
  branchId: numericId.optional(),
  inquiryType: z.enum(["GENERAL", "ADMISSIONS", "PARENT_SUPPORT", "FINANCE"]).optional(),
  status: z.enum(["NEW", "CONTACTED", "CLOSED"]).optional(),
  search: z.string().trim().min(1).max(150).optional(),
});

export const publicInquiryParamsSchema = z.object({
  id: z.string().regex(/^\d+$/, "id must be a numeric string"),
});

export const updatePublicInquiryStatusSchema = z.object({
  status: z.enum(["NEW", "CONTACTED", "CLOSED"]),
});

export type CreatePublicInquiryInput = z.infer<typeof createPublicInquirySchema>;
export type ListPublicInquiriesQuery = z.infer<typeof listPublicInquiriesQuerySchema>;
export type UpdatePublicInquiryStatusInput = z.infer<typeof updatePublicInquiryStatusSchema>;
