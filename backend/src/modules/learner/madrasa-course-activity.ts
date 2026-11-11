import { Prisma } from "@prisma/client";

// Authorize the platform caller first. Aggregate only current learner links;
// a former account's completion must not transfer to its replacement.
export async function madrasaCourseActivity(db: Prisma.TransactionClient, orgIds: bigint[]) {
  if (!orgIds.length) return [];
  const rows = await db.$queryRaw<Array<{
    orgId: bigint; learners: bigint; trackedLessons: bigint; completedLessons: Prisma.Decimal;
  }>>(Prisma.sql`
    SELECT p.org_id AS orgId, COUNT(DISTINCT p.student_id) AS learners,
      COUNT(*) AS trackedLessons,
      SUM(CASE WHEN p.completed_at IS NOT NULL OR p.progress_percent >= 100 THEN 1 ELSE 0 END) AS completedLessons
    FROM course_lesson_progress p
    JOIN students s ON s.id = p.student_id AND s.org_id = p.org_id
      AND s.learner_user_id = p.learner_user_id
    JOIN courses c ON c.id = p.course_id AND c.org_id = p.org_id
      AND c.program_category = s.program_category
    JOIN course_lessons l ON l.id = p.lesson_id AND l.org_id = p.org_id AND l.course_id = p.course_id
    WHERE p.org_id IN (${Prisma.join(orgIds)}) AND s.status = 'ACTIVE'
      AND c.publication_status = 'PUBLISHED' AND c.visibility <> 'UNLISTED'
      AND l.publication_status = 'PUBLISHED' AND l.visibility <> 'UNLISTED'
    GROUP BY p.org_id
  `);
  return rows.map(row => ({
    orgId: row.orgId, learners: Number(row.learners),
    trackedLessons: Number(row.trackedLessons), completedLessons: Number(row.completedLessons),
  }));
}
