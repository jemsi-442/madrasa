import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "branchId must be a numeric string");

export const createAnnouncementSchema = z
  .object({
    title: z.string().min(2, "title must be at least 2 characters").max(150, "title is too long"),
    message: z.string().min(5, "message must be at least 5 characters"),
    audience: z.enum(["ALL", "PARENTS", "TEACHERS", "ACCOUNTANTS"]),
    publishAt: z.string().datetime({ offset: true }),
    expiresAt: z.string().datetime({ offset: true }).optional(),
    branchId: numericId.optional(),
  })
  .superRefine((value, ctx) => {
    if (value.expiresAt && new Date(value.expiresAt) <= new Date(value.publishAt)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["expiresAt"],
        message: "expiresAt must be later than publishAt",
      });
    }
  });

export const listAnnouncementsQuerySchema = z.object({
  branchId: numericId.optional(),
  audience: z.enum(["ALL", "PARENTS", "TEACHERS", "ACCOUNTANTS"]).optional(),
  activeOnly: z
    .enum(["true", "false"])
    .transform((value) => value === "true")
    .optional(),
});

export const listPublicAnnouncementsQuerySchema = z.object({
  branchId: numericId.optional(),
  limit: z
    .string()
    .regex(/^\d+$/, "limit must be a numeric string")
    .transform((value) => Number(value))
    .refine((value) => value >= 1 && value <= 12, "limit must be between 1 and 12")
    .optional(),
});

export const announcementParamsSchema = z.object({
  id: z.string().regex(/^\d+$/, "id must be a numeric string"),
});

export type CreateAnnouncementInput = z.infer<typeof createAnnouncementSchema>;
export type ListAnnouncementsQuery = z.infer<typeof listAnnouncementsQuerySchema>;
export type ListPublicAnnouncementsQuery = z.infer<typeof listPublicAnnouncementsQuerySchema>;
