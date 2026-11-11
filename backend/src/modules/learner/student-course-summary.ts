import type { Prisma } from "@prisma/client";

// Call only after the caller has authorised access to this student.
export async function studentCourseSummary(
  db: Prisma.TransactionClient, orgId: bigint, studentId: bigint,
) {
  const student = await db.student.findFirst({
    where: { orgId, id: studentId },
    select: { learnerUserId: true, programCategory: true },
  });
  if (!student?.learnerUserId) {
    return { linked: false, trackedLessons: 0, completedLessons: 0, recent: [] };
  }
  const where: Prisma.CourseLessonProgressWhereInput = {
    orgId, studentId, learnerUserId: student.learnerUserId,
    lesson: { orgId, publicationStatus: "PUBLISHED", visibility: { not: "UNLISTED" } },
    course: { orgId, publicationStatus: "PUBLISHED", visibility: { not: "UNLISTED" },
      programCategory: student.programCategory },
  };
  const [trackedLessons, completedLessons, recent] = await Promise.all([
    db.courseLessonProgress.count({ where }),
    db.courseLessonProgress.count({ where: { ...where,
      OR: [{ completedAt: { not: null } }, { progressPercent: { gte: 100 } }],
    } }),
    db.courseLessonProgress.findMany({
      where, take: 5, orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      select: { progressPercent: true, completedAt: true, updatedAt: true,
        course: { select: { title: true } }, lesson: { select: { title: true } } },
    }),
  ]);
  return { linked: true, trackedLessons, completedLessons, recent };
}
