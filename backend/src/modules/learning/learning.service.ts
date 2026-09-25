import { Prisma } from "@prisma/client";

import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  CreateCourseAccessGrantInput,
  CreateCourseAccessRequestInput,
  CreateCourseInput,
  CreateCourseLessonInput,
  CreateCourseModuleInput,
  CreateLessonAssetInput,
  CreateSubjectInput,
  ListCourseAccessRequestsQuery,
  ListCoursesQuery,
  ListSubjectsQuery,
  UpdateCourseAccessRequestStatusInput,
  UpdateCourseLessonInput,
  UpdateCourseModuleInput,
  UpdateCourseInput,
  UpdateLessonAssetInput,
} from "./learning.schemas";
import { ensureCourseAccessInvoiceForRequest, toCourseAccessInvoiceSummary } from "./course-access-billing.service";

const learningPrisma = prisma;

const toSubjectResponse = (subject: {
  id: bigint;
  orgId: bigint;
  code: string;
  slug: string | null;
  name: string;
  summary: string | null;
  category: string;
  isCore: boolean;
  isActive: boolean;
  createdAt: Date;
  createdBy?: { id: bigint; fullName: string; role: string } | null;
  _count?: { courses: number };
}) => ({
  id: subject.id.toString(),
  orgId: subject.orgId.toString(),
  code: subject.code,
  slug: subject.slug,
  name: subject.name,
  summary: subject.summary,
  category: subject.category,
  isCore: subject.isCore,
  isActive: subject.isActive,
  createdAt: subject.createdAt.toISOString(),
  createdBy: subject.createdBy
    ? {
        id: subject.createdBy.id.toString(),
        fullName: subject.createdBy.fullName,
        role: subject.createdBy.role,
      }
    : null,
  stats: subject._count
    ? {
        courses: subject._count.courses,
      }
    : null,
});

const toCourseResponse = (course: {
  id: bigint;
  orgId: bigint;
  subjectId: bigint;
  slug: string;
  title: string;
  summary: string;
  description: string | null;
  programCategory: string;
  deliveryMode: string;
  level: string | null;
  visibility: string;
  priceAmount: Prisma.Decimal | null;
  currency: string;
  billingMode: string;
  publicationStatus: string;
  isFeatured: boolean;
  isReligious: boolean;
  requiresApprovalBeforePublish: boolean;
  primaryInstructorUserId: bigint | null;
  createdByUserId: bigint;
  publishedByUserId: bigint | null;
  publishedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  subject?: { id: bigint; name: string; code: string; category: string } | null;
  primaryInstructor?: { id: bigint; fullName: string; email: string | null; phone: string | null } | null;
  createdBy?: { id: bigint; fullName: string; role: string } | null;
  publishedBy?: { id: bigint; fullName: string; role: string } | null;
}) => ({
  id: course.id.toString(),
  orgId: course.orgId.toString(),
  subjectId: course.subjectId.toString(),
  slug: course.slug,
  title: course.title,
  summary: course.summary,
  description: course.description,
  programCategory: course.programCategory,
  deliveryMode: course.deliveryMode,
  level: course.level,
  visibility: course.visibility,
  priceAmount: course.priceAmount?.toFixed(2) ?? null,
  currency: course.currency,
  billingMode: course.billingMode,
  publicationStatus: course.publicationStatus,
  isFeatured: course.isFeatured,
  isReligious: course.isReligious,
  requiresApprovalBeforePublish: course.requiresApprovalBeforePublish,
  primaryInstructorUserId: course.primaryInstructorUserId?.toString() ?? null,
  createdByUserId: course.createdByUserId.toString(),
  publishedByUserId: course.publishedByUserId?.toString() ?? null,
  publishedAt: course.publishedAt?.toISOString() ?? null,
  createdAt: course.createdAt.toISOString(),
  updatedAt: course.updatedAt.toISOString(),
  subject: course.subject
    ? {
        id: course.subject.id.toString(),
        name: course.subject.name,
        code: course.subject.code,
        category: course.subject.category,
      }
    : null,
  primaryInstructor: course.primaryInstructor
    ? {
        id: course.primaryInstructor.id.toString(),
        fullName: course.primaryInstructor.fullName,
        email: course.primaryInstructor.email,
        phone: course.primaryInstructor.phone,
      }
    : null,
  createdBy: course.createdBy
    ? {
        id: course.createdBy.id.toString(),
        fullName: course.createdBy.fullName,
        role: course.createdBy.role,
      }
    : null,
  publishedBy: course.publishedBy
    ? {
        id: course.publishedBy.id.toString(),
        fullName: course.publishedBy.fullName,
        role: course.publishedBy.role,
      }
    : null,
});

const toCourseModuleResponse = (moduleRecord: {
  id: bigint;
  orgId: bigint;
  courseId: bigint;
  title: string;
  position: number;
  summary: string | null;
  createdAt: Date;
  updatedAt: Date;
  course?: { id: bigint; title: string; slug: string } | null;
  _count?: { lessons: number };
}) => ({
  id: moduleRecord.id.toString(),
  orgId: moduleRecord.orgId.toString(),
  courseId: moduleRecord.courseId.toString(),
  title: moduleRecord.title,
  position: moduleRecord.position,
  summary: moduleRecord.summary,
  createdAt: moduleRecord.createdAt.toISOString(),
  updatedAt: moduleRecord.updatedAt.toISOString(),
  course: moduleRecord.course
    ? {
        id: moduleRecord.course.id.toString(),
        title: moduleRecord.course.title,
        slug: moduleRecord.course.slug,
      }
    : null,
  stats: moduleRecord._count
    ? {
        lessons: moduleRecord._count.lessons,
      }
    : null,
});

