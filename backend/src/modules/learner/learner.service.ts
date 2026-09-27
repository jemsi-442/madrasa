import jwt from "jsonwebtoken";
import { Prisma } from "@prisma/client";

import { env } from "../../config/env";
import { initiatePayment } from "../payments/payments.service";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type {
  InitiateLearnerCoursePaymentInput,
  LearnerAttendanceQuery,
  UpdateLearnerLessonProgressInput,
} from "./learner.schemas";

const toDateString = (value: Date) => value.toISOString().slice(0, 10);
const LEARNER_ASSET_OPEN_TTL_SECONDS = 5 * 60;
const learnerPrisma = prisma;
const isPreviewVisibility = (visibility: string) => visibility === "PREVIEW";
const isFreeVisibility = (visibility: string) => visibility === "FREE";
const isPublished = (publicationStatus: string) => publicationStatus === "PUBLISHED";
const isHttpUrl = (value: string) => /^https?:\/\//i.test(value);
const splitFullName = (fullName: string): { firstname: string; lastname: string } => {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);

  if (!parts.length) {
    return {
      firstname: "Learner",
      lastname: "Account",
    };
  }

  if (parts.length === 1) {
    return {
      firstname: parts[0] ?? "Learner",
      lastname: parts[0] ?? "Account",
    };
  }

  return {
    firstname: parts[0] ?? "Learner",
    lastname: parts.slice(1).join(" "),
  };
};

type LearnerAssetTokenPayload = {
  type: "learner-asset";
  orgId: string;
  learnerUserId: string;
  sub: string;
  assetId: string;
  iat: number;
  exp: number;
};

type LessonProgressSummary = {
  progressPercent: number;
  watchSeconds: number;
  completedAt: string | null;
  lastOpenedAt: string | null;
};

type CourseAccessRequestSummary = {
  id: string;
  status: string;
  requestMessage: string | null;
  officeNote: string | null;
  createdAt: string;
  updatedAt: string;
  reviewedAt: string | null;
  invoice: {
    id: string;
    invoiceNo: string;
    amountDue: string;
    amountPaid: string;
    balanceRemaining: string;
    currency: string;
    dueDate: string;
    status: string;
    issuedAt: string;
    createdAt: string;
  } | null;
};

const getCourseAccessState = (courseVisibility: string, hasGrant = false) => {
  if (courseVisibility === "FREE") return "OPEN";
  if (courseVisibility === "PREVIEW") return "PREVIEW";
  if (courseVisibility === "PAID") return hasGrant ? "OPEN" : "PAYWALL";
  if (courseVisibility === "LOCKED") return "LOCKED";
  return "HIDDEN";
};

const getLessonAccessState = (courseVisibility: string, lessonVisibility: string, hasGrant = false) => {
  if (courseVisibility === "UNLISTED" || lessonVisibility === "UNLISTED") return "HIDDEN";
  if (courseVisibility === "LOCKED" || lessonVisibility === "LOCKED") return "LOCKED";

  if (isPreviewVisibility(lessonVisibility)) {
    return "PREVIEW";
  }

  if (isFreeVisibility(courseVisibility) && isFreeVisibility(lessonVisibility)) {
    return "OPEN";
  }

  if (isPreviewVisibility(courseVisibility) && isFreeVisibility(lessonVisibility)) {
    return "OPEN";
  }

  if (courseVisibility === "PAID") {
    if (hasGrant && (lessonVisibility === "PAID" || lessonVisibility === "FREE")) {
      return "OPEN";
    }

    return "PAYWALL";
  }

  if (courseVisibility === "LOCKED" || lessonVisibility === "LOCKED") {
    return "LOCKED";
  }

  return "LOCKED";
};

const getAssetAccessState = (
  courseVisibility: string,
  lessonVisibility: string,
  assetVisibility: string,
  hasGrant = false,
) => {
  if ([courseVisibility, lessonVisibility, assetVisibility].includes("UNLISTED")) return "HIDDEN";
  if ([courseVisibility, lessonVisibility, assetVisibility].includes("LOCKED")) return "LOCKED";

  if (isPreviewVisibility(assetVisibility)) {
    return "PREVIEW";
  }

  if (
    isFreeVisibility(assetVisibility) &&
    (getLessonAccessState(courseVisibility, lessonVisibility, hasGrant) === "OPEN" ||
      getLessonAccessState(courseVisibility, lessonVisibility, hasGrant) === "PREVIEW")
  ) {
    return "OPEN";
  }

  if (courseVisibility === "PAID") {
    if (hasGrant && assetVisibility === "PAID") {
      return "OPEN";
    }

    return "PAYWALL";
  }

  return "LOCKED";
};

export const loadLearnerStudent = async (authUser: AuthenticatedUser) => {
  if (authUser.role !== "LEARNER") {
    throw new HttpError(403, "You are not allowed to access learner data");
  }

  const student = await prisma.student.findFirst({
    where: {
      orgId: BigInt(authUser.orgId),
      learnerUserId: BigInt(authUser.userId),
      status: "ACTIVE",
      learnerUser: { is: { orgId: BigInt(authUser.orgId), status: "ACTIVE", role: "LEARNER", organization: { status: { in: ["ACTIVE", "TRIAL"] } } } },
    },
    select: {
      id: true,
      fullName: true,
      admissionNo: true,
      gender: true,
      status: true,
      programCategory: true,
      joinedOn: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      currentClass: {
        select: {
          id: true,
          name: true,
          academicYear: true,
        },
      },
      learnerUser: {
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          role: true,
        },
      },
    },
  });

  if (!student || !student.learnerUser) {
    throw new HttpError(404, "Learner profile is not linked to a student record");
  }

  return {
    ...student,
    learnerUser: student.learnerUser,
  };
};

