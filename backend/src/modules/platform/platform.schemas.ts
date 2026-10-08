import { z } from "zod";
export const platformSessionIdSchema = z.string().uuid();
export const platformAccountIdSchema = z.string().min(1).max(30);
export const platformDisableAccountSchema = z.object({
  reason: z.string().trim().min(10).max(500),
}).strict();
export const platformRestoreAccountSchema = platformDisableAccountSchema.extend({
  suspensionEventId: z.string().min(1).max(30),
});

export const tenantApplicationSchema = z.object({
  schoolName: z.string().trim().min(2).max(150),
  requestedCode: z.string().trim().toLowerCase().min(3).max(50)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Use lowercase letters, digits and single hyphens"),
  adminEmail: z.string().trim().toLowerCase().email().max(150),
}).strict();

export const tenantDecisionSchema = z.object({
  decision: z.enum(["APPROVED", "REJECTED"]),
  reason: z.string().trim().min(10).max(500),
}).strict();

export const platformPageSchema = z.object({
  page: z.coerce.number().int().min(1).max(10000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
}).strict();

export const platformProvisioningQuerySchema = platformPageSchema.extend({
  q: z.string().trim().max(100).optional(),
  setup: z.enum(["pending", "created"]).optional(),
});

export const platformAuditQuerySchema = platformPageSchema.extend({
  action: z.string().trim().min(1).max(100).regex(/^[a-z][a-z0-9.]*$/).optional(),
  actorRole: z.enum(["SUPER_ADMIN", "IT_SECURITY"]).optional(),
  actorId: z.string().trim().min(1).max(30).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
}).refine((q) => !q.from || !q.to || new Date(q.from) <= new Date(q.to), {
  message: "Start must not be after end", path: ["from"],
});

export const platformAccountQuerySchema = platformPageSchema.extend({
  role: z.enum(["SUPER_ADMIN", "IT_SECURITY"]).optional(),
  status: z.enum(["ACTIVE", "DISABLED"]).optional(),
});

export const platformApplicationQuerySchema = platformPageSchema.extend({
  status: z.enum(["REQUESTED", "APPROVED", "REJECTED"]).optional(),
  scope: z.enum(["mine", "reviewable"]).optional(),
}).refine((query) => query.scope !== "reviewable" || !query.status || query.status === "REQUESTED", {
  message: "Reviewable applications must be requested", path: ["status"],
});