const toCourseLessonResponse = (lesson: {
  id: bigint;
  orgId: bigint;
  courseId: bigint;
  moduleId: bigint;
  title: string;
  slug: string;
  summary: string | null;
  contentText: string | null;
  position: number;
  visibility: string;
  publicationStatus: string;
  estimatedMinutes: number | null;
  createdAt: Date;
  updatedAt: Date;
  module?: { id: bigint; title: string; position: number } | null;
  _count?: { assets: number };
}) => ({
  id: lesson.id.toString(),
  orgId: lesson.orgId.toString(),
  courseId: lesson.courseId.toString(),
  moduleId: lesson.moduleId.toString(),
  title: lesson.title,
  slug: lesson.slug,
  summary: lesson.summary,
  contentText: lesson.contentText,
  position: lesson.position,
  visibility: lesson.visibility,
  publicationStatus: lesson.publicationStatus,
  estimatedMinutes: lesson.estimatedMinutes,
  createdAt: lesson.createdAt.toISOString(),
  updatedAt: lesson.updatedAt.toISOString(),
  module: lesson.module
    ? {
        id: lesson.module.id.toString(),
        title: lesson.module.title,
        position: lesson.module.position,
      }
    : null,
  stats: lesson._count
    ? {
        assets: lesson._count.assets,
      }
    : null,
});

const toMediaAssetResponse = (asset: {
  id: bigint;
  orgId: bigint;
  courseId: bigint;
  lessonId: bigint;
  assetType: string;
  storageProvider: string;
  title: string | null;
  storageKey: string;
  mimeType: string | null;
  durationSeconds: number | null;
  fileSizeBytes: bigint | null;
  visibility: string;
  downloadAllowed: boolean;
  streamingProfile: string | null;
  createdAt: Date;
  updatedAt: Date;
}) => ({
  id: asset.id.toString(),
  orgId: asset.orgId.toString(),
  courseId: asset.courseId.toString(),
  lessonId: asset.lessonId.toString(),
  assetType: asset.assetType,
  storageProvider: asset.storageProvider,
  title: asset.title,
  storageKey: asset.storageKey,
  mimeType: asset.mimeType,
  durationSeconds: asset.durationSeconds,
  fileSizeBytes: asset.fileSizeBytes?.toString() ?? null,
  visibility: asset.visibility,
  downloadAllowed: asset.downloadAllowed,
  streamingProfile: asset.streamingProfile,
  createdAt: asset.createdAt.toISOString(),
  updatedAt: asset.updatedAt.toISOString(),
});

const toCourseAccessGrantResponse = (grant: {
  id: bigint;
  orgId: bigint;
  courseId: bigint;
  studentId: bigint;
  learnerUserId: bigint;
  grantType: string;
  startsAt: Date | null;
  endsAt: Date | null;
  grantedByUserId: bigint;
  createdAt: Date;
  updatedAt: Date;
  learnerUser?: { id: bigint; fullName: string; email: string | null; phone: string | null } | null;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  grantedBy?: { id: bigint; fullName: string; role: string } | null;
}) => ({
  id: grant.id.toString(),
  orgId: grant.orgId.toString(),
  courseId: grant.courseId.toString(),
  studentId: grant.studentId.toString(),
  learnerUserId: grant.learnerUserId.toString(),
  grantType: grant.grantType,
  startsAt: grant.startsAt?.toISOString() ?? null,
  endsAt: grant.endsAt?.toISOString() ?? null,
  grantedByUserId: grant.grantedByUserId.toString(),
  createdAt: grant.createdAt.toISOString(),
  updatedAt: grant.updatedAt.toISOString(),
  learnerUser: grant.learnerUser
    ? {
        id: grant.learnerUser.id.toString(),
        fullName: grant.learnerUser.fullName,
        email: grant.learnerUser.email,
        phone: grant.learnerUser.phone,
      }
    : null,
  student: grant.student
    ? {
        id: grant.student.id.toString(),
        fullName: grant.student.fullName,
        admissionNo: grant.student.admissionNo,
      }
    : null,
  grantedBy: grant.grantedBy
    ? {
        id: grant.grantedBy.id.toString(),
        fullName: grant.grantedBy.fullName,
        role: grant.grantedBy.role,
      }
    : null,
});

const toCourseAccessRequestResponse = (request: {
  id: bigint;
  orgId: bigint;
  courseId: bigint;
  studentId: bigint;
  learnerUserId: bigint;
  status: string;
  requestMessage: string | null;
  officeNote: string | null;
  reviewedByUserId: bigint | null;
  reviewedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  course?: {
    id: bigint;
    title: string;
    slug: string;
    visibility: string;
    priceAmount: Prisma.Decimal | null;
    currency: string;
    billingMode: string;
  } | null;
  learnerUser?: { id: bigint; fullName: string; email: string | null; phone: string | null } | null;
  student?: { id: bigint; fullName: string; admissionNo: string } | null;
  reviewedBy?: { id: bigint; fullName: string; role: string } | null;
  courseInvoices?: Array<{
    id: bigint;
    invoiceNo: string;
    amountDue: Prisma.Decimal;
    amountPaid: Prisma.Decimal;
    currency: string;
    dueDate: Date;
    status: string;
    issuedAt: Date;
    createdAt: Date;
  }>;
}) => ({
  id: request.id.toString(),
  orgId: request.orgId.toString(),
  courseId: request.courseId.toString(),
  studentId: request.studentId.toString(),
  learnerUserId: request.learnerUserId.toString(),
  status: request.status,
  requestMessage: request.requestMessage,
  officeNote: request.officeNote,
  reviewedByUserId: request.reviewedByUserId?.toString() ?? null,
  reviewedAt: request.reviewedAt?.toISOString() ?? null,
  createdAt: request.createdAt.toISOString(),
  updatedAt: request.updatedAt.toISOString(),
  course: request.course
    ? {
        id: request.course.id.toString(),
        title: request.course.title,
        slug: request.course.slug,
        visibility: request.course.visibility,
        priceAmount: request.course.priceAmount?.toFixed(2) ?? null,
        currency: request.course.currency,
        billingMode: request.course.billingMode,
      }
    : null,
  learnerUser: request.learnerUser
    ? {
        id: request.learnerUser.id.toString(),
        fullName: request.learnerUser.fullName,
        email: request.learnerUser.email,
        phone: request.learnerUser.phone,
      }
    : null,
  student: request.student
    ? {
        id: request.student.id.toString(),
        fullName: request.student.fullName,
        admissionNo: request.student.admissionNo,
      }
    : null,
  reviewedBy: request.reviewedBy
    ? {
        id: request.reviewedBy.id.toString(),
        fullName: request.reviewedBy.fullName,
        role: request.reviewedBy.role,
      }
    : null,
  invoice: request.courseInvoices?.[0] ? toCourseAccessInvoiceSummary(request.courseInvoices[0]) : null,
});

