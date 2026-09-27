import { z } from "zod";
import { assessmentId } from "../assessments/assessments.schemas";
export { assessmentId as reportId };
const date = z.string().regex(/^20\d{2}-\d{2}-\d{2}$/).refine(v => {
  const d = new Date(v); return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
});
export const periodInput = z.object({ clientId: z.string().uuid(), name: z.string().trim().min(2).max(150),
  startsOn: date, endsOn: date }).strict().refine(v => v.endsOn >= v.startsOn &&
    new Date(v.endsOn).getTime() - new Date(v.startsOn).getTime() <= 366 * 86400000,
  "Choose a period of up to one year, with the end after the start");
export const prepareInput = z.object({ periodId: assessmentId, studentId: assessmentId }).strict();
export const saveInput = z.object({ revision: z.number().int().positive(), feedback: z.string().trim().max(2000) }).strict();
export const listQuery = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1),
  periodId: assessmentId.optional(), classId: assessmentId.optional(),
  status: z.enum(["DRAFT", "SUBMITTED", "PUBLISHED"]).optional() }).strict();
export const pageQuery = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1) }).strict();
export const rosterQuery = z.object({ classId: assessmentId }).strict();
