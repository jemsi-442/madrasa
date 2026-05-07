import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");

export const createClassSchema = z.object({
  branchId: numericId,
  name: z.string().min(2, "name must be at least 2 characters"),
  level: z.string().min(2, "level must be at least 2 characters"),
  academicYear: z.string().min(4, "academicYear must be at least 4 characters"),
  teacherId: numericId.optional(),
  capacity: z.number().int().positive().optional(),
});

export const listClassesQuerySchema = z.object({
  branchId: numericId.optional(),
  academicYear: z.string().optional(),
  teacherId: numericId.optional(),
});

export const createEnrollmentSchema = z.object({
  studentId: numericId,
  classId: numericId,
  academicYear: z.string().min(4, "academicYear must be at least 4 characters"),
  status: z.enum(["ACTIVE", "COMPLETED", "WITHDRAWN"]).default("ACTIVE"),
});

export const listEnrollmentsQuerySchema = z.object({
  studentId: numericId.optional(),
  classId: numericId.optional(),
  academicYear: z.string().optional(),
  status: z.enum(["ACTIVE", "COMPLETED", "WITHDRAWN"]).optional(),
});

export type CreateClassInput = z.infer<typeof createClassSchema>;
export type ListClassesQuery = z.infer<typeof listClassesQuerySchema>;
export type CreateEnrollmentInput = z.infer<typeof createEnrollmentSchema>;
export type ListEnrollmentsQuery = z.infer<typeof listEnrollmentsQuerySchema>;

