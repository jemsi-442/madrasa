import { expect, it, vi } from 'vitest';
import type { Prisma } from '@prisma/client';
import { institutionOverview } from '../src/modules/platform/institution-overview';

it('counts recorded madrasas once, excludes void Quran records and keeps currencies separate', async () => {
  const tx = {
    organization: { count: vi.fn().mockResolvedValue(2), findMany: vi.fn().mockResolvedValue([
      { id: 1n, name: 'Synthetic school', code: 'AFQ-000001', status: 'ACTIVE', _count: { students: 4, users: 1 } },
    ]) },
    student: { count: vi.fn().mockResolvedValue(4) }, user: { count: vi.fn().mockResolvedValue(1) },
    curriculumLessonDelivery: { groupBy: vi.fn().mockResolvedValue([{ orgId: 1n, _count: { _all: 2 } }]) },
    quranSession: { groupBy: vi.fn().mockResolvedValue([{ orgId: 1n, _count: { _all: 3 } }]) },
    donation: { groupBy: vi.fn().mockResolvedValue([{ currency: 'TZS', _sum: { amount: '10000' } }, { currency: 'USD', _sum: { amount: '5' } }]) },
    donationPledge: { groupBy: vi.fn().mockResolvedValue([]) },
    studentSupportNote: { count: vi.fn().mockResolvedValue(2) },
  };
  const data = await institutionOverview(tx as unknown as Prisma.TransactionClient, new Date('2026-10-31T10:00:00Z'));
  expect(data.summary).toMatchObject({ withLearningRecords: 1, lessonsTaught: 2, quranObservations: 3 });
  expect(data.receipts).toEqual([{ currency: 'TZS', amount: '10000' }, { currency: 'USD', amount: '5' }]);
  expect(data.madrasas[0]?.id).toBe('1');
  expect(tx.quranSession.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: {
    voidedAt: null, learnedOn: { gte: new Date('2026-10-01T00:00:00Z'), lt: new Date('2026-11-01T00:00:00Z') },
  } }));
});