const ensureSubjectBelongsToOrg = async (orgId: bigint, subjectId: bigint) => {
  const subject = await prisma.subject.findFirst({
    where: {
      id: subjectId,
      orgId,
    },
    select: {
      id: true,
    },
  });

  if (!subject) {
    throw new HttpError(404, "Subject not found for this organization");
  }
};

const ensureTeacherBelongsToOrg = async (orgId: bigint, teacherId: bigint) => {
  const teacher = await prisma.user.findFirst({
    where: {
      id: teacherId,
      orgId,
      role: "TEACHER",
      status: "ACTIVE",
    },
    select: {
      id: true,
    },
  });

  if (!teacher) {
    throw new HttpError(404, "Teacher not found for this organization");
  }
};

const ensureLearnerBelongsToOrg = async (orgId: bigint, learnerUserId: bigint) => {
  const learner = await prisma.user.findFirst({
    where: {
      id: learnerUserId,
      orgId,
      role: "LEARNER",
      status: "ACTIVE",
    },
    select: {
      id: true,
      fullName: true,
      email: true,
      phone: true,
      learnerProfile: {
        select: {
          id: true,
          branchId: true,
          fullName: true,
          admissionNo: true,
          programCategory: true,
        },
      },
    },
  });

  if (!learner || !learner.learnerProfile) {
    throw new HttpError(404, "Learner account is not linked to a student record");
  }

  return {
    ...learner,
    learnerProfile: learner.learnerProfile,
  };
};

const ensureCourseExistsForOrg = async (orgId: bigint, courseId: bigint) => {
  const course = await learningPrisma.course.findFirst({
    where: {
      id: courseId,
      orgId,
    },
    select: {
      id: true,
      orgId: true,
      primaryInstructorUserId: true,
      programCategory: true,
      visibility: true,
      priceAmount: true,
      currency: true,
      billingMode: true,
      title: true,
      slug: true,
    },
  });

  if (!course) {
    throw new HttpError(404, "Course not found for this organization");
  }

  return course;
};

const ensureCourseAuthorAccess = async (authUser: AuthenticatedUser, courseId: bigint) => {
  const course = await ensureCourseExistsForOrg(BigInt(authUser.orgId), courseId);

  if (authUser.role === "TEACHER" && course.primaryInstructorUserId !== BigInt(authUser.userId)) {
    throw new HttpError(403, "You can only manage lessons for courses assigned to you");
  }

  return course;
};

const ensureModuleAuthorAccess = async (authUser: AuthenticatedUser, moduleId: bigint) => {
  const moduleRecord = await learningPrisma.courseModule.findFirst({
    where: {
      id: moduleId,
      orgId: BigInt(authUser.orgId),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      title: true,
      position: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          primaryInstructorUserId: true,
        },
      },
    },
  });

  if (!moduleRecord) {
    throw new HttpError(404, "Course module not found");
  }

  if (authUser.role === "TEACHER" && moduleRecord.course.primaryInstructorUserId !== BigInt(authUser.userId)) {
    throw new HttpError(403, "You can only manage lessons for courses assigned to you");
  }

  return moduleRecord;
};

const ensureLessonAuthorAccess = async (authUser: AuthenticatedUser, lessonId: bigint) => {
  const lesson = await learningPrisma.courseLesson.findFirst({
    where: {
      id: lessonId,
      orgId: BigInt(authUser.orgId),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      moduleId: true,
      title: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          primaryInstructorUserId: true,
        },
      },
    },
  });

  if (!lesson) {
    throw new HttpError(404, "Course lesson not found");
  }

  if (authUser.role === "TEACHER" && lesson.course.primaryInstructorUserId !== BigInt(authUser.userId)) {
    throw new HttpError(403, "You can only manage assets for courses assigned to you");
  }

  return lesson;
};

export const createSubject = async (authUser: AuthenticatedUser, input: CreateSubjectInput) => {
  const subject = await prisma.subject.create({
    data: {
      orgId: BigInt(authUser.orgId),
      code: input.code,
      slug: input.slug,
      name: input.name,
      summary: input.summary ?? null,
      category: input.category,
      isCore: input.isCore,
      isActive: input.isActive,
      createdByUserId: BigInt(authUser.userId),
    },
    select: {
      id: true,
      orgId: true,
      code: true,
      slug: true,
      name: true,
      summary: true,
      category: true,
      isCore: true,
      isActive: true,
      createdAt: true,
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      _count: {
        select: {
          courses: true,
        },
      },
    },
  });

  return toSubjectResponse(subject);
};

export const listSubjects = async (authUser: AuthenticatedUser, query: ListSubjectsQuery) => {
  const where: Prisma.SubjectWhereInput = {
    orgId: BigInt(authUser.orgId),
  };

  if (query.category) {
    where.category = query.category;
  }

  if (query.activeOnly ?? authUser.role === "TEACHER") {
    where.isActive = true;
  }

  const subjects = await prisma.subject.findMany({
    where,
    orderBy: [{ name: "asc" }],
    select: {
      id: true,
      orgId: true,
      code: true,
      slug: true,
      name: true,
      summary: true,
      category: true,
      isCore: true,
      isActive: true,
      createdAt: true,
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      _count: {
        select: {
          courses: true,
        },
      },
    },
  });

  return subjects.map(toSubjectResponse);
};