const ensureLearnerCourseVisible = async (authUser: AuthenticatedUser, courseId: string) => {
  const student = await loadLearnerStudent(authUser);
  const course = await learnerPrisma.course.findFirst({
    where: {
      id: BigInt(courseId),
      orgId: BigInt(authUser.orgId),
      publicationStatus: "PUBLISHED",
      programCategory: student.programCategory,
      visibility: {
        not: "UNLISTED",
      },
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
      publishedAt: true,
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
        },
      },
    },
  });

  if (!course) {
    throw new HttpError(404, "Course not found for this learner");
  }

  return { student, course };
};

const loadActiveGrantMap = async (
  authUser: AuthenticatedUser,
  studentId: bigint,
  learnerUserId: bigint,
  courseIds: bigint[],
) => {
  if (!courseIds.length) {
    return new Map<string, { grantType: string; endsAt: string | null }>();
  }

  const now = new Date();
  const grants = await learnerPrisma.courseAccessGrant.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId,
      learnerUserId,
      courseId: {
        in: courseIds,
      },
      OR: [{ startsAt: null }, { startsAt: { lte: now } }],
      AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
    },
    select: {
      courseId: true,
      grantType: true,
      endsAt: true,
    },
  });

  return new Map(
    grants.map((grant: { courseId: bigint; grantType: string; endsAt: Date | null }) => [
      grant.courseId.toString(),
      {
        grantType: grant.grantType,
        endsAt: grant.endsAt?.toISOString() ?? null,
      },
    ]),
  );
};

const loadAccessRequestMap = async (
  authUser: AuthenticatedUser,
  studentId: bigint,
  learnerUserId: bigint,
  courseIds: bigint[],
) => {
  if (!courseIds.length) {
    return new Map<string, CourseAccessRequestSummary>();
  }

  const requests = await learnerPrisma.courseAccessRequest.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId,
      learnerUserId,
      courseId: {
        in: courseIds,
      },
    },
    select: {
      id: true,
      courseId: true,
      status: true,
      requestMessage: true,
      officeNote: true,
      createdAt: true,
      updatedAt: true,
      reviewedAt: true,
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

  return new Map(
    requests.map((request: {
      id: bigint;
      courseId: bigint;
      status: string;
      requestMessage: string | null;
      officeNote: string | null;
      createdAt: Date;
      updatedAt: Date;
      reviewedAt: Date | null;
      courseInvoices: Array<{
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
    }) => [
      request.courseId.toString(),
      {
        id: request.id.toString(),
        status: request.status,
        requestMessage: request.requestMessage,
        officeNote: request.officeNote,
        createdAt: request.createdAt.toISOString(),
        updatedAt: request.updatedAt.toISOString(),
        reviewedAt: request.reviewedAt?.toISOString() ?? null,
        invoice: request.courseInvoices[0]
          ? {
              id: request.courseInvoices[0].id.toString(),
              invoiceNo: request.courseInvoices[0].invoiceNo,
              amountDue: request.courseInvoices[0].amountDue.toFixed(2),
              amountPaid: request.courseInvoices[0].amountPaid.toFixed(2),
              balanceRemaining: request.courseInvoices[0].amountDue.minus(request.courseInvoices[0].amountPaid).toFixed(2),
              currency: request.courseInvoices[0].currency,
              dueDate: toDateString(request.courseInvoices[0].dueDate),
              status: request.courseInvoices[0].status,
              issuedAt: request.courseInvoices[0].issuedAt.toISOString(),
              createdAt: request.courseInvoices[0].createdAt.toISOString(),
            }
          : null,
      },
    ]),
  );
};

const toLessonProgressSummary = (progress: {
  progressPercent: number;
  watchSeconds: number;
  completedAt: Date | null;
  lastOpenedAt: Date | null;
} | null): LessonProgressSummary => ({
  progressPercent: progress?.progressPercent ?? 0,
  watchSeconds: progress?.watchSeconds ?? 0,
  completedAt: progress?.completedAt?.toISOString() ?? null,
  lastOpenedAt: progress?.lastOpenedAt?.toISOString() ?? null,
});

const loadLessonProgressMap = async (
  authUser: AuthenticatedUser,
  studentId: bigint,
  learnerUserId: bigint,
  lessonIds: bigint[],
) => {
  if (!lessonIds.length) {
    return new Map<string, LessonProgressSummary>();
  }

  const records = await learnerPrisma.courseLessonProgress.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId,
      learnerUserId,
      lessonId: {
        in: lessonIds,
      },
    },
    select: {
      lessonId: true,
      progressPercent: true,
      watchSeconds: true,
      completedAt: true,
      lastOpenedAt: true,
    },
  });

  return new Map(
    records.map((record: {
      lessonId: bigint;
      progressPercent: number;
      watchSeconds: number;
      completedAt: Date | null;
      lastOpenedAt: Date | null;
    }) => [
      record.lessonId.toString(),
      toLessonProgressSummary(record),
    ]),
  );
};

const buildLearnerAssetDeliveryToken = (authUser: AuthenticatedUser, assetId: bigint) =>
  jwt.sign(
    {
      orgId: authUser.orgId,
      learnerUserId: authUser.userId,
      assetId: assetId.toString(),
      type: "learner-asset",
    },
    env.JWT_SECRET,
    {
      expiresIn: LEARNER_ASSET_OPEN_TTL_SECONDS,
      subject: authUser.userId,
    },
  );

const decodeLearnerAssetDeliveryToken = (token: string) => {
  let payload: LearnerAssetTokenPayload;

  try {
    payload = jwt.verify(token, env.JWT_SECRET) as LearnerAssetTokenPayload;
  } catch {
    throw new HttpError(401, "This lesson item link is no longer valid");
  }

  if (
    payload.type !== "learner-asset" ||
    !payload.orgId ||
    !payload.learnerUserId ||
    !payload.assetId ||
    payload.sub !== payload.learnerUserId
  ) {
    throw new HttpError(401, "This lesson item link is no longer valid");
  }

  return payload;
};

