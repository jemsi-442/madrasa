import { z } from "zod";
export const assessmentId = z.string().regex(/^[1-9]\d{0,18}$/)
  .refine(v => /^[1-9]\d{0,18}$/.test(v) && BigInt(v) <= 9223372036854775807n);
const date = z.string().regex(/^20\d{2}-\d{2}-\d{2}$/).refine(v => {
  const d = new Date(v); return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
});
export const createAssessmentInput = z.object({
  clientId: z.string().uuid(), classId: assessmentId, subjectId: assessmentId,
  title: z.string().trim().min(2).max(150), assessedOn: date,
  maxScore: z.number().int().min(1).max(1000),
}).strict();
export const assessmentQuery = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  classId: assessmentId.optional(),
  status: z.enum(["DRAFT", "SUBMITTED", "PUBLISHED"]).optional(),
}).strict();
export const resultsInput = z.object({
  revision: z.number().int().positive(),
  results: z.array(z.object({
    studentId: assessmentId, score: z.number().int().min(0).max(1000).nullable(),
    feedback: z.string().trim().max(500),
  }).strict()).min(1).max(500),
}).strict().refine(v => new Set(v.results.map(r => r.studentId)).size === v.results.length,
  "Each student must appear once");
export const transitionInput = z.object({
  revision: z.number().int().positive(),
  action: z.enum(["submit", "return", "publish", "retract"]),
  reason: z.string().trim().min(3).max(500).optional(),
}).strict().refine(v => !["return", "retract"].includes(v.action) || !!v.reason,
  "A reason is required");
export const academicQuery = z.object({
  year: z.coerce.number().int().min(2000).max(2099),
}).strict();