export const createCourse = async (authUser: AuthenticatedUser, input: CreateCourseInput) => {
  const orgId = BigInt(authUser.orgId);
  const subjectId = BigInt(input.subjectId);
  const primaryInstructorUserId = input.primaryInstructorUserId ? BigInt(input.primaryInstructorUserId) : null;

  await ensureSubjectBelongsToOrg(orgId, subjectId);

  if (input.visibility === "PAID" && !input.priceAmount) {
    throw new HttpError(400, "Paid courses must include a price amount");
  }

  if (primaryInstructorUserId) {
    await ensureTeacherBelongsToOrg(orgId, primaryInstructorUserId);
  }

  const course = await learningPrisma.course.create({
    data: {
      orgId,
      subjectId,
      slug: input.slug,
      title: input.title,
      summary: input.summary,
      description: input.description ?? null,
      programCategory: input.programCategory,
      deliveryMode: input.deliveryMode,
      level: input.level ?? null,
      visibility: input.visibility,
      priceAmount: input.priceAmount ? new Prisma.Decimal(input.priceAmount) : null,
      currency: input.currency ?? "TZS",
      billingMode: input.billingMode,
      publicationStatus: input.publicationStatus,
      isFeatured: input.isFeatured,
      isReligious: input.isReligious,
      requiresApprovalBeforePublish: input.requiresApprovalBeforePublish,
      primaryInstructorUserId,
      createdByUserId: BigInt(authUser.userId),
      publishedByUserId: input.publicationStatus === "PUBLISHED" ? BigInt(authUser.userId) : null,
      publishedAt: input.publicationStatus === "PUBLISHED" ? new Date() : null,
    },
    select: {
      id: true,
      orgId: true,
      subjectId: true,
      slug: true,
      title: true,
      summary: true,
      description: true,
      programCategory: true,
      deliveryMode: true,
      level: true,
      visibility: true,
      priceAmount: true,
      currency: true,
      billingMode: true,
      publicationStatus: true,
      isFeatured: true,
      isReligious: true,
      requiresApprovalBeforePublish: true,
      primaryInstructorUserId: true,
      createdByUserId: true,
      publishedByUserId: true,
      publishedAt: true,
      createdAt: true,
      updatedAt: true,
      subject: {
        select: {
          id: true,
          name: true,
          code: true,
          category: true,
        },
      },
      primaryInstructor: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      publishedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return toCourseResponse(course);
};

export const createCourseAccessGrant = async (
  authUser: AuthenticatedUser,
  courseId: string,
  input: CreateCourseAccessGrantInput,
) => {
  const orgId = BigInt(authUser.orgId);
  const parsedCourseId = BigInt(courseId);
  const parsedLearnerUserId = BigInt(input.learnerUserId);
  const course = await ensureCourseExistsForOrg(orgId, parsedCourseId);
  const learner = await ensureLearnerBelongsToOrg(orgId, parsedLearnerUserId);

  if (learner.learnerProfile.programCategory !== course.programCategory) {
    throw new HttpError(409, "Learner program category does not match this course");
  }

  if (course.visibility !== "PAID" && input.grantType === "PAYMENT") {
    throw new HttpError(409, "Payment grants are only valid for paid courses");
  }

  if (input.grantType === "PAYMENT") {
    const latestInvoice = await prisma.invoice.findFirst({
      where: {
        orgId,
        courseId: parsedCourseId,
        studentId: learner.learnerProfile.id,
        learnerUserId: parsedLearnerUserId,
        invoiceScope: "COURSE_ACCESS",
      },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      select: { status: true },
    });
    if (latestInvoice?.status !== "PAID") throw new HttpError(409, "A paid course invoice is required for a payment grant");
  }

  const startsAt = input.startsAt ? new Date(input.startsAt) : new Date();
  const endsAt = input.endsAt ? new Date(input.endsAt) : null;

  if (endsAt && endsAt <= startsAt) {
    throw new HttpError(400, "Grant end date must be after the start date");
  }

  const grant = await learningPrisma.courseAccessGrant.upsert({
    where: {
      courseId_learnerUserId: {
        courseId: parsedCourseId,
        learnerUserId: parsedLearnerUserId,
      },
    },
    update: {
      studentId: learner.learnerProfile.id,
      grantType: input.grantType,
      startsAt,
      endsAt,
      grantedByUserId: BigInt(authUser.userId),
    },
    create: {
      orgId,
      courseId: parsedCourseId,
      studentId: learner.learnerProfile.id,
      learnerUserId: parsedLearnerUserId,
      grantType: input.grantType,
      startsAt,
      endsAt,
      grantedByUserId: BigInt(authUser.userId),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      studentId: true,
      learnerUserId: true,
      grantType: true,
      startsAt: true,
      endsAt: true,
      grantedByUserId: true,
      createdAt: true,
      updatedAt: true,
      learnerUser: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      grantedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  await learningPrisma.courseAccessRequest.updateMany({
    where: {
      orgId,
      courseId: parsedCourseId,
      learnerUserId: parsedLearnerUserId,
      studentId: learner.learnerProfile.id,
    },
    data: {
      status: "APPROVED",
      reviewedByUserId: BigInt(authUser.userId),
      reviewedAt: new Date(),
    },
  });

  return {
    ...toCourseAccessGrantResponse(grant),
    courseTitle: course.title,
  };
};

export const createCourseAccessRequest = async (
  authUser: AuthenticatedUser,
  courseId: string,
  input: CreateCourseAccessRequestInput,
) => {
  const parsedCourseId = BigInt(courseId);
  const course = await ensureCourseExistsForOrg(BigInt(authUser.orgId), parsedCourseId);
  const learner = await ensureLearnerBelongsToOrg(BigInt(authUser.orgId), BigInt(authUser.userId));

  if (authUser.role !== "LEARNER") {
    throw new HttpError(403, "Only learner accounts can request course access");
  }

  if (course.visibility !== "PAID") {
    throw new HttpError(409, "Access requests are only used for paid courses");
  }

  if (learner.learnerProfile.programCategory !== course.programCategory) {
    throw new HttpError(409, "Learner program category does not match this course");
  }

  const existingGrant = await learningPrisma.courseAccessGrant.findFirst({
    where: {
      orgId: BigInt(authUser.orgId),
      courseId: parsedCourseId,
      learnerUserId: learner.id,
      studentId: learner.learnerProfile.id,
      OR: [{ startsAt: null }, { startsAt: { lte: new Date() } }],
      AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }] }],
    },
    select: {
      id: true,
    },
  });

  if (existingGrant) {
    throw new HttpError(409, "This learner already has access to the course");
  }

  const priceAmount = course.priceAmount;
  if (!priceAmount) {
    throw new HttpError(409, "This paid course is missing a price and cannot accept payment yet");
  }

  const request = await prisma.$transaction(async (tx) => {
    const requestRecord = await tx.courseAccessRequest.upsert({
      where: {
        courseId_learnerUserId: {
          courseId: parsedCourseId,
          learnerUserId: learner.id,
        },
      },
      update: {
        status: "NEW",
        requestMessage: input.requestMessage ?? null,
        officeNote: null,
        reviewedByUserId: null,
        reviewedAt: null,
      },
      create: {
        orgId: BigInt(authUser.orgId),
        courseId: parsedCourseId,
        studentId: learner.learnerProfile.id,
        learnerUserId: learner.id,
        status: "NEW",
        requestMessage: input.requestMessage ?? null,
      },
      select: {
        id: true,
      },
    });

    await ensureCourseAccessInvoiceForRequest(tx, {
      orgId: BigInt(authUser.orgId),
      branchId: learner.learnerProfile.branchId,
      studentId: learner.learnerProfile.id,
      learnerUserId: learner.id,
      courseId: parsedCourseId,
      courseAccessRequestId: requestRecord.id,
      amountDue: priceAmount,
      currency: course.currency,
    });

    return tx.courseAccessRequest.findUniqueOrThrow({
      where: {
        id: requestRecord.id,
      },
      select: {
        id: true,
        orgId: true,
        courseId: true,
        studentId: true,
        learnerUserId: true,
        status: true,
        requestMessage: true,
        officeNote: true,
        reviewedByUserId: true,
        reviewedAt: true,
        createdAt: true,
        updatedAt: true,
        course: {
          select: {
            id: true,
            title: true,
            slug: true,
            visibility: true,
            priceAmount: true,
            currency: true,
            billingMode: true,
          },
        },
        learnerUser: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
          },
        },
        student: {
          select: {
            id: true,
            fullName: true,
            admissionNo: true,
          },
        },
        reviewedBy: {
          select: {
            id: true,
            fullName: true,
            role: true,
          },
        },
        courseInvoices: {
          where: {
            invoiceScope: "COURSE_ACCESS",
          },
          orderBy: [{ createdAt: "desc" }],
          take: 1,
          select: {
            id: true,
            invoiceNo: true,
            amountDue: true,
            amountPaid: true,
            currency: true,
            dueDate: true,
            status: true,
            issuedAt: true,
            createdAt: true,
          },
        },
      },
    });
  });

  await prisma.auditLog.create({
    data: {
      orgId: BigInt(authUser.orgId),
      actorUserId: BigInt(authUser.userId),
      action: "COURSE_ACCESS_REQUEST_CREATE",
      entityType: "CourseAccessRequest",
      entityId: request.id.toString(),
      metadata: {
        courseId: parsedCourseId.toString(),
        courseTitle: course.title,
        status: request.status,
      },
    },
  });

  return toCourseAccessRequestResponse(request);
};

