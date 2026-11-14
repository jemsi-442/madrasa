import { beforeEach, describe, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({ course: { findFirst: vi.fn() }, courseModule: { findMany: vi.fn() } }));
vi.mock('../src/shared/db/prisma', () => ({ prisma: db }));
import { listCourseModules } from '../src/modules/learning/learning.service';
import type { AuthenticatedUser } from '../src/shared/middleware/authenticate';

const teacher = { userId: '3', orgId: '1', role: 'TEACHER' } as AuthenticatedUser;
const moduleRecord = {
  id: 2n, orgId: 1n, courseId: 7n, title: 'Synthetic module', position: 1,
  summary: null, createdAt: new Date('2026-01-01'), updatedAt: new Date('2026-01-01'),
  _count: { lessons: 2 },
};

describe('teacher module summary', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    db.course.findFirst.mockResolvedValue({ id: 7n, orgId: 1n, primaryInstructorUserId: 3n });
  });
  it('returns actual resources and total estimated lesson duration', async () => {
    db.courseModule.findMany.mockResolvedValue([{ ...moduleRecord, lessons: [
      { estimatedMinutes: 10, _count: { assets: 2 } },
      { estimatedMinutes: 20, _count: { assets: 3 } },
    ] }]);
    const result = await listCourseModules(teacher, '7');
    expect(result[0]?.stats).toEqual({ lessons: 2, resources: 5, estimatedMinutes: 30 });
    expect(db.course.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 7n, orgId: 1n } }));
    expect(db.courseModule.findMany).toHaveBeenCalledWith(expect.objectContaining({
      select: expect.objectContaining({ lessons: expect.objectContaining({ where: { orgId: 1n, courseId: 7n } }) }),
    }));
  });
  it('does not present a partial duration as a total', async () => {
    db.courseModule.findMany.mockResolvedValue([{ ...moduleRecord, lessons: [
      { estimatedMinutes: null, _count: { assets: 0 } },
      { estimatedMinutes: 20, _count: { assets: 1 } },
    ] }]);
    expect((await listCourseModules(teacher, '7'))[0]?.stats?.estimatedMinutes).toBeNull();
  });
  it('does not return metadata to an unassigned teacher', async () => {
    db.course.findFirst.mockResolvedValue({ id: 7n, orgId: 1n, primaryInstructorUserId: 9n });
    await expect(listCourseModules(teacher, '7')).rejects.toThrow('assigned to you');
    expect(db.courseModule.findMany).not.toHaveBeenCalled();
  });
  it('does not query modules when the scoped course is absent', async () => {
    db.course.findFirst.mockResolvedValue(null);
    await expect(listCourseModules(teacher, '7')).rejects.toThrow('Course not found');
    expect(db.courseModule.findMany).not.toHaveBeenCalled();
  });
});
