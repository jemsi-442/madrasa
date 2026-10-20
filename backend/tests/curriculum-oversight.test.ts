import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
const actor = { scope: 'platform' as const, accountId: 'super', sessionId: 's' };
function fixture(role = 'SUPER_ADMIN', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    curriculumAssignment: { findMany: vi.fn().mockResolvedValue([{
      id: 'a1', organizationId: 10n, versionId: 'v1',
      organization: { name: 'Synthetic Madrasa', status: 'ACTIVE' }, subject: { isActive: true },
      version: { subject: 'Arabic', level: 'L1', version: '1.0', _count: { lessons: 3 } },
      adoptions: [{ id: 'c1', classId: 11n, subjectId: 21n }, { id: 'c2', classId: 12n, subjectId: 21n }],
    }]) },
    assessment: { count: vi.fn().mockResolvedValue(3) },
    curriculumLessonDelivery: { groupBy: vi.fn().mockResolvedValue([
      { assignmentId: 'a1', classCurriculumId: 'c1', lessonId: 'l1' },
      { assignmentId: 'a1', classCurriculumId: 'c2', lessonId: 'l1' },
    ]) },
  };
  return { tx, service: new PlatformCurriculumService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
it('reports distinct class lessons using only current scoped adoptions', async () => {
  const { tx, service } = fixture();
  const result = await service.oversight(actor, { page: 2, madrasa: 'Synthetic', subject: 'Arabic', level: 'L1' });
  expect(result.items[0]).toMatchObject({ adoptedClasses: 2, plannedClassLessons: 6, taughtClassLessons: 2, pendingClassLessons: 4 });
  expect(result.items[0]).not.toHaveProperty('organizationId');
  expect(result.assessments).toEqual({ classSubjectScopes: 2, publishedAssessments: 3 });
  expect(tx.assessment.count).toHaveBeenCalledWith({
    where: {
      OR: [
        { orgId: 10n, classId: 11n, subjectId: 21n },
        { orgId: 10n, classId: 12n, subjectId: 21n },
      ],
      releases: { some: { retractedAt: null } },
    },
  });
  expect(tx.curriculumLessonDelivery.groupBy).toHaveBeenCalledWith({
    by: ['assignmentId', 'classCurriculumId', 'lessonId'],
    where: { OR: [{ orgId: 10n, assignmentId: 'a1', classCurriculumId: { in: ['c1', 'c2'] }, lesson: { versionId: 'v1' } }] },
  });
  expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 20, take: 21,
    where: { organization: { name: { contains: 'Synthetic' } }, version: { status: 'PUBLISHED', subject: { contains: 'Arabic' }, level: { contains: 'L1' } } },
  }));
});
for (const role of ['IT_SECURITY', 'ACCOUNTANT']) it(`denies ${role} oversight`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.oversight(actor, {})).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.curriculumAssignment.findMany).not.toHaveBeenCalled();
  expect(tx.assessment.count).not.toHaveBeenCalled();
});
it('rejects inactive accounts and invalid filters', async () => {
  await expect(fixture('SUPER_ADMIN', 'SUSPENDED').service.oversight(actor, {})).rejects.toMatchObject({ statusCode: 403 });
  for (const query of [{ page: 0 }, { page: 10001 }, { level: '' }, { adoption: 'invalid' }, { status: 'UNKNOWN' }, { studentId: '1' }]) {
    await expect(fixture().service.oversight(actor, query)).rejects.toThrow();
  }
});
for (const status of ['ACTIVE', 'TRIAL', 'SUSPENDED', 'PENDING_ACTIVATION']) it(`combines ${status} with madrasa name and adoption filters`, async () => {
  const { service, tx } = fixture();
  await service.oversight(actor, { status, madrasa: 'Synthetic', adoption: 'without', page: 2 });
  expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: expect.objectContaining({ organization: { status, name: { contains: 'Synthetic' } }, adoptions: { none: {} } }),
    skip: 20, take: 21,
  }));
});
for (const adoption of ['with', 'without'] as const) it(`filters ${adoption} class adoptions before pagination`, async () => {
  const { service, tx } = fixture();
  await service.oversight(actor, { adoption, page: 2 });
  expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: expect.objectContaining({ adoptions: adoption === 'with' ? { some: {} } : { none: {} } }),
    skip: 20, take: 21,
  }));
});
it('does not read deliveries for an empty assignment result', async () => {
  const { service, tx } = fixture();
  tx.curriculumAssignment.findMany.mockResolvedValue([]);
  const before = Date.now();
  const result = await service.oversight(actor, {});
  expect(result).toMatchObject({ items: [], page: 1, hasMore: false });
  expect(Date.parse(result.generatedAt)).toBeGreaterThanOrEqual(before);
  expect(Date.parse(result.generatedAt)).toBeLessThanOrEqual(Date.now());
  expect(tx.curriculumLessonDelivery.groupBy).not.toHaveBeenCalled();
  expect(tx.assessment.count).not.toHaveBeenCalled();
  expect(result.assessments).toEqual({ classSubjectScopes: 0, publishedAssessments: 0 });
});
it('shows assignment without adoption as zero coverage, not teaching completion', async () => {
  const { service, tx } = fixture();
  const rows = await tx.curriculumAssignment.findMany();
  rows[0]!.adoptions = [];
  rows[0]!.organization.status = 'SUSPENDED';
  rows[0]!.subject.isActive = false;
  tx.curriculumAssignment.findMany.mockResolvedValue(rows);
  const result = await service.oversight(actor, {});
  expect(result.items[0]).toMatchObject({
    madrasaStatus: 'SUSPENDED', subjectActive: false, adoptedClasses: 0,
    plannedClassLessons: 0, taughtClassLessons: 0, pendingClassLessons: 0,
  });
  expect(tx.curriculumLessonDelivery.groupBy).not.toHaveBeenCalled();
  expect(tx.assessment.count).not.toHaveBeenCalled();
});
it('deduplicates assessment scopes and excludes the pagination lookahead', async () => {
  const { service, tx } = fixture();
  const [row] = await tx.curriculumAssignment.findMany();
  const visible = Array.from({ length: 20 }, (_, i) => ({ ...row!, id: `a${i}` }));
  tx.curriculumAssignment.findMany.mockResolvedValue([
    ...visible,
    { ...row!, id: 'next-page', organizationId: 999n },
  ]);
  const result = await service.oversight(actor, {});
  expect(result.hasMore).toBe(true);
  expect(result.assessments.classSubjectScopes).toBe(2);
  expect(tx.assessment.count).toHaveBeenCalledWith({
    where: {
      OR: [
        { orgId: 10n, classId: 11n, subjectId: 21n },
        { orgId: 10n, classId: 12n, subjectId: 21n },
      ],
      releases: { some: { retractedAt: null } },
    },
  });
  expect(() => JSON.stringify(result)).not.toThrow();
});