export const listCourseAccessRequests = async (
  authUser: AuthenticatedUser,
  query: ListCourseAccessRequestsQuery,
) => {
  const where: Prisma.CourseAccessRequestWhereInput = {
    orgId: BigInt(authUser.orgId),
  };

  if (query.status) {
    where.status = query.status;
  }

  const requests = await learningPrisma.courseAccessRequest.findMany({
    where,
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      orgId: true,
      courseId: true,
      studentId: true,
      learnerUserId: true,
      status: true,
      requestMessage: true,
      officeNote: true,
      reviewedByUserId: true,
      reviewedAt: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          visibility: true,
          priceAmount: true,
          currency: true,
          billingMode: true,
        },
      },
      learnerUser: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      reviewedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      courseInvoices: {
        where: {
          invoiceScope: "COURSE_ACCESS",
        },
        orderBy: [{ createdAt: "desc" }],
        take: 1,
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          currency: true,
          dueDate: true,
          status: true,
          issuedAt: true,
          createdAt: true,
        },
      },
    },
  });

  return requests.map(toCourseAccessRequestResponse);
};

export const updateCourseAccessRequestStatus = async (
  authUser: AuthenticatedUser,
  requestId: string,
  input: UpdateCourseAccessRequestStatusInput,
) => {
  const parsedRequestId = BigInt(requestId);

  const existingRequest = await learningPrisma.courseAccessRequest.findFirst({
    where: {
      id: parsedRequestId,
      orgId: BigInt(authUser.orgId),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      studentId: true,
      learnerUserId: true,
      status: true,
      requestMessage: true,
      officeNote: true,
      reviewedByUserId: true,
      reviewedAt: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          visibility: true,
          priceAmount: true,
          currency: true,
          billingMode: true,
        },
      },
      learnerUser: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      reviewedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      courseInvoices: {
        where: {
          invoiceScope: "COURSE_ACCESS",
        },
        orderBy: [{ createdAt: "desc" }],
        take: 1,
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          currency: true,
          dueDate: true,
          status: true,
          issuedAt: true,
          createdAt: true,
        },
      },
    },
  });

  if (!existingRequest) {
    throw new HttpError(404, "Course access request not found");
  }

  const updatedRequest = await learningPrisma.courseAccessRequest.update({
    where: {
      id: parsedRequestId,
    },
    data: {
      status: input.status,
      officeNote: input.officeNote ?? null,
      reviewedByUserId: BigInt(authUser.userId),
      reviewedAt: new Date(),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      studentId: true,
      learnerUserId: true,
      status: true,
      requestMessage: true,
      officeNote: true,
      reviewedByUserId: true,
      reviewedAt: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          visibility: true,
          priceAmount: true,
          currency: true,
          billingMode: true,
        },
      },
      learnerUser: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
      reviewedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      courseInvoices: {
        where: {
          invoiceScope: "COURSE_ACCESS",
        },
        orderBy: [{ createdAt: "desc" }],
        take: 1,
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          currency: true,
          dueDate: true,
          status: true,
          issuedAt: true,
          createdAt: true,
        },
      },
    },
  });

  await prisma.auditLog.create({
    data: {
      orgId: BigInt(authUser.orgId),
      actorUserId: BigInt(authUser.userId),
      action: "COURSE_ACCESS_REQUEST_STATUS_UPDATE",
      entityType: "CourseAccessRequest",
      entityId: updatedRequest.id.toString(),
      metadata: {
        courseId: updatedRequest.courseId.toString(),
        courseTitle: updatedRequest.course?.title ?? null,
        previousStatus: existingRequest.status,
        nextStatus: updatedRequest.status,
        officeNote: updatedRequest.officeNote ?? null,
      },
    },
  });

  return toCourseAccessRequestResponse(updatedRequest);
};

