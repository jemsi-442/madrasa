import { beforeEach, expect, it, vi } from 'vitest';
import type { AuthenticatedUser } from '../src/shared/middleware/authenticate';
const mocks = vi.hoisted(() => ({ findFirst: vi.fn(), summary: vi.fn(), transaction: vi.fn() }));
vi.mock('../src/shared/db/prisma', () => ({ prisma: { $transaction: mocks.transaction } }));
vi.mock('../src/modules/learner/student-course-summary', () => ({ studentCourseSummary: mocks.summary }));
import { studentCourseActivity } from '../src/modules/admin-panel/student-management';
const actor: AuthenticatedUser = { userId: '1', orgId: '2', branchId: '3', role: 'ADMIN' };
beforeEach(() => {
  vi.resetAllMocks();
  mocks.transaction.mockImplementation(fn => fn({ student: { findFirst: mocks.findFirst } }));
  mocks.findFirst.mockResolvedValue({ id: 4n, fullName: 'Synthetic Learner' });
  mocks.summary.mockResolvedValue({ linked: false, trackedLessons: 0, completedLessons: 0, recent: [] });
});
it('authorizes the org and branch before loading progress in the same snapshot', async () => {
  const result = await studentCourseActivity(actor, '4');
  expect(mocks.findFirst).toHaveBeenCalledWith({ where: { id: 4n, orgId: 2n, branchId: 3n }, select: { id: true, fullName: true } });
  expect(mocks.summary).toHaveBeenCalledWith(expect.anything(), 2n, 4n);
  expect(mocks.transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
  expect(result.courseProgress.linked).toBe(false);
});
it('does not read progress for an absent or out-of-scope student', async () => {
  mocks.findFirst.mockResolvedValue(null);
  await expect(studentCourseActivity(actor, '4')).rejects.toMatchObject({ statusCode: 404 });
  expect(mocks.summary).not.toHaveBeenCalled();
});
it.each(['TEACHER', 'PARENT', 'LEARNER', 'ACCOUNTANT'] as const)('rejects %s before accessing storage', async role => {
  await expect(studentCourseActivity({ ...actor, role }, '4')).rejects.toMatchObject({ statusCode: 403 });
  expect(mocks.transaction).not.toHaveBeenCalled();
});
