import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "guardianId must be a numeric string");

export const createUserSchema = z
  .object({
    fullName: z.string().min(2, "fullName must be at least 2 characters"),
    email: z.string().email("email must be valid").optional(),
    phone: z.string().min(8, "phone must be at least 8 characters").optional(),
    password: z.string().min(8, "password must be at least 8 characters"),
    role: z.enum(["ADMIN", "ACCOUNTANT", "TEACHER", "PARENT", "LEARNER"]),
    branchId: z.string().regex(/^\d+$/, "branchId must be a numeric string").optional(),
    guardianId: numericId.optional(),
    studentId: numericId.optional(),
  })
  .superRefine((value, ctx) => {
    if (!value.email && !value.phone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["email"],
        message: "Either email or phone is required",
      });
    }

    if (value.role === "PARENT" && !value.guardianId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["guardianId"],
        message: "guardianId is required when role is PARENT",
      });
    }

    if (value.role !== "PARENT" && value.guardianId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["guardianId"],
        message: "guardianId can only be used for PARENT accounts",
      });
    }

    if (value.role === "LEARNER" && !value.studentId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["studentId"],
        message: "studentId is required when role is LEARNER",
      });
    }

    if (value.role !== "LEARNER" && value.studentId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["studentId"],
        message: "studentId can only be used for LEARNER accounts",
      });
    }
  });

export const listUsersQuerySchema = z.object({
  role: z.enum(["ADMIN", "ACCOUNTANT", "TEACHER", "PARENT", "LEARNER"]).optional(),
  status: z.enum(["ACTIVE", "DISABLED"]).optional(),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;