export const updateCourse = async (authUser: AuthenticatedUser, courseId: string, input: UpdateCourseInput) => {
  const orgId = BigInt(authUser.orgId);
  const parsedCourseId = BigInt(courseId);
  const data: Record<string, unknown> = {};
  const currentCourse = await ensureCourseExistsForOrg(orgId, parsedCourseId);
  const nextVisibility = input.visibility ?? currentCourse.visibility;
  const nextPriceAmount = input.priceAmount !== undefined ? input.priceAmount : currentCourse.priceAmount?.toFixed(2) ?? null;

  if (nextVisibility === "PAID" && !nextPriceAmount) {
    throw new HttpError(400, "Paid courses must include a price amount");
  }

  if (input.subjectId) {
    const subjectId = BigInt(input.subjectId);
    await ensureSubjectBelongsToOrg(orgId, subjectId);
    data.subject = { connect: { id: subjectId } };
  }

  if (input.primaryInstructorUserId !== undefined) {
    if (input.primaryInstructorUserId) {
      const teacherId = BigInt(input.primaryInstructorUserId);
      await ensureTeacherBelongsToOrg(orgId, teacherId);
      data.primaryInstructor = { connect: { id: teacherId } };
    } else {
      data.primaryInstructor = { disconnect: true };
    }
  }

  if (input.slug !== undefined) data.slug = input.slug;
  if (input.title !== undefined) data.title = input.title;
  if (input.summary !== undefined) data.summary = input.summary;
  if (input.description !== undefined) data.description = input.description;
  if (input.programCategory !== undefined) data.programCategory = input.programCategory;
  if (input.deliveryMode !== undefined) data.deliveryMode = input.deliveryMode;
  if (input.level !== undefined) data.level = input.level ?? null;
  if (input.visibility !== undefined) data.visibility = input.visibility;
  if (input.priceAmount !== undefined) {
    data.priceAmount = input.priceAmount ? new Prisma.Decimal(input.priceAmount) : null;
  }
  if (input.currency !== undefined) data.currency = input.currency;
  if (input.billingMode !== undefined) data.billingMode = input.billingMode;
  if (input.publicationStatus !== undefined) {
    data.publicationStatus = input.publicationStatus;

    if (input.publicationStatus === "PUBLISHED") {
      data.publishedBy = { connect: { id: BigInt(authUser.userId) } };
      data.publishedAt = new Date();
    }
  }
  if (input.isFeatured !== undefined) data.isFeatured = input.isFeatured;
  if (input.isReligious !== undefined) data.isReligious = input.isReligious;
  if (input.requiresApprovalBeforePublish !== undefined) {
    data.requiresApprovalBeforePublish = input.requiresApprovalBeforePublish;
  }

  try {
    const course = await learningPrisma.course.update({
      where: {
        id: parsedCourseId,
        orgId,
      },
      data,
      select: {
        id: true,
        orgId: true,
        subjectId: true,
        slug: true,
        title: true,
        summary: true,
        description: true,
        programCategory: true,
        deliveryMode: true,
        level: true,
        visibility: true,
        priceAmount: true,
        currency: true,
        billingMode: true,
        publicationStatus: true,
        isFeatured: true,
        isReligious: true,
        requiresApprovalBeforePublish: true,
        primaryInstructorUserId: true,
        createdByUserId: true,
        publishedByUserId: true,
        publishedAt: true,
        createdAt: true,
        updatedAt: true,
        subject: {
          select: {
            id: true,
            name: true,
            code: true,
            category: true,
          },
        },
        primaryInstructor: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
          },
        },
        createdBy: {
          select: {
            id: true,
            fullName: true,
            role: true,
          },
        },
        publishedBy: {
          select: {
            id: true,
            fullName: true,
            role: true,
          },
        },
      },
    });

    return toCourseResponse(course);
  } catch (error) {
    if (error instanceof Error && error.message.includes("Record to update not found")) {
      throw new HttpError(404, "Course not found");
    }

    throw error;
  }
};