const toExternalVideoEmbedUrl = (storageProvider: string, storageKey: string) => {
  if (!isHttpUrl(storageKey)) {
    return null;
  }

  if (storageProvider === "YOUTUBE") {
    const youtubeMatch =
      storageKey.match(/v=([^&]+)/i) ?? storageKey.match(/youtu\.be\/([^?&/]+)/i);
    return youtubeMatch?.[1]
      ? `https://www.youtube.com/embed/${youtubeMatch[1]}`
      : storageKey;
  }

  if (storageProvider === "VIMEO") {
    const vimeoMatch = storageKey.match(/vimeo\.com\/(\d+)/i);
    return vimeoMatch?.[1]
      ? `https://player.vimeo.com/video/${vimeoMatch[1]}`
      : storageKey;
  }

  return null;
};

const loadLearnerAssetAccess = async (authUser: AuthenticatedUser, assetId: string) => {
  const student = await loadLearnerStudent(authUser);
  const asset = await learnerPrisma.mediaAsset.findFirst({
    where: {
      id: BigInt(assetId),
      orgId: BigInt(authUser.orgId),
      visibility: {
        not: "UNLISTED",
      },
      lesson: {
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
      },
      course: {
        programCategory: student.programCategory,
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
      },
    },
    select: {
      id: true,
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
      lesson: {
        select: {
          id: true,
          title: true,
          visibility: true,
          publicationStatus: true,
        },
      },
      course: {
        select: {
          id: true,
          title: true,
          visibility: true,
          publicationStatus: true,
        },
      },
    },
  });

  if (!asset || !isPublished(asset.lesson.publicationStatus) || !isPublished(asset.course.publicationStatus)) {
    throw new HttpError(404, "Lesson item not found for this learner");
  }

  const grantMap = await loadActiveGrantMap(authUser, student.id, student.learnerUser.id, [asset.course.id]);
  const entitlement = grantMap.get(asset.course.id.toString()) ?? null;
  const accessState = getAssetAccessState(
    asset.course.visibility,
    asset.lesson.visibility,
    asset.visibility,
    Boolean(entitlement),
  );

  return {
    student,
    asset,
    entitlement,
    accessState,
  };
};

export const getLearnerProfile = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);

  return {
    user: {
      id: student.learnerUser.id.toString(),
      fullName: student.learnerUser.fullName,
      role: student.learnerUser.role,
    },
    student: {
      id: student.id.toString(),
      fullName: student.fullName,
      admissionNo: student.admissionNo,
      gender: student.gender,
      status: student.status,
      programCategory: student.programCategory,
      joinedOn: student.joinedOn ? toDateString(student.joinedOn) : null,
      branch: {
        id: student.branch.id.toString(),
        name: student.branch.name,
      },
      currentClass: student.currentClass
        ? {
            id: student.currentClass.id.toString(),
            name: student.currentClass.name,
            academicYear: student.currentClass.academicYear,
          }
        : null,
    },
  };
};

export const listLearnerCourses = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const courses = await learnerPrisma.course.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      programCategory: student.programCategory,
      publicationStatus: "PUBLISHED",
      visibility: {
        not: "UNLISTED",
      },
    },
    orderBy: [{ isFeatured: "desc" }, { publishedAt: "desc" }, { title: "asc" }],
    select: {
      id: true,
      slug: true,
      title: true,
      summary: true,
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
      publishedAt: true,
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
        },
      },
      _count: {
        select: {
          modules: true,
          lessons: true,
        },
      },
    },
  });

  const grantMap = await loadActiveGrantMap(
    authUser,
    student.id,
    student.learnerUser.id,
    courses.map((course: { id: bigint }) => course.id),
  );
  const accessRequestMap = await loadAccessRequestMap(
    authUser,
    student.id,
    student.learnerUser.id,
    courses.map((course: { id: bigint }) => course.id),
  );

  return courses.map((course: any) => ({
    id: course.id.toString(),
    slug: course.slug,
    title: course.title,
    summary: course.summary,
    programCategory: course.programCategory,
    deliveryMode: course.deliveryMode,
    level: course.level,
    visibility: course.visibility,
    priceAmount: course.priceAmount?.toFixed(2) ?? null,
    currency: course.currency,
    billingMode: course.billingMode,
    publicationStatus: course.publicationStatus,
    accessState: getCourseAccessState(course.visibility, grantMap.has(course.id.toString())),
    entitlement: grantMap.get(course.id.toString()) ?? null,
    accessRequest: accessRequestMap.get(course.id.toString()) ?? null,
    isFeatured: course.isFeatured,
    isReligious: course.isReligious,
    publishedAt: course.publishedAt?.toISOString() ?? null,
    subject: {
      id: course.subject.id.toString(),
      name: course.subject.name,
      code: course.subject.code,
      category: course.subject.category,
    },
    primaryInstructor: course.primaryInstructor
      ? {
          id: course.primaryInstructor.id.toString(),
          fullName: course.primaryInstructor.fullName,
        }
      : null,
    stats: {
      modules: course._count.modules,
      lessons: course._count.lessons,
    },
  }));
};

