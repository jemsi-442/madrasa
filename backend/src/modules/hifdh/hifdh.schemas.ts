import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");
const scoreString = z
  .string()
  .regex(/^\d+(\.\d{1,2})?$/, "score must be a valid decimal string")
  .refine((value) => Number(value) >= 0 && Number(value) <= 100, "score must be between 0 and 100");

export const createHifdhProgressSchema = z
  .object({
    studentId: numericId,
    teacherId: numericId.optional(),
    juzNumber: z.coerce.number().int().min(1).max(30),
    surahName: z.string().min(2, "surahName must be at least 2 characters").max(100),
    ayahFrom: z.coerce.number().int().positive().optional(),
    ayahTo: z.coerce.number().int().positive().optional(),
    memorizationScore: scoreString,
    revisionScore: scoreString.optional(),
    remarks: z.string().max(5000, "remarks must not exceed 5000 characters").optional(),
    assessedOn: z.string().date(),
  })
  .superRefine((value, ctx) => {
    if (value.ayahFrom && value.ayahTo && value.ayahTo < value.ayahFrom) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["ayahTo"],
        message: "ayahTo must be greater than or equal to ayahFrom",
      });
    }
  });

export const listHifdhProgressQuerySchema = z.object({
  studentId: numericId.optional(),
  teacherId: numericId.optional(),
  juzNumber: z.coerce.number().int().min(1).max(30).optional(),
  dateFrom: z.string().date().optional(),
  dateTo: z.string().date().optional(),
});

export const hifdhProgressParamsSchema = z.object({
  id: numericId,
});

export type CreateHifdhProgressInput = z.infer<typeof createHifdhProgressSchema>;
export type ListHifdhProgressQuery = z.infer<typeof listHifdhProgressQuerySchema>;