export const listCourses = async (authUser: AuthenticatedUser, query: ListCoursesQuery) => {
  const where: Prisma.CourseWhereInput = {
    orgId: BigInt(authUser.orgId),
  };

  if (query.subjectId) {
    where.subjectId = BigInt(query.subjectId);
  }

  if (query.publicationStatus) {
    where.publicationStatus = query.publicationStatus;
  }

  if (query.visibility) {
    where.visibility = query.visibility;
  }

  if (query.primaryInstructorUserId) {
    where.primaryInstructorUserId = BigInt(query.primaryInstructorUserId);
  }

  if (authUser.role === "TEACHER") {
    where.primaryInstructorUserId = BigInt(authUser.userId);
  }

  const courses = await learningPrisma.course.findMany({
    where,
    orderBy: [{ updatedAt: "desc" }, { title: "asc" }],
    select: {
      id: true,
      orgId: true,
      subjectId: true,
      slug: true,
      title: true,
      summary: true,
      description: true,
      programCategory: true,
      deliveryMode: true,
      level: true,
      visibility: true,
      priceAmount: true,
      currency: true,
      billingMode: true,
      publicationStatus: true,
      isFeatured: true,
      isReligious: true,
      requiresApprovalBeforePublish: true,
      primaryInstructorUserId: true,
      createdByUserId: true,
      publishedByUserId: true,
      publishedAt: true,
      createdAt: true,
      updatedAt: true,
      subject: {
        select: {
          id: true,
          name: true,
          code: true,
          category: true,
        },
      },
      primaryInstructor: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
      publishedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return courses.map(toCourseResponse);
};

export const createCourseModule = async (
  authUser: AuthenticatedUser,
  courseId: string,
  input: CreateCourseModuleInput,
) => {
  const parsedCourseId = BigInt(courseId);
  const course = await ensureCourseAuthorAccess(authUser, parsedCourseId);

  const moduleRecord = await learningPrisma.courseModule.create({
    data: {
      orgId: BigInt(authUser.orgId),
      courseId: parsedCourseId,
      title: input.title,
      position: input.position,
      summary: input.summary ?? null,
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      title: true,
      position: true,
      summary: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
        },
      },
      _count: {
        select: {
          lessons: true,
        },
      },
    },
  });

  return {
    ...toCourseModuleResponse(moduleRecord),
    courseTitle: course.title,
  };
};

export const listCourseModules = async (authUser: AuthenticatedUser, courseId: string) => {
  const parsedCourseId = BigInt(courseId);
  await ensureCourseAuthorAccess(authUser, parsedCourseId);

  const modules = await learningPrisma.courseModule.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      courseId: parsedCourseId,
    },
    orderBy: [{ position: "asc" }, { createdAt: "asc" }],
    select: {
      id: true,
      orgId: true,
      courseId: true,
      title: true,
      position: true,
      summary: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
        },
      },
      _count: {
        select: {
          lessons: true,
        },
      },
    },
  });

  return modules.map(toCourseModuleResponse);
};

export const updateCourseModule = async (
  authUser: AuthenticatedUser,
  moduleId: string,
  input: UpdateCourseModuleInput,
) => {
  const parsedModuleId = BigInt(moduleId);
  const moduleRecord = await ensureModuleAuthorAccess(authUser, parsedModuleId);

  const updatedModule = await learningPrisma.courseModule.update({
    where: {
      id: parsedModuleId,
    },
    data: {
      ...(input.title !== undefined ? { title: input.title } : {}),
      ...(input.position !== undefined ? { position: input.position } : {}),
      ...(input.summary !== undefined ? { summary: input.summary ?? null } : {}),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      title: true,
      position: true,
      summary: true,
      createdAt: true,
      updatedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
        },
      },
      _count: {
        select: {
          lessons: true,
        },
      },
    },
  });

  return {
    ...toCourseModuleResponse(updatedModule),
    courseTitle: moduleRecord.course.title,
  };
};

export const createCourseLesson = async (
  authUser: AuthenticatedUser,
  moduleId: string,
  input: CreateCourseLessonInput,
) => {
  const parsedModuleId = BigInt(moduleId);
  const moduleRecord = await ensureModuleAuthorAccess(authUser, parsedModuleId);

  const lesson = await learningPrisma.courseLesson.create({
    data: {
      orgId: BigInt(authUser.orgId),
      courseId: moduleRecord.courseId,
      moduleId: parsedModuleId,
      title: input.title,
      slug: input.slug,
      summary: input.summary ?? null,
      contentText: input.contentText ?? null,
      position: input.position,
      visibility: input.visibility,
      publicationStatus: input.publicationStatus,
      estimatedMinutes: input.estimatedMinutes ?? null,
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      moduleId: true,
      title: true,
      slug: true,
      summary: true,
      contentText: true,
      position: true,
      visibility: true,
      publicationStatus: true,
      estimatedMinutes: true,
      createdAt: true,
      updatedAt: true,
      module: {
        select: {
          id: true,
          title: true,
          position: true,
        },
      },
      _count: {
        select: {
          assets: true,
        },
      },
    },
  });

  return {
    ...toCourseLessonResponse(lesson),
    moduleTitle: moduleRecord.title,
  };
};

export const listCourseLessons = async (authUser: AuthenticatedUser, moduleId: string) => {
  const parsedModuleId = BigInt(moduleId);
  const moduleRecord = await ensureModuleAuthorAccess(authUser, parsedModuleId);

  const lessons = await learningPrisma.courseLesson.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      moduleId: parsedModuleId,
      courseId: moduleRecord.courseId,
    },
    orderBy: [{ position: "asc" }, { createdAt: "asc" }],
    select: {
      id: true,
      orgId: true,
      courseId: true,
      moduleId: true,
      title: true,
      slug: true,
      summary: true,
      contentText: true,
      position: true,
      visibility: true,
      publicationStatus: true,
      estimatedMinutes: true,
      createdAt: true,
      updatedAt: true,
      module: {
        select: {
          id: true,
          title: true,
          position: true,
        },
      },
      _count: {
        select: {
          assets: true,
        },
      },
    },
  });

  return lessons.map(toCourseLessonResponse);
};