export const getLearnerCourseDetail = async (authUser: AuthenticatedUser, courseId: string) => {
  const { student, course } = await ensureLearnerCourseVisible(authUser, courseId);
  const grantMap = await loadActiveGrantMap(authUser, student.id, student.learnerUser.id, [course.id]);
  const accessRequestMap = await loadAccessRequestMap(authUser, student.id, student.learnerUser.id, [course.id]);
  const entitlement = grantMap.get(course.id.toString()) ?? null;
  const accessRequest = accessRequestMap.get(course.id.toString()) ?? null;
  const modules = await prisma.courseModule.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      courseId: course.id,
    },
    orderBy: [{ position: "asc" }, { createdAt: "asc" }],
    select: {
      id: true,
      title: true,
      position: true,
      summary: true,
      lessons: {
        where: {
          publicationStatus: "PUBLISHED",
          visibility: {
            not: "UNLISTED",
          },
        },
        orderBy: [{ position: "asc" }, { createdAt: "asc" }],
        select: {
          id: true,
          title: true,
          slug: true,
          summary: true,
          position: true,
          visibility: true,
          publicationStatus: true,
          estimatedMinutes: true,
          _count: {
            select: {
              assets: true,
            },
          },
        },
      },
    },
  });
  const lessonIds = modules.flatMap((moduleRecord) => moduleRecord.lessons.map((lesson) => lesson.id));
  const progressMap = await loadLessonProgressMap(
    authUser,
    student.id,
    student.learnerUser.id,
    lessonIds,
  );
  const completedLessons = lessonIds.filter((lessonId) => {
    const progress = progressMap.get(lessonId.toString()) as LessonProgressSummary | undefined;
    return Boolean(progress?.completedAt) || (progress?.progressPercent ?? 0) >= 100;
  }).length;
  const courseProgressPercent = lessonIds.length
    ? Math.round((completedLessons / lessonIds.length) * 100)
    : 0;

  return {
    learner: {
      studentId: student.id.toString(),
      programCategory: student.programCategory,
    },
    course: {
      id: course.id.toString(),
      slug: course.slug,
      title: course.title,
      summary: course.summary,
      description: course.description,
      deliveryMode: course.deliveryMode,
      level: course.level,
      visibility: course.visibility,
      priceAmount: course.priceAmount?.toFixed(2) ?? null,
      currency: course.currency,
      billingMode: course.billingMode,
      publicationStatus: course.publicationStatus,
      accessState: getCourseAccessState(course.visibility, Boolean(entitlement)),
      entitlement,
      accessRequest,
      isFeatured: course.isFeatured,
      isReligious: course.isReligious,
      publishedAt: course.publishedAt?.toISOString() ?? null,
      subject: {
        id: course.subject.id.toString(),
        name: course.subject.name,
        code: course.subject.code,
        category: course.subject.category,
      },
      primaryInstructor: course.primaryInstructor
        ? {
            id: course.primaryInstructor.id.toString(),
            fullName: course.primaryInstructor.fullName,
          }
        : null,
      progress: {
        completedLessons,
        totalLessons: lessonIds.length,
        progressPercent: courseProgressPercent,
      },
      modules: modules.map((moduleRecord) => ({
        id: moduleRecord.id.toString(),
        title: moduleRecord.title,
        position: moduleRecord.position,
        summary: moduleRecord.summary,
        lessons: moduleRecord.lessons.map((lesson) => ({
          id: lesson.id.toString(),
          title: lesson.title,
          slug: lesson.slug,
          summary: lesson.summary,
          position: lesson.position,
          visibility: lesson.visibility,
          publicationStatus: lesson.publicationStatus,
          estimatedMinutes: lesson.estimatedMinutes,
          accessState: getLessonAccessState(course.visibility, lesson.visibility, Boolean(entitlement)),
          assetCount: lesson._count.assets,
          progress: progressMap.get(lesson.id.toString()) ?? toLessonProgressSummary(null),
        })),
      })),
    },
  };
};

