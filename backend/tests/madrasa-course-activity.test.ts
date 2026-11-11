import { expect, it, vi } from 'vitest';
import { Prisma } from '@prisma/client';
import { madrasaCourseActivity } from '../src/modules/learner/madrasa-course-activity';

it('binds scopes and excludes stale accounts, mismatched programmes and unpublished content', async () => {
  const query = vi.fn().mockResolvedValue([{ orgId: 4n, learners: 2n, trackedLessons: 7n, completedLessons: new Prisma.Decimal(3) }]);
  const result = await madrasaCourseActivity({ $queryRaw: query } as unknown as Prisma.TransactionClient, [4n, 9n]);
  const sql = query.mock.calls[0]![0] as Prisma.Sql;
  expect(sql.values).toEqual([4n, 9n]);
  for (const guard of [
    's.org_id = p.org_id', 's.learner_user_id = p.learner_user_id',
    'c.org_id = p.org_id', 'c.program_category = s.program_category',
    'l.org_id = p.org_id', 'l.course_id = p.course_id', "s.status = 'ACTIVE'",
    "c.publication_status = 'PUBLISHED'", "l.publication_status = 'PUBLISHED'",
    "c.visibility <> 'UNLISTED'", "l.visibility <> 'UNLISTED'",
    'COUNT(DISTINCT p.student_id)', 'p.completed_at IS NOT NULL OR p.progress_percent >= 100',
  ]) expect(sql.sql).toContain(guard);
  expect(result).toEqual([{ orgId: 4n, learners: 2, trackedLessons: 7, completedLessons: 3 }]);
  expect(sql.sql).not.toContain('full_name');
});

it('skips empty scopes and propagates failures rather than reporting zero activity', async () => {
  const query = vi.fn().mockRejectedValue(new Error('Unavailable'));
  const db = { $queryRaw: query } as unknown as Prisma.TransactionClient;
  expect(await madrasaCourseActivity(db, [])).toEqual([]);
  expect(query).not.toHaveBeenCalled();
  await expect(madrasaCourseActivity(db, [1n])).rejects.toThrow('Unavailable');
});
