import { beforeEach, describe, expect, it, vi } from 'vitest';
import { prisma } from '../src/shared/db/prisma';
import { reorderCourseOutline, validateCourseOrder } from '../src/modules/learning/course-order';

vi.mock('../src/shared/db/prisma', () => ({ prisma: { $transaction: vi.fn() } }));

const actor = { userId: '7', orgId: '1', role: 'TEACHER' as const };
const order = { expectedIds: ['2', '3'], ids: ['3', '2'] };
const tx = {
  course: { findFirst: vi.fn() },
  courseModule: { findFirst: vi.fn(), findMany: vi.fn(), update: vi.fn() },
  courseLesson: { findMany: vi.fn(), update: vi.fn() },
};

beforeEach(() => {
  vi.clearAllMocks();
  tx.course.findFirst.mockResolvedValue({ id: 10n, primaryInstructorUserId: 7n });
  tx.courseModule.findFirst.mockResolvedValue({ id: 9n, courseId: 10n });
  const rows = [{ id: 2n, position: 1 }, { id: 3n, position: 2 }];
  tx.courseModule.findMany.mockResolvedValue(rows);
  tx.courseLesson.findMany.mockResolvedValue(rows);
  vi.mocked(prisma.$transaction).mockImplementation(async (run: any) => run(tx));
});

describe('course outline ordering', () => {
  it('rejects stale, duplicate and foreign items', () => {
    expect(() => validateCourseOrder(['2', '3'], ['3', '2'], ['2', '3'])).toThrow('outline changed');
    for (const next of [['2', '2'], ['2', '4'], ['2']]) {
      expect(() => validateCourseOrder(['2', '3'], ['2', '3'], next)).toThrow('exactly once');
    }
  });
  for (const kind of ['modules', 'lessons'] as const) {
    it(`moves ${kind} through unused positions in one transaction`, async () => {
      await expect(reorderCourseOutline(actor, '9', kind, order)).resolves.toEqual({ ids: ['3', '2'] });
      const update = kind === 'modules' ? tx.courseModule.update : tx.courseLesson.update;
      expect(update.mock.calls.map(([arg]) => [arg.where.id, arg.data.position])).toEqual([
        [3n, 3], [2n, 4], [3n, 1], [2n, 2],
      ]);
      expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'Serializable' });
      expect(tx.course.findFirst).toHaveBeenCalledWith({ where: { id: kind === 'modules' ? 9n : 10n, orgId: 1n } });
    });
  }
  it('blocks non-authors and courses outside the institution', async () => {
    await expect(reorderCourseOutline({ ...actor, role: 'ACCOUNTANT' }, '9', 'modules', order)).rejects.toThrow('Author access');
    expect(prisma.$transaction).not.toHaveBeenCalled();
    tx.course.findFirst.mockResolvedValue({ id: 10n, primaryInstructorUserId: 8n });
    await expect(reorderCourseOutline(actor, '9', 'modules', order)).rejects.toThrow('assigned courses');
    tx.course.findFirst.mockResolvedValue(null);
    await expect(reorderCourseOutline(actor, '9', 'modules', order)).rejects.toThrow('Course not found');
    expect(tx.courseModule.update).not.toHaveBeenCalled();
  });
  it('does not write a stale outline', async () => {
    await expect(reorderCourseOutline(actor, '9', 'modules', { ...order, expectedIds: ['3', '2'] })).rejects.toThrow('outline changed');
    expect(tx.courseModule.update).not.toHaveBeenCalled();
  });
});