export const getLearnerLessonDetail = async (authUser: AuthenticatedUser, lessonId: string) => {
  const student = await loadLearnerStudent(authUser);
  const lesson = await prisma.courseLesson.findFirst({
    where: {
      id: BigInt(lessonId),
      orgId: BigInt(authUser.orgId),
      publicationStatus: "PUBLISHED",
      visibility: {
        not: "UNLISTED",
      },
      course: {
        programCategory: student.programCategory,
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
      },
    },
    select: {
      id: true,
      title: true,
      slug: true,
      summary: true,
      contentText: true,
      position: true,
      visibility: true,
      publicationStatus: true,
      estimatedMinutes: true,
      module: {
        select: {
          id: true,
          title: true,
          position: true,
        },
      },
      course: {
        select: {
          id: true,
          slug: true,
          title: true,
          visibility: true,
          publicationStatus: true,
        },
      },
      assets: {
        where: {
          visibility: {
            not: "UNLISTED",
          },
        },
        orderBy: [{ createdAt: "asc" }],
        select: {
          id: true,
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
        },
      },
    },
  });

  if (!lesson || !isPublished(lesson.course.publicationStatus)) {
    throw new HttpError(404, "Lesson not found for this learner");
  }

  const grantMap = await loadActiveGrantMap(authUser, student.id, student.learnerUser.id, [lesson.course.id]);
  const entitlement = grantMap.get(lesson.course.id.toString()) ?? null;
  const progressMap = await loadLessonProgressMap(
    authUser,
    student.id,
    student.learnerUser.id,
    [lesson.id],
  );
  const curriculumModules = await prisma.courseModule.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      courseId: lesson.course.id,
    },
    orderBy: [{ position: "asc" }, { createdAt: "asc" }],
    select: {
      id: true,
      title: true,
      position: true,
      lessons: {
        where: {
          publicationStatus: "PUBLISHED",
          visibility: {
            not: "UNLISTED",
          },
        },
        orderBy: [{ position: "asc" }, { createdAt: "asc" }],
        select: {
          id: true,
          title: true,
          slug: true,
          summary: true,
          position: true,
          visibility: true,
          estimatedMinutes: true,
          _count: {
            select: {
              assets: true,
            },
          },
        },
      },
    },
  });
  const curriculumLessonIds = curriculumModules.flatMap((moduleRecord) =>
    moduleRecord.lessons.map((moduleLesson) => moduleLesson.id),
  );
  const curriculumProgressMap = await loadLessonProgressMap(
    authUser,
    student.id,
    student.learnerUser.id,
    curriculumLessonIds,
  );
  const lessonAccessState = getLessonAccessState(
    lesson.course.visibility,
    lesson.visibility,
    Boolean(entitlement),
  );

  if (!["OPEN", "PREVIEW"].includes(lessonAccessState)) {
    throw new HttpError(403, "This lesson is not open for this learner yet");
  }

  return {
    learner: {
      studentId: student.id.toString(),
      programCategory: student.programCategory,
    },
    lesson: {
      id: lesson.id.toString(),
      title: lesson.title,
      slug: lesson.slug,
      summary: lesson.summary,
      contentText: lesson.contentText,
      position: lesson.position,
      visibility: lesson.visibility,
      publicationStatus: lesson.publicationStatus,
      estimatedMinutes: lesson.estimatedMinutes,
      accessState: lessonAccessState,
      progress: progressMap.get(lesson.id.toString()) ?? toLessonProgressSummary(null),
      module: {
        id: lesson.module.id.toString(),
        title: lesson.module.title,
        position: lesson.module.position,
      },
      course: {
        id: lesson.course.id.toString(),
        slug: lesson.course.slug,
        title: lesson.course.title,
        visibility: lesson.course.visibility,
        publicationStatus: lesson.course.publicationStatus,
        entitlement,
        curriculum: curriculumModules.map((moduleRecord) => ({
          id: moduleRecord.id.toString(),
          title: moduleRecord.title,
          position: moduleRecord.position,
          lessons: moduleRecord.lessons.map((moduleLesson) => ({
            id: moduleLesson.id.toString(),
            title: moduleLesson.title,
            slug: moduleLesson.slug,
            summary: moduleLesson.summary,
            position: moduleLesson.position,
            visibility: moduleLesson.visibility,
            estimatedMinutes: moduleLesson.estimatedMinutes,
            assetCount: moduleLesson._count.assets,
            accessState: getLessonAccessState(
              lesson.course.visibility,
              moduleLesson.visibility,
              Boolean(entitlement),
            ),
            progress: curriculumProgressMap.get(moduleLesson.id.toString()) ?? toLessonProgressSummary(null),
          })),
        })),
      },
      assets: lesson.assets.map((asset) => ({
        id: asset.id.toString(),
        assetType: asset.assetType,
        storageProvider: asset.storageProvider,
        title: asset.title,
        mimeType: asset.mimeType,
        durationSeconds: asset.durationSeconds,
        fileSizeBytes: asset.fileSizeBytes?.toString() ?? null,
        visibility: asset.visibility,
        downloadAllowed: asset.downloadAllowed,
        streamingProfile: asset.streamingProfile,
        sourceReady:
          Boolean(toExternalVideoEmbedUrl(asset.storageProvider, asset.storageKey)) ||
          isHttpUrl(asset.storageKey),
        accessState: getAssetAccessState(
          lesson.course.visibility,
          lesson.visibility,
          asset.visibility,
          Boolean(entitlement),
        ),
      })),
    },
  };
};

export const initiateLearnerCoursePayment = async (
  authUser: AuthenticatedUser,
  invoiceId: string,
  input: InitiateLearnerCoursePaymentInput,
  ipAddress?: string,
) => {
  const student = await loadLearnerStudent(authUser);
  const invoice = await prisma.invoice.findFirst({
    where: {
      id: BigInt(invoiceId),
      orgId: BigInt(authUser.orgId),
      studentId: student.id,
      learnerUserId: student.learnerUser.id,
      invoiceScope: "COURSE_ACCESS",
    },
    select: {
      id: true,
      status: true,
      course: {
        select: {
          id: true,
        },
      },
    },
  });

  if (!invoice || !invoice.course) {
    throw new HttpError(404, "Course invoice not found for this learner");
  }

  if (invoice.status === "CANCELLED") {
    throw new HttpError(409, "Cancelled course invoices cannot be paid");
  }

  const customer = splitFullName(student.learnerUser.fullName);

  return initiatePayment(
    authUser,
    {
      invoiceId,
      payerPhone: input.payerPhone,
      channel: input.channel,
      customer: {
        firstname: customer.firstname,
        lastname: customer.lastname,
        email: student.learnerUser.email ?? undefined,
      },
    },
    ipAddress,
  );
};

export const openLearnerAsset = async (authUser: AuthenticatedUser, assetId: string) => {
  const { asset, accessState } = await loadLearnerAssetAccess(authUser, assetId);

  if (!["OPEN", "PREVIEW"].includes(accessState)) {
    throw new HttpError(403, "This lesson item is not open for this learner yet");
  }

  const embedUrl = toExternalVideoEmbedUrl(asset.storageProvider, asset.storageKey);
  const token = buildLearnerAssetDeliveryToken(authUser, asset.id);
  const deliveryPath = `/api/learner/assets/${asset.id.toString()}/deliver?token=${encodeURIComponent(token)}`;
  const expiresAt = new Date(Date.now() + LEARNER_ASSET_OPEN_TTL_SECONDS * 1000).toISOString();

  const delivery =
    embedUrl
      ? {
          status: "READY",
          playerKind: "EMBED",
          inlineUrl: embedUrl,
          downloadUrl: null,
          expiresAt,
        }
      : isHttpUrl(asset.storageKey)
        ? {
            status: "READY",
            playerKind:
              asset.assetType === "VIDEO"
                ? "VIDEO"
                : asset.assetType === "AUDIO"
                  ? "AUDIO"
                  : asset.assetType === "PDF"
                    ? "PDF"
                    : "EXTERNAL",
            inlineUrl: deliveryPath,
            downloadUrl: asset.downloadAllowed ? deliveryPath : null,
            expiresAt,
          }
        : {
            status: "PENDING_SOURCE",
            playerKind: "PLACEHOLDER",
            inlineUrl: null,
            downloadUrl: null,
            expiresAt,
          };

  await prisma.auditLog.create({
    data: {
      orgId: BigInt(authUser.orgId),
      actorUserId: BigInt(authUser.userId),
      action: "LEARNER_ASSET_OPEN",
      entityType: "MediaAsset",
      entityId: asset.id.toString(),
      metadata: {
        assetType: asset.assetType,
        storageProvider: asset.storageProvider,
        lessonId: asset.lesson.id.toString(),
        courseId: asset.course.id.toString(),
        accessState,
        deliveryStatus: delivery.status,
      },
    },
  });

  return {
    asset: {
      id: asset.id.toString(),
      title: asset.title,
      assetType: asset.assetType,
      storageProvider: asset.storageProvider,
      mimeType: asset.mimeType,
      durationSeconds: asset.durationSeconds,
      fileSizeBytes: asset.fileSizeBytes?.toString() ?? null,
      accessState,
      downloadAllowed: asset.downloadAllowed,
      streamingProfile: asset.streamingProfile,
    },
    delivery,
  };
};

