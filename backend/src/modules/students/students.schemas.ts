import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");
const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(10),
});

export const guardianInputSchema = z.object({
  fullName: z.string().min(2, "fullName must be at least 2 characters"),
  phone: z.string().min(8, "phone must be at least 8 characters"),
  email: z.string().email("email must be valid").optional(),
  relationship: z.string().min(2, "relationship must be at least 2 characters").optional(),
  address: z.string().min(2, "address must be at least 2 characters").optional(),
});

export const createGuardianSchema = guardianInputSchema;

export const createStudentSchema = z
  .object({
    admissionNo: z.string().min(2, "admissionNo must be at least 2 characters"),
    fullName: z.string().min(2, "fullName must be at least 2 characters"),
    gender: z.enum(["male", "female"]),
    dob: z.string().date().optional(),
    branchId: numericId,
    classId: numericId.optional(),
    joinedOn: z.string().date().optional(),
    notes: z.string().optional(),
    primaryGuardianId: numericId.optional(),
    guardian: guardianInputSchema.optional(),
  })
  .superRefine((value, ctx) => {
    const hasExistingGuardian = Boolean(value.primaryGuardianId);
    const hasGuardianPayload = Boolean(value.guardian);

    if (hasExistingGuardian === hasGuardianPayload) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["primaryGuardianId"],
        message: "Provide either primaryGuardianId or guardian payload",
      });
    }
  });

export const updateStudentSchema = z.object({
  admissionNo: z.string().min(2, "admissionNo must be at least 2 characters").optional(),
  fullName: z.string().min(2, "fullName must be at least 2 characters").optional(),
  gender: z.enum(["male", "female"]).optional(),
  dob: z.union([z.string().date(), z.null()]).optional(),
  branchId: numericId.optional(),
  classId: z.union([numericId, z.null()]).optional(),
  joinedOn: z.union([z.string().date(), z.null()]).optional(),
  leftOn: z.union([z.string().date(), z.null()]).optional(),
  notes: z.union([z.string(), z.null()]).optional(),
  status: z.enum(["ACTIVE", "INACTIVE", "SUSPENDED", "GRADUATED"]).optional(),
});

export const studentIdParamsSchema = z.object({
  id: numericId,
});

export const linkGuardianSchema = z.object({
  guardianId: numericId,
  isPrimary: z.boolean().optional(),
});

export const studentGuardianParamsSchema = z.object({
  id: numericId,
  guardianId: numericId,
});

export const setPrimaryGuardianSchema = z.object({
  guardianId: numericId,
});

export const listStudentsQuerySchema = paginationSchema.extend({
  branchId: numericId.optional(),
  classId: numericId.optional(),
  status: z.enum(["ACTIVE", "INACTIVE", "SUSPENDED", "GRADUATED"]).optional(),
  search: z.string().min(1).max(100).optional(),
});

export type CreateGuardianInput = z.infer<typeof createGuardianSchema>;
export type CreateStudentInput = z.infer<typeof createStudentSchema>;
export type UpdateStudentInput = z.infer<typeof updateStudentSchema>;
export type ListStudentsQuery = z.infer<typeof listStudentsQuerySchema>;
export type LinkGuardianInput = z.infer<typeof linkGuardianSchema>;
export type SetPrimaryGuardianInput = z.infer<typeof setPrimaryGuardianSchema>;
