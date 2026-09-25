import { z } from "zod";

const numericId = z.string().regex(/^\d+$/, "must be a numeric string");

export const createSubjectSchema = z.object({
  code: z.string().min(2, "code must be at least 2 characters").max(30, "code is too long"),
  slug: z.string().min(2, "slug must be at least 2 characters").max(100, "slug is too long"),
  name: z.string().min(2, "name must be at least 2 characters").max(100, "name is too long"),
  summary: z.string().max(255, "summary is too long").optional(),
  category: z.enum(["RELIGIOUS", "LANGUAGE", "TECHNICAL", "BUSINESS", "GENERAL", "VOCATIONAL"]).default("GENERAL"),
  isCore: z.boolean().default(true),
  isActive: z.boolean().default(true),
});

export const listSubjectsQuerySchema = z.object({
  category: z.enum(["RELIGIOUS", "LANGUAGE", "TECHNICAL", "BUSINESS", "GENERAL", "VOCATIONAL"]).optional(),
  activeOnly: z
    .enum(["true", "false"])
    .transform((value) => value === "true")
    .optional(),
});

export const createCourseSchema = z.object({
  subjectId: numericId,
  slug: z.string().min(2, "slug must be at least 2 characters").max(120, "slug is too long"),
  title: z.string().min(2, "title must be at least 2 characters").max(150, "title is too long"),
  summary: z.string().min(2, "summary must be at least 2 characters").max(255, "summary is too long"),
  description: z.string().optional(),
  programCategory: z.enum(["MADRASA_CHILD", "COURSE_STUDENT"]).default("COURSE_STUDENT"),
  deliveryMode: z.enum(["SELF_PACED", "COHORT", "LIVE_PLUS_LIBRARY"]).default("SELF_PACED"),
  level: z.string().max(50, "level is too long").optional(),
  visibility: z.enum(["FREE", "PAID", "PREVIEW", "LOCKED", "UNLISTED"]).default("LOCKED"),
  priceAmount: z.string().regex(/^\d+(\.\d{1,2})?$/, "priceAmount must be a valid money value").optional(),
  currency: z.string().length(3, "currency must be a 3-letter code").optional(),
  billingMode: z.enum(["ONE_TIME", "SUBSCRIPTION"]).default("ONE_TIME"),
  publicationStatus: z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]).default("DRAFT"),
  isFeatured: z.boolean().default(false),
  isReligious: z.boolean().default(false),
  requiresApprovalBeforePublish: z.boolean().default(true),
  primaryInstructorUserId: numericId.optional(),
});

export const updateCourseSchema = createCourseSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  "At least one field is required",
);

export const listCoursesQuerySchema = z.object({
  subjectId: numericId.optional(),
  publicationStatus: z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]).optional(),
  visibility: z.enum(["FREE", "PAID", "PREVIEW", "LOCKED", "UNLISTED"]).optional(),
  primaryInstructorUserId: numericId.optional(),
});

export const learningRecordParamsSchema = z.object({
  id: numericId,
});

export const createCourseModuleSchema = z.object({
  title: z.string().min(2, "title must be at least 2 characters").max(150, "title is too long"),
  position: z.number().int().positive(),
  summary: z.string().max(255, "summary is too long").optional(),
});

export const updateCourseModuleSchema = createCourseModuleSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  "At least one field is required",
);

export const createCourseLessonSchema = z.object({
  title: z.string().min(2, "title must be at least 2 characters").max(150, "title is too long"),
  slug: z.string().min(2, "slug must be at least 2 characters").max(150, "slug is too long"),
  summary: z.string().max(255, "summary is too long").optional(),
  contentText: z.string().optional(),
  position: z.number().int().positive(),
  visibility: z.enum(["FREE", "PAID", "PREVIEW", "LOCKED", "UNLISTED"]).default("LOCKED"),
  publicationStatus: z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]).default("DRAFT"),
  estimatedMinutes: z.number().int().positive().optional(),
});

export const updateCourseLessonSchema = createCourseLessonSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  "At least one field is required",
);

export const createLessonAssetSchema = z.object({
  assetType: z.enum(["VIDEO", "AUDIO", "PDF", "TEXT", "ATTACHMENT"]),
  storageProvider: z.enum(["LOCAL", "S3", "R2", "VIMEO", "YOUTUBE", "EXTERNAL"]).default("LOCAL"),
  title: z.string().max(150, "title is too long").optional(),
  storageKey: z.string().min(2, "storageKey must be at least 2 characters").max(255, "storageKey is too long"),
  mimeType: z.string().max(120, "mimeType is too long").optional(),
  durationSeconds: z.number().int().positive().optional(),
  fileSizeBytes: z.number().int().positive().optional(),
  visibility: z.enum(["FREE", "PAID", "PREVIEW", "LOCKED", "UNLISTED"]).default("LOCKED"),
  downloadAllowed: z.boolean().default(false),
  streamingProfile: z.string().max(100, "streamingProfile is too long").optional(),
});

export const updateLessonAssetSchema = createLessonAssetSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  "At least one field is required",
);

export const createCourseAccessGrantSchema = z.object({
  learnerUserId: numericId,
  grantType: z.enum(["MANUAL", "PAYMENT", "SCHOLARSHIP", "PREVIEW"]).default("MANUAL"),
  startsAt: z.string().datetime().optional(),
  endsAt: z.string().datetime().optional(),
});

export const createCourseAccessRequestSchema = z.object({
  requestMessage: z.string().max(255, "requestMessage is too long").optional(),
});

export const listCourseAccessRequestsQuerySchema = z.object({
  status: z.enum(["NEW", "REVIEWING", "APPROVED", "REJECTED"]).optional(),
});

export const updateCourseAccessRequestStatusSchema = z.object({
  status: z.enum(["REVIEWING", "REJECTED"]),
  officeNote: z.string().max(255, "officeNote is too long").optional(),
});

export type CreateSubjectInput = z.infer<typeof createSubjectSchema>;
export type ListSubjectsQuery = z.infer<typeof listSubjectsQuerySchema>;
export type CreateCourseInput = z.infer<typeof createCourseSchema>;
export type UpdateCourseInput = z.infer<typeof updateCourseSchema>;
export type ListCoursesQuery = z.infer<typeof listCoursesQuerySchema>;
export type CreateCourseModuleInput = z.infer<typeof createCourseModuleSchema>;
export type UpdateCourseModuleInput = z.infer<typeof updateCourseModuleSchema>;
export type CreateCourseLessonInput = z.infer<typeof createCourseLessonSchema>;
export type UpdateCourseLessonInput = z.infer<typeof updateCourseLessonSchema>;
export type CreateLessonAssetInput = z.infer<typeof createLessonAssetSchema>;
export type UpdateLessonAssetInput = z.infer<typeof updateLessonAssetSchema>;
export type CreateCourseAccessGrantInput = z.infer<typeof createCourseAccessGrantSchema>;
export type CreateCourseAccessRequestInput = z.infer<typeof createCourseAccessRequestSchema>;
export type ListCourseAccessRequestsQuery = z.infer<typeof listCourseAccessRequestsQuerySchema>;
export type UpdateCourseAccessRequestStatusInput = z.infer<typeof updateCourseAccessRequestStatusSchema>;