export const resolveLearnerAssetDelivery = async (assetId: string, token: string) => {
  const payload = decodeLearnerAssetDeliveryToken(token);

  if (payload.assetId !== assetId) {
    throw new HttpError(401, "This lesson item link is no longer valid");
  }

  const authUser: AuthenticatedUser = {
    userId: payload.learnerUserId,
    orgId: payload.orgId,
    role: "LEARNER",
  };
  const { asset, accessState } = await loadLearnerAssetAccess(authUser, assetId);

  if (accessState !== "OPEN" && accessState !== "PREVIEW") {
    throw new HttpError(403, "This lesson item is not open for this learner yet");
  }

  if (!isHttpUrl(asset.storageKey)) {
    throw new HttpError(409, "This lesson item source is not connected yet");
  }

  return {
    redirectUrl: asset.storageKey,
  };
};

export const listLearnerProgress = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const records = await learnerPrisma.courseLessonProgress.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId: student.id,
      learnerUserId: student.learnerUser.id,
      lesson: {
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
      },
      course: {
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
        programCategory: student.programCategory,
      },
    },
    orderBy: [{ updatedAt: "desc" }],
    select: {
      id: true,
      progressPercent: true,
      watchSeconds: true,
      completedAt: true,
      lastOpenedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
          subject: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      },
      lesson: {
        select: {
          id: true,
          title: true,
          slug: true,
          summary: true,
          estimatedMinutes: true,
          module: {
            select: {
              id: true,
              title: true,
              position: true,
            },
          },
        },
      },
    },
  });

  const courseMap = new Map<
    string,
    {
      id: string;
      title: string;
      slug: string;
      subject: { id: string; name: string };
      lessonCount: number;
      completedLessons: number;
      averageProgressPercent: number;
    }
  >();

  const items: Array<{
    id: string;
    progressPercent: number;
    watchSeconds: number;
    completedAt: string | null;
    lastOpenedAt: string | null;
    course: {
      id: string;
      title: string;
      slug: string;
      subject: {
        id: string;
        name: string;
      };
    };
    lesson: {
      id: string;
      title: string;
      slug: string;
      summary: string | null;
      estimatedMinutes: number | null;
      module: {
        id: string;
        title: string;
        position: number;
      };
    };
  }> = records.map((record: {
    id: bigint;
    progressPercent: number;
    watchSeconds: number;
    completedAt: Date | null;
    lastOpenedAt: Date | null;
    course: { id: bigint; title: string; slug: string; subject: { id: bigint; name: string } };
    lesson: {
      id: bigint;
      title: string;
      slug: string;
      summary: string | null;
      estimatedMinutes: number | null;
      module: { id: bigint; title: string; position: number };
    };
  }) => {
    const courseId = record.course.id.toString();
    const progress = toLessonProgressSummary(record);
    const courseItem = courseMap.get(courseId) ?? {
      id: courseId,
      title: record.course.title,
      slug: record.course.slug,
      subject: {
        id: record.course.subject.id.toString(),
        name: record.course.subject.name,
      },
      lessonCount: 0,
      completedLessons: 0,
      averageProgressPercent: 0,
    };

    courseItem.lessonCount += 1;
    courseItem.completedLessons += progress.completedAt || progress.progressPercent >= 100 ? 1 : 0;
    courseItem.averageProgressPercent += progress.progressPercent;
    courseMap.set(courseId, courseItem);

    return {
      id: record.id.toString(),
      progressPercent: progress.progressPercent,
      watchSeconds: progress.watchSeconds,
      completedAt: progress.completedAt,
      lastOpenedAt: progress.lastOpenedAt,
      course: {
        id: courseId,
        title: record.course.title,
        slug: record.course.slug,
        subject: {
          id: record.course.subject.id.toString(),
          name: record.course.subject.name,
        },
      },
      lesson: {
        id: record.lesson.id.toString(),
        title: record.lesson.title,
        slug: record.lesson.slug,
        summary: record.lesson.summary,
        estimatedMinutes: record.lesson.estimatedMinutes,
        module: {
          id: record.lesson.module.id.toString(),
          title: record.lesson.module.title,
          position: record.lesson.module.position,
        },
      },
    };
  });

  const courses = Array.from(courseMap.values()).map((courseItem) => ({
    ...courseItem,
    averageProgressPercent: courseItem.lessonCount
      ? Math.round(courseItem.averageProgressPercent / courseItem.lessonCount)
      : 0,
  }));

  const completedLessons = items.filter((item: (typeof items)[number]) => item.completedAt || item.progressPercent >= 100).length;

  return {
    learner: {
      studentId: student.id.toString(),
      programCategory: student.programCategory,
    },
    summary: {
      trackedLessons: items.length,
      completedLessons,
      activeCourses: courses.length,
      averageProgressPercent: items.length
        ? Math.round(items.reduce((sum: number, item: (typeof items)[number]) => sum + item.progressPercent, 0) / items.length)
        : 0,
    },
    courses,
    items,
  };
};

