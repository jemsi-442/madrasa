import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 's' };
function fixture(role = 'SUPER_ADMIN') {
  const tx = {
    $queryRaw: vi.fn().mockResolvedValue([{ orgId: 1n, learners: 2n, trackedLessons: 5n, completedLessons: 3n }]),
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status: 'ACTIVE' }) },
    organization: { findMany: vi.fn().mockResolvedValue([{ id: 1n, name: 'Synthetic Madrasa', status: 'ACTIVE' }]) },
    student: { groupBy: vi.fn().mockResolvedValueOnce([{ orgId: 1n, _count: { _all: 6 } }])
      .mockResolvedValueOnce([{ orgId: 1n, _count: { _all: 2 } }])
      .mockResolvedValueOnce([{ orgId: 1n, _count: { _all: 1 } }]) },
  };
  return { tx, service: new PlatformCurriculumService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
it('returns per-madrasa counts without curriculum adoption or learner identifiers', async () => {
  const { tx, service } = fixture();
  const before = Date.now();
  const result = await service.madrasaOversight(actor, { quranMonth: '2026-10', page: 2 });
  expect(Date.parse(result.generatedAt)).toBeGreaterThanOrEqual(before);
  expect(Date.parse(result.generatedAt)).toBeLessThanOrEqual(Date.now());
  expect(result.items[0]).toEqual({ id: '1', name: 'Synthetic Madrasa', status: 'ACTIVE', eligible: 6, recorded: 2, unrecorded: 4, needingSupport: 1,
    courseActivity: { period: 'ALL_TIME', learners: 2, trackedLessons: 5, completedLessons: 3 } });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 20, take: 21 }));
  expect(tx.student.groupBy).toHaveBeenNthCalledWith(2, {
    by: ['orgId'], _count: { _all: true }, where: { status: 'ACTIVE', orgId: { in: [1n] },
      quranSessions: { some: { voidedAt: null, learnedOn: { gte: new Date('2026-10-01'), lt: new Date('2026-11-01') } } } },
  });
  expect(JSON.stringify(result)).not.toContain('studentId');
});
it('does not query learners when no madrasas match', async () => {
  const { tx, service } = fixture();
  tx.organization.findMany.mockResolvedValue([]);
  expect((await service.madrasaOversight(actor, {})).items).toEqual([]);
  expect(tx.student.groupBy).not.toHaveBeenCalled();
  expect(tx.$queryRaw).not.toHaveBeenCalled();
});
for (const role of ['IT_SECURITY', 'ACCOUNTANT']) it(`denies ${role}`, async () => {
  const { tx, service } = fixture(role);
  await expect(service.madrasaOversight(actor, {})).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.organization.findMany).not.toHaveBeenCalled();
  expect(tx.$queryRaw).not.toHaveBeenCalled();
});
it('excludes lookahead organization from counts', async () => {
  const { tx, service } = fixture();
  tx.organization.findMany.mockResolvedValue(Array.from({ length: 21 }, (_, i) => ({ id: BigInt(i + 1), name: 'Synthetic', status: 'ACTIVE' })));
  const result = await service.madrasaOversight(actor, {});
  expect(result.hasMore).toBe(true);
  expect(result.items).toHaveLength(20);
  expect(tx.student.groupBy.mock.calls[0]![0].where.orgId.in).not.toContain(21n);
  expect(tx.$queryRaw.mock.calls[0]![0].values).toEqual(Array.from({ length: 20 }, (_, i) => BigInt(i + 1)));
});
