import { z } from "zod";
import { attendanceStatusSchema } from "./attendance.schemas";

const id = z.string().regex(/^[1-9]\d{0,17}$/, "Choose a valid record");
export const registerQuerySchema = z.object({
  classId: id,
  date: z.string().date(),
}).strict();

export const registerSaveSchema = registerQuerySchema.extend({
  correctionReason: z.string().trim().min(5).max(255).optional(),
  records: z.array(z.object({
    studentId: id,
    version: z.number().int().min(0).max(2147483646),
    status: attendanceStatusSchema,
    reason: z.string().trim().max(255).nullable().optional(),
    checkInTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).nullable().optional(),
  }).strict()).min(1).max(1000),
}).superRefine((input, ctx) => {
  const seen = new Set<string>();
  input.records.forEach((row, index) => {
    if (seen.has(row.studentId)) ctx.addIssue({
      code: z.ZodIssueCode.custom, path: ["records", index, "studentId"],
      message: "A student can appear only once",
    });
    seen.add(row.studentId);
    if (row.checkInTime && !["PRESENT", "LATE"].includes(row.status)) ctx.addIssue({
      code: z.ZodIssueCode.custom, path: ["records", index, "checkInTime"],
      message: "Only present or late students can have a check-in time",
    });
  });
});

export type RegisterQuery = z.infer<typeof registerQuerySchema>;
export type RegisterSave = z.infer<typeof registerSaveSchema>;