export const updateLearnerLessonProgress = async (
  authUser: AuthenticatedUser,
  lessonId: string,
  input: UpdateLearnerLessonProgressInput,
) => {
  const student = await loadLearnerStudent(authUser);
  const lesson = await prisma.courseLesson.findFirst({
    where: {
      id: BigInt(lessonId),
      orgId: BigInt(authUser.orgId),
      publicationStatus: "PUBLISHED",
      visibility: {
        not: "UNLISTED",
      },
      course: {
        programCategory: student.programCategory,
        publicationStatus: "PUBLISHED",
        visibility: {
          not: "UNLISTED",
        },
      },
    },
    select: {
      id: true,
      title: true,
      courseId: true,
      visibility: true,
      course: {
        select: {
          id: true,
          title: true,
          visibility: true,
        },
      },
    },
  });

  if (!lesson) {
    throw new HttpError(404, "Lesson not found for this learner");
  }

  const grantMap = await loadActiveGrantMap(authUser, student.id, student.learnerUser.id, [lesson.course.id]);
  const entitlement = grantMap.get(lesson.course.id.toString()) ?? null;
  const lessonAccessState = getLessonAccessState(
    lesson.course.visibility,
    lesson.visibility,
    Boolean(entitlement),
  );

  if (!["OPEN", "PREVIEW"].includes(lessonAccessState)) {
    throw new HttpError(403, "This lesson is not open for progress tracking yet");
  }

  const progressPercent = input.markCompleted ? 100 : input.progressPercent;
  const watchSeconds = input.watchSeconds ?? 0;
  const now = new Date();

  const progress = await learnerPrisma.courseLessonProgress.upsert({
    where: {
      lessonId_learnerUserId: {
        lessonId: lesson.id,
        learnerUserId: student.learnerUser.id,
      },
    },
    update: {
      progressPercent,
      watchSeconds,
      lastOpenedAt: now,
      completedAt: progressPercent >= 100 ? now : null,
    },
    create: {
      orgId: BigInt(authUser.orgId),
      courseId: lesson.courseId,
      lessonId: lesson.id,
      studentId: student.id,
      learnerUserId: student.learnerUser.id,
      progressPercent,
      watchSeconds,
      lastOpenedAt: now,
      completedAt: progressPercent >= 100 ? now : null,
    },
    select: {
      id: true,
      progressPercent: true,
      watchSeconds: true,
      completedAt: true,
      lastOpenedAt: true,
    },
  });

  await prisma.auditLog.create({
    data: {
      orgId: BigInt(authUser.orgId),
      actorUserId: BigInt(authUser.userId),
      action: "LEARNER_LESSON_PROGRESS_UPDATE",
      entityType: "CourseLesson",
      entityId: lesson.id.toString(),
      metadata: {
        courseId: lesson.course.id.toString(),
        progressPercent,
        watchSeconds,
        completed: progressPercent >= 100,
      },
    },
  });

  return {
    id: progress.id.toString(),
    lessonId: lesson.id.toString(),
    lessonTitle: lesson.title,
    courseId: lesson.course.id.toString(),
    courseTitle: lesson.course.title,
    ...toLessonProgressSummary(progress),
  };
};

export const getLearnerAttendance = async (authUser: AuthenticatedUser, query: LearnerAttendanceQuery) => {
  const student = await loadLearnerStudent(authUser);
  const where = {
    orgId: BigInt(authUser.orgId),
    studentId: student.id,
    ...(query.dateFrom || query.dateTo
      ? {
          date: {
            ...(query.dateFrom ? { gte: new Date(`${query.dateFrom}T00:00:00.000Z`) } : {}),
            ...(query.dateTo ? { lte: new Date(`${query.dateTo}T23:59:59.999Z`) } : {}),
          },
        }
      : {}),
  };

  const records = await prisma.attendanceRecord.findMany({
    where,
    orderBy: [{ date: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      date: true,
      status: true,
      reason: true,
      class: {
        select: {
          id: true,
          name: true,
          academicYear: true,
        },
      },
      markedBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map((record) => ({
    id: record.id.toString(),
    date: toDateString(record.date),
    status: record.status,
    reason: record.reason,
    class: {
      id: record.class.id.toString(),
      name: record.class.name,
      academicYear: record.class.academicYear,
    },
    markedBy: {
      id: record.markedBy.id.toString(),
      fullName: record.markedBy.fullName,
      role: record.markedBy.role,
    },
  }));
};

export const getLearnerFinance = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const invoices = await prisma.invoice.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId: student.id,
    },
    orderBy: [{ createdAt: "desc" }],
    select: {
      id: true,
      invoiceNo: true,
      amountDue: true,
      amountPaid: true,
      currency: true,
      dueDate: true,
      status: true,
      invoiceScope: true,
      issuedAt: true,
      course: {
        select: {
          id: true,
          title: true,
          slug: true,
        },
      },
      feeStructure: {
        select: {
          id: true,
          name: true,
        },
      },
      payments: {
        orderBy: [{ createdAt: "desc" }],
        select: {
          id: true,
          amount: true,
          currency: true,
          status: true,
          channel: true,
          reference: true,
          externalReference: true,
          paidAt: true,
          createdAt: true,
        },
      },
    },
  });

  return invoices.map((invoice) => ({
    id: invoice.id.toString(),
    invoiceNo: invoice.invoiceNo,
    amountDue: invoice.amountDue.toFixed(2),
    amountPaid: invoice.amountPaid.toFixed(2),
    balanceRemaining: invoice.amountDue.minus(invoice.amountPaid).toFixed(2),
    currency: invoice.currency,
    dueDate: toDateString(invoice.dueDate),
    status: invoice.status,
    invoiceScope: invoice.invoiceScope,
    issuedAt: invoice.issuedAt.toISOString(),
    course: invoice.course
      ? {
          id: invoice.course.id.toString(),
          title: invoice.course.title,
          slug: invoice.course.slug,
        }
      : null,
    feeStructure: invoice.feeStructure
      ? {
          id: invoice.feeStructure.id.toString(),
          name: invoice.feeStructure.name,
        }
      : null,
    payments: invoice.payments.map((payment) => ({
      id: payment.id.toString(),
      amount: payment.amount.toFixed(2),
      currency: payment.currency,
      status: payment.status,
      channel: payment.channel,
      reference: payment.reference,
      externalReference: payment.externalReference,
      paidAt: payment.paidAt?.toISOString() ?? null,
      createdAt: payment.createdAt.toISOString(),
    })),
  }));
};