export const updateCourseLesson = async (
  authUser: AuthenticatedUser,
  lessonId: string,
  input: UpdateCourseLessonInput,
) => {
  const parsedLessonId = BigInt(lessonId);
  const lessonRecord = await ensureLessonAuthorAccess(authUser, parsedLessonId);

  const updatedLesson = await learningPrisma.courseLesson.update({
    where: {
      id: parsedLessonId,
    },
    data: {
      ...(input.title !== undefined ? { title: input.title } : {}),
      ...(input.slug !== undefined ? { slug: input.slug } : {}),
      ...(input.summary !== undefined ? { summary: input.summary ?? null } : {}),
      ...(input.contentText !== undefined ? { contentText: input.contentText ?? null } : {}),
      ...(input.position !== undefined ? { position: input.position } : {}),
      ...(input.visibility !== undefined ? { visibility: input.visibility } : {}),
      ...(input.publicationStatus !== undefined ? { publicationStatus: input.publicationStatus } : {}),
      ...(input.estimatedMinutes !== undefined ? { estimatedMinutes: input.estimatedMinutes ?? null } : {}),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      moduleId: true,
      title: true,
      slug: true,
      summary: true,
      contentText: true,
      position: true,
      visibility: true,
      publicationStatus: true,
      estimatedMinutes: true,
      createdAt: true,
      updatedAt: true,
      module: {
        select: {
          id: true,
          title: true,
          position: true,
        },
      },
      _count: {
        select: {
          assets: true,
        },
      },
    },
  });

  return {
    ...toCourseLessonResponse(updatedLesson),
    moduleTitle: updatedLesson.module?.title ?? null,
    courseTitle: lessonRecord.course.title,
  };
};

export const createLessonAsset = async (
  authUser: AuthenticatedUser,
  lessonId: string,
  input: CreateLessonAssetInput,
) => {
  const parsedLessonId = BigInt(lessonId);
  const lesson = await ensureLessonAuthorAccess(authUser, parsedLessonId);

  const asset = await learningPrisma.mediaAsset.create({
    data: {
      orgId: BigInt(authUser.orgId),
      courseId: lesson.courseId,
      lessonId: parsedLessonId,
      assetType: input.assetType,
      storageProvider: input.storageProvider,
      title: input.title ?? null,
      storageKey: input.storageKey,
      mimeType: input.mimeType ?? null,
      durationSeconds: input.durationSeconds ?? null,
      fileSizeBytes: input.fileSizeBytes ? BigInt(input.fileSizeBytes) : null,
      visibility: input.visibility,
      downloadAllowed: input.downloadAllowed,
      streamingProfile: input.streamingProfile ?? null,
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      lessonId: true,
      assetType: true,
      storageProvider: true,
      title: true,
      storageKey: true,
      mimeType: true,
      durationSeconds: true,
      fileSizeBytes: true,
      visibility: true,
      downloadAllowed: true,
      streamingProfile: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return {
    ...toMediaAssetResponse(asset),
    lessonTitle: lesson.title,
  };
};

export const listLessonAssets = async (authUser: AuthenticatedUser, lessonId: string) => {
  const parsedLessonId = BigInt(lessonId);
  const lesson = await ensureLessonAuthorAccess(authUser, parsedLessonId);

  const assets = await learningPrisma.mediaAsset.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      lessonId: parsedLessonId,
      courseId: lesson.courseId,
    },
    orderBy: [{ createdAt: "asc" }],
    select: {
      id: true,
      orgId: true,
      courseId: true,
      lessonId: true,
      assetType: true,
      storageProvider: true,
      title: true,
      storageKey: true,
      mimeType: true,
      durationSeconds: true,
      fileSizeBytes: true,
      visibility: true,
      downloadAllowed: true,
      streamingProfile: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return assets.map(toMediaAssetResponse);
};

export const updateLessonAsset = async (
  authUser: AuthenticatedUser,
  assetId: string,
  input: UpdateLessonAssetInput,
) => {
  const parsedAssetId = BigInt(assetId);
  const assetRecord = await learningPrisma.mediaAsset.findFirst({
    where: {
      id: parsedAssetId,
      orgId: BigInt(authUser.orgId),
    },
    select: {
      id: true,
      lessonId: true,
    },
  });

  if (!assetRecord) {
    throw new HttpError(404, "Lesson asset not found");
  }

  const lesson = await ensureLessonAuthorAccess(authUser, assetRecord.lessonId);

  const updatedAsset = await learningPrisma.mediaAsset.update({
    where: {
      id: parsedAssetId,
    },
    data: {
      ...(input.assetType !== undefined ? { assetType: input.assetType } : {}),
      ...(input.storageProvider !== undefined ? { storageProvider: input.storageProvider } : {}),
      ...(input.title !== undefined ? { title: input.title ?? null } : {}),
      ...(input.storageKey !== undefined ? { storageKey: input.storageKey } : {}),
      ...(input.mimeType !== undefined ? { mimeType: input.mimeType ?? null } : {}),
      ...(input.durationSeconds !== undefined ? { durationSeconds: input.durationSeconds ?? null } : {}),
      ...(input.fileSizeBytes !== undefined
        ? { fileSizeBytes: input.fileSizeBytes ? BigInt(input.fileSizeBytes) : null }
        : {}),
      ...(input.visibility !== undefined ? { visibility: input.visibility } : {}),
      ...(input.downloadAllowed !== undefined ? { downloadAllowed: input.downloadAllowed } : {}),
      ...(input.streamingProfile !== undefined ? { streamingProfile: input.streamingProfile ?? null } : {}),
    },
    select: {
      id: true,
      orgId: true,
      courseId: true,
      lessonId: true,
      assetType: true,
      storageProvider: true,
      title: true,
      storageKey: true,
      mimeType: true,
      durationSeconds: true,
      fileSizeBytes: true,
      visibility: true,
      downloadAllowed: true,
      streamingProfile: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return {
    ...toMediaAssetResponse(updatedAsset),
    lessonTitle: lesson.title,
  };
};
