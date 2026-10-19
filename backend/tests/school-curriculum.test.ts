import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import type { AuthenticatedUser } from '../src/shared/middleware/authenticate';
import { SchoolCurriculumService } from '../src/modules/learning/school-curriculum';

const admin: AuthenticatedUser = { userId: '1', orgId: '10', role: 'ADMIN', branchId: '20' };
const input = { assignmentId: 'assigned-v1', classId: '30', subjectId: '40' };
function fixture() {
  const tx = {
    user: { findFirst: vi.fn().mockResolvedValue({ id: 1n }) },
    curriculumAssignment: {
      findFirst: vi.fn().mockResolvedValue({ id: 'assigned-v1', subjectId: null }),
      findMany: vi.fn().mockResolvedValue([]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    class: { findFirst: vi.fn().mockResolvedValue({ id: 30n }), findMany: vi.fn().mockResolvedValue([]) },
    subject: { findFirst: vi.fn().mockResolvedValue({ id: 40n }), findMany: vi.fn().mockResolvedValue([]) },
    classCurriculum: {
      findUnique: vi.fn().mockResolvedValue(null),
      findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ id: 'adoption', orgId: 10n }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    classCurriculumHistory: { create: vi.fn().mockResolvedValue({ id: 'history' }) },
    curriculumLessonDelivery: { findMany: vi.fn().mockResolvedValue([]), groupBy: vi.fn().mockResolvedValue([]) },
    curriculumLesson: { count: vi.fn().mockResolvedValue(3), findMany: vi.fn().mockResolvedValue([]) },
    auditLog: { create: vi.fn() },
  };
  const db = { $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
  return { tx, service: new SchoolCurriculumService(db) };
}
describe('school curriculum boundaries', () => {
  it('loads distinct current-version teaching counts in one scoped query', async () => {
    const { tx, service } = fixture();
    tx.curriculumAssignment.findMany.mockResolvedValue([{
      id: 'assigned-v1', subjectId: 40n,
      version: { id: 'v1', version: '1.0', lessons: [{ id: 'lesson-a' }, { id: 'lesson-b' }] },
      adoptions: [{ id: 'class-a' }, { id: 'class-b' }],
    }]);
    tx.curriculumLessonDelivery.groupBy.mockResolvedValue([
      { assignmentId: 'assigned-v1', classCurriculumId: 'class-a', lessonId: 'lesson-a' },
      { assignmentId: 'assigned-v1', classCurriculumId: 'class-a', lessonId: 'lesson-b' },
    ]);
    const data = await service.list(admin);
    expect(data.assignments[0].adoptions.map((row: { teachingCoverage: unknown }) => row.teachingCoverage)).toEqual([
      { version: '1.0', taughtLessons: 2, totalLessons: 2 },
      { version: '1.0', taughtLessons: 0, totalLessons: 2 },
    ]);
    expect(tx.curriculumLessonDelivery.groupBy).toHaveBeenCalledExactlyOnceWith({
      by: ['classCurriculumId', 'assignmentId', 'lessonId'],
      where: { orgId: 10n, OR: [{ assignmentId: 'assigned-v1', classCurriculumId: { in: ['class-a', 'class-b'] }, lesson: { versionId: 'v1' } }] },
    });
  });
  it('does not query teaching records without visible adopted classes', async () => {
    const { service, tx } = fixture();
    await service.list(admin);
    expect(tx.curriculumLessonDelivery.groupBy).not.toHaveBeenCalled();
  });
  it('pages scoped teaching history without exposing event IDs or login details', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findFirst.mockResolvedValue({ id: 'adoption', assignmentId: 'assigned-v1', assignment: { versionId: 'v1', version: { version: '1.0' } } });
    tx.curriculumLessonDelivery.findMany.mockResolvedValue(Array.from({ length: 21 }, (_, i) => ({ id: `${i}` })));
    const result = await service.deliveryHistory(admin, { classCurriculumId: 'adoption', page: '2' });
    expect(result.items).toHaveLength(20);
    expect(result).toMatchObject({ page: 2, hasMore: true });
    expect(result.teachingCoverage).toEqual({ version: '1.0', taughtLessons: 0, totalLessons: 3 });
    expect(tx.curriculumLessonDelivery.groupBy).toHaveBeenCalledWith({
      by: ['lessonId'], where: {
        orgId: 10n, classCurriculumId: 'adoption', assignmentId: 'assigned-v1', lesson: { versionId: 'v1' },
      },
    });
    expect(tx.curriculumLessonDelivery.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { orgId: 10n, classCurriculumId: 'adoption' }, skip: 20, take: 21,
      select: expect.objectContaining({ teacher: { select: { fullName: true } } }),
    }));
    expect(tx.curriculumLessonDelivery.findMany.mock.calls[0]![0].select).not.toHaveProperty('clientEventId');
  });
  it('rejects inaccessible history before reading delivery records', async () => {
    const { tx, service } = fixture();
    await expect(service.deliveryHistory({ ...admin, role: 'TEACHER' }, { classCurriculumId: 'other' }))
      .rejects.toMatchObject({ statusCode: 404 });
    expect(tx.curriculumLessonDelivery.findMany).not.toHaveBeenCalled();
    expect(tx.curriculumLesson.findMany).not.toHaveBeenCalled();
  });
  it('returns a bounded pending lesson list from only the current version', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findFirst.mockResolvedValue({ id: 'adoption', assignmentId: 'assigned-v2', assignment: { versionId: 'v2', version: { version: '2.0' } } });
    tx.curriculumLessonDelivery.groupBy.mockResolvedValue([{ lessonId: 'taught-lesson' }]);
    tx.curriculumLesson.findMany.mockResolvedValue([{ id: 'pending-lesson', title: 'Synthetic reading' }]);
    const result = await service.deliveryHistory(admin, { classCurriculumId: 'adoption' });
    expect(result.pendingLessons).toEqual([{ id: 'pending-lesson', title: 'Synthetic reading' }]);
    expect(tx.curriculumLesson.findMany).toHaveBeenCalledExactlyOnceWith({
      where: { versionId: 'v2', id: { notIn: ['taught-lesson'] } },
      orderBy: [{ position: 'asc' }, { id: 'asc' }], take: 10,
      select: { id: true, title: true },
    });
  });
  it('rejects invalid history pagination', async () => {
    const { tx, service } = fixture();
    for (const page of [0, -1, 1.5, 10001, 'bad']) {
      await expect(service.deliveryHistory(admin, { classCurriculumId: 'adoption', page })).rejects.toThrow();
    }
    expect(tx.curriculumLessonDelivery.findMany).not.toHaveBeenCalled();
  });
  describe('online lesson delivery input and role boundaries', () => {
    const teacher: AuthenticatedUser = { ...admin, role: 'TEACHER' };
    const delivery = {
      classCurriculumId: 'adoption', assignmentId: 'assigned-v1', lessonId: 'lesson-1',
      clientEventId: '20f05979-54b4-4ff9-bb7b-1131b99a2a86',
    };
    for (const role of ['ADMIN', 'ACCOUNTANT', 'PARENT'] as const) {
      it(`does not allow ${role} to record teaching`, async () => {
        const { service, tx } = fixture();
        await expect(service.recordDelivery({ ...admin, role }, delivery)).rejects.toMatchObject({ statusCode: 403 });
        expect(tx.classCurriculum.findFirst).not.toHaveBeenCalled();
      });
    }
    for (const extra of [{ taughtAt: '2026-01-01T00:00:00Z' }, { teacherId: '2' }, { orgId: '99' }, { achievement: true }]) {
      it(`rejects caller-supplied ${Object.keys(extra)[0]}`, async () => {
        const { service, tx } = fixture();
        await expect(service.recordDelivery(teacher, { ...delivery, ...extra })).rejects.toThrow();
        expect(tx.user.findFirst).not.toHaveBeenCalled();
      });
    }
    it('rechecks active account and class scope before accepting an event', async () => {
      const { service, tx } = fixture();
      await expect(service.recordDelivery(teacher, delivery)).rejects.toMatchObject({ statusCode: 404 });
      expect(tx.classCurriculum.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: {
        id: 'adoption', orgId: 10n, class: { orgId: 10n, branchId: 20n, teacherId: 1n },
      } }));
      tx.user.findFirst.mockResolvedValue(null);
      await expect(service.recordDelivery(teacher, delivery)).rejects.toMatchObject({ statusCode: 403 });
    });
    it('requires a valid client event identifier', async () => {
      const { service, tx } = fixture();
      await expect(service.recordDelivery(teacher, { ...delivery, clientEventId: 'invalid' })).rejects.toThrow();
      expect(tx.user.findFirst).not.toHaveBeenCalled();
    });
  });
  it('adopts an assigned published version using scoped existing class and subject', async () => {
    const { tx, service } = fixture();
    expect(await service.adopt(admin, input)).toEqual({ id: 'adoption', orgId: '10' });
    expect(tx.curriculumAssignment.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: input.assignmentId, organizationId: 10n, version: { status: 'PUBLISHED' } } }));
    expect(tx.class.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 30n, orgId: 10n, branchId: 20n } }));
    expect(tx.subject.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 40n, orgId: 10n, isActive: true } }));
    expect(tx.curriculumAssignment.updateMany).toHaveBeenCalledWith({
      where: { id: input.assignmentId, organizationId: 10n, subjectId: null },
      data: { subjectId: 40n },
    });
    expect(tx.auditLog.create).toHaveBeenCalledOnce();
  });
  it('does not allow one madrasa assignment to be adopted under a different subject', async () => {
    const { tx, service } = fixture();
    tx.curriculumAssignment.findFirst.mockResolvedValue({ id: input.assignmentId, subjectId: 41n });
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 422 });
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    expect(tx.classCurriculumHistory.create).not.toHaveBeenCalled();
  });
  it('does not adopt against a mapped school subject that is no longer active', async () => {
    const { tx, service } = fixture();
    tx.curriculumAssignment.findFirst.mockResolvedValue({
      id: input.assignmentId,
      subjectId: 40n,
    });
    tx.subject.findFirst.mockResolvedValue(null);

    await expect(service.adopt(admin, input)).rejects.toMatchObject({
      statusCode: 404,
    });
    expect(tx.curriculumAssignment.updateMany).not.toHaveBeenCalled();
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    expect(tx.classCurriculumHistory.create).not.toHaveBeenCalled();
  });
  it('does not infer a mapping that conflicts with legacy class adoption', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findFirst.mockResolvedValue({ id: 'legacy-adoption' });
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 409 });
    expect(tx.curriculumAssignment.updateMany).not.toHaveBeenCalled();
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
  });
  it('returns the assignment subject mapping to administrators for a locked UI choice', async () => {
    const { tx, service } = fixture();
    tx.curriculumAssignment.findMany.mockResolvedValue([{ id: 'assigned-v1', subjectId: 40n, version: {}, adoptions: [] }]);
    tx.subject.findMany.mockResolvedValue([{ id: 40n, name: 'Arabic', isActive: true }]);
    const result = await service.list(admin);
    expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({
      select: expect.objectContaining({ subjectId: true }),
    }));
    expect(tx.subject.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { orgId: 10n, OR: [{ isActive: true }, { id: { in: [40n] } }] },
    }));
    expect(result.subjects).toEqual([{ id: '40', name: 'Arabic', isActive: true }]);
  });
  it('accepts the same subject mapping when another request wins the assignment race', async () => {
    const { tx, service } = fixture();
    tx.curriculumAssignment.findFirst
      .mockResolvedValueOnce({ id: input.assignmentId, subjectId: null })
      .mockResolvedValueOnce({ subjectId: 40n });
    tx.curriculumAssignment.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.adopt(admin, input)).resolves.toMatchObject({ id: 'adoption' });
    expect(tx.classCurriculum.create).toHaveBeenCalledOnce();
  });
  for (const missing of ['class', 'subject', 'curriculumAssignment'] as const) {
    it(`rejects unavailable or out-of-scope ${missing}`, async () => {
      const { tx, service } = fixture(); tx[missing].findFirst.mockResolvedValue(null);
      await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 404 });
      expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    });
  }
  it('makes repeat adoption idempotent', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findUnique.mockResolvedValue({ id: 'existing', assignmentId: input.assignmentId });
    expect(await service.adopt(admin, input)).toMatchObject({ id: 'existing' });
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    expect(tx.classCurriculumHistory.create).not.toHaveBeenCalled();
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });
  it('archives the active adoption before upgrading a class to a new version', async () => {
    const { tx, service } = fixture();
    const adoptedAt = new Date('2026-09-01T08:00:00Z');
    tx.classCurriculum.findUnique.mockResolvedValue({
      id: 'existing', assignmentId: 'older-assignment', adoptedBy: 1n, createdAt: adoptedAt,
    });
    const result = await service.adopt(admin, input);
    expect(tx.classCurriculumHistory.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      classCurriculumId: 'existing', orgId: 10n, classId: 30n, subjectId: 40n,
      previousAssignmentId: 'older-assignment', previousAdoptedBy: 1n, previousAdoptedAt: adoptedAt,
      replacedBy: 1n,
    }) });
    expect(tx.classCurriculum.updateMany).toHaveBeenCalledWith({
      where: { id: 'existing', assignmentId: 'older-assignment', orgId: 10n },
      data: expect.objectContaining({ assignmentId: input.assignmentId, adoptedBy: 1n }),
    });
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      action: 'curriculum.class.version_changed',
      metadata: expect.objectContaining({ previousAssignmentId: 'older-assignment', assignmentId: input.assignmentId }),
    }) });
    expect(result).toMatchObject({ id: 'existing', assignmentId: input.assignmentId });
  });
  it('rolls the replacement transaction back when the active adoption changed concurrently', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findUnique.mockResolvedValue({ id: 'existing', assignmentId: 'older-assignment', adoptedBy: 2n, createdAt: new Date() });
    tx.classCurriculum.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 409 });
    expect(tx.classCurriculumHistory.create).toHaveBeenCalledOnce();
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });
  it('restricts teacher reads to adopted assigned classes and hides school subject choices', async () => {
    const { tx, service } = fixture();
    await service.list({ ...admin, role: 'TEACHER', userId: '5' });
    expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: {
      organizationId: 10n, version: { status: 'PUBLISHED' }, adoptions: { some: { class: { orgId: 10n, branchId: 20n, teacherId: 5n } } },
    } }));
    expect(tx.subject.findMany).not.toHaveBeenCalled();
    await expect(service.adopt({ ...admin, role: 'TEACHER' }, input)).rejects.toMatchObject({ statusCode: 403 });
  });
  it('denies accountant access and inactive users', async () => {
    const { tx, service } = fixture();
    await expect(service.list({ ...admin, role: 'ACCOUNTANT' })).rejects.toMatchObject({ statusCode: 403 });
    tx.user.findFirst.mockResolvedValue(null);
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 403 });
    expect(tx.user.findFirst).toHaveBeenCalledWith({ where: {
      id: 1n, orgId: 10n, role: 'ADMIN', status: 'ACTIVE', branchId: 20n,
      organization: { status: { in: ['ACTIVE', 'TRIAL'] } },
    }, select: { id: true } });
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
  });
  it('rejects client supplied tenant and actor fields', async () => {
    const { service } = fixture();
    await expect(service.adopt(admin, { ...input, orgId: '99', adoptedBy: '99' })).rejects.toThrow();
  });
  it('rejects identifiers outside the database BIGINT range before querying', async () => {
    const { tx, service } = fixture();
    await expect(service.adopt(admin, {
      ...input,
      classId: '9223372036854775808',
    })).rejects.toThrow();
    expect(tx.user.findFirst).not.toHaveBeenCalled();
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
  });
});