export const getLearnerReceipts = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const payments = await prisma.payment.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      status: "COMPLETED",
      invoice: {
        studentId: student.id,
      },
    },
    orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      orgId: true,
      invoiceId: true,
      amount: true,
      currency: true,
      status: true,
      channel: true,
      reference: true,
      externalReference: true,
      providerTxnRef: true,
      paidAt: true,
      createdAt: true,
      organization: {
        select: {
          id: true,
          name: true,
          code: true,
        },
      },
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          dueDate: true,
          status: true,
          branch: {
            select: {
              id: true,
              name: true,
            },
          },
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  return payments.map((payment) => ({
    receiptNo: `RCP-${payment.id.toString().padStart(6, "0")}`,
    payment: {
      id: payment.id.toString(),
      orgId: payment.orgId.toString(),
      invoiceId: payment.invoiceId.toString(),
      amount: payment.amount.toFixed(2),
      currency: payment.currency,
      status: payment.status,
      channel: payment.channel,
      reference: payment.reference,
      externalReference: payment.externalReference,
      providerTxnRef: payment.providerTxnRef,
      paidAt: payment.paidAt?.toISOString() ?? null,
      createdAt: payment.createdAt.toISOString(),
    },
    organization: {
      id: payment.organization.id.toString(),
      name: payment.organization.name,
      code: payment.organization.code,
    },
    branch: payment.invoice.branch
      ? {
          id: payment.invoice.branch.id.toString(),
          name: payment.invoice.branch.name,
        }
      : null,
    student: {
      id: payment.invoice.student.id.toString(),
      fullName: payment.invoice.student.fullName,
      admissionNo: payment.invoice.student.admissionNo,
    },
    invoice: {
      id: payment.invoice.id.toString(),
      invoiceNo: payment.invoice.invoiceNo,
      amountDue: payment.invoice.amountDue.toFixed(2),
      amountPaid: payment.invoice.amountPaid.toFixed(2),
      balanceRemaining: payment.invoice.amountDue.minus(payment.invoice.amountPaid).toFixed(2),
      dueDate: toDateString(payment.invoice.dueDate),
      status: payment.invoice.status,
    },
  }));
};

export const getLearnerHifdh = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const records = await prisma.hifdhProgress.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      studentId: student.id,
    },
    orderBy: [{ assessedOn: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      studentId: true,
      teacherId: true,
      juzNumber: true,
      surahName: true,
      ayahFrom: true,
      ayahTo: true,
      memorizationScore: true,
      revisionScore: true,
      remarks: true,
      assessedOn: true,
      createdAt: true,
      teacher: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return records.map((record) => ({
    id: record.id.toString(),
    studentId: record.studentId.toString(),
    teacherId: record.teacherId.toString(),
    juzNumber: record.juzNumber,
    surahName: record.surahName,
    ayahFrom: record.ayahFrom,
    ayahTo: record.ayahTo,
    memorizationScore: record.memorizationScore.toFixed(2),
    revisionScore: record.revisionScore ? record.revisionScore.toFixed(2) : null,
    remarks: record.remarks,
    assessedOn: toDateString(record.assessedOn),
    createdAt: record.createdAt.toISOString(),
    teacher: {
      id: record.teacher.id.toString(),
      fullName: record.teacher.fullName,
      role: record.teacher.role,
    },
  }));
};

export const listLearnerAnnouncements = async (authUser: AuthenticatedUser) => {
  const student = await loadLearnerStudent(authUser);
  const now = new Date();

  const announcements = await prisma.announcement.findMany({
    where: {
      orgId: BigInt(authUser.orgId),
      audience: "ALL",
      publishAt: {
        lte: now,
      },
      OR: [{ expiresAt: null }, { expiresAt: { gte: now } }],
      AND: [
        {
          OR: [{ branchId: null }, { branchId: student.branch.id }],
        },
      ],
    },
    orderBy: [{ publishAt: "desc" }, { createdAt: "desc" }],
    select: {
      id: true,
      title: true,
      message: true,
      audience: true,
      publishAt: true,
      expiresAt: true,
      branch: {
        select: {
          id: true,
          name: true,
        },
      },
      createdBy: {
        select: {
          id: true,
          fullName: true,
          role: true,
        },
      },
    },
  });

  return announcements.map((announcement) => ({
    id: announcement.id.toString(),
    title: announcement.title,
    message: announcement.message,
    audience: announcement.audience,
    publishAt: announcement.publishAt.toISOString(),
    expiresAt: announcement.expiresAt?.toISOString() ?? null,
    branch: announcement.branch
      ? {
          id: announcement.branch.id.toString(),
          name: announcement.branch.name,
        }
      : null,
    createdBy: {
      id: announcement.createdBy.id.toString(),
      fullName: announcement.createdBy.fullName,
      role: announcement.createdBy.role,
    },
  }));
};
