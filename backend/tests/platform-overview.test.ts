import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
const actor = { scope: 'platform' as const, accountId: 'admin', sessionId: 'session' };
function fixture(role = 'SUPER_ADMIN') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'admin', role, status: 'ACTIVE' }), groupBy: vi.fn().mockResolvedValue([{ role: 'IT_SECURITY', status: 'DISABLED', _count: { _all: 2 } }]) },
    tenantApplication: { groupBy: vi.fn().mockResolvedValue([{ status: 'REQUESTED', _count: { _all: 3 } }]), count: vi.fn().mockResolvedValue(1) },
    organization: { count: vi.fn().mockResolvedValue(2), findMany: vi.fn().mockResolvedValue([
      { id: 1n, name: 'Synthetic Madrasa', code: 'test-madrasa', status: 'ACTIVE', _count: { students: 8, users: 2 } },
      { id: 2n, name: 'Synthetic Second Madrasa', code: 'test-second', status: 'ACTIVE', _count: { students: 4, users: 1 } },
    ]) },
    student: { count: vi.fn().mockResolvedValue(12) },
    user: { count: vi.fn().mockResolvedValue(3) },
    curriculumLessonDelivery: { groupBy: vi.fn().mockResolvedValue([{ orgId: 1n, _count: { _all: 5 } }]) },
    quranSession: { groupBy: vi.fn().mockResolvedValue([{ orgId: 1n, _count: { _all: 7 } }]) },
    donation: { groupBy: vi.fn().mockResolvedValue([{ currency: 'TZS', _sum: { amount: '1200.50' } }]) },
    donationPledge: { groupBy: vi.fn().mockResolvedValue([{ currency: 'TZS', _sum: { amount: '2000.00' } }]) },
    studentSupportNote: { count: vi.fn().mockResolvedValue(2) },
  };
  return { tx, service: new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient) };
}
describe('platform governance overview', () => {
  it('aggregates platform counts and excludes own requests from independent review', async () => {
    const f = fixture();
    const result = await f.service.overview(actor);
    expect(result).toMatchObject({ applications: { REQUESTED: 3, APPROVED: 0, REJECTED: 0 }, awaitingYourReview: 1,
      accounts: { SUPER_ADMIN: { ACTIVE: 0, DISABLED: 0 }, IT_SECURITY: { ACTIVE: 0, DISABLED: 2 } } });
    expect(f.tx.tenantApplication.count).toHaveBeenCalledWith({ where: { status: 'REQUESTED', requestedById: { not: 'admin' } } });
    expect(f.tx.platformAccount.groupBy).toHaveBeenCalledWith({ by: ['role', 'status'], _count: { _all: true } });
    expect(result.onboarding).toEqual({ awaitingSetup: 1, pendingActivation: 1 });
    expect(f.tx.tenantApplication.count).toHaveBeenCalledWith({ where: { status: 'APPROVED', organizationId: null } });
    expect(f.tx.tenantApplication.count).toHaveBeenCalledWith({ where: { status: 'APPROVED', organization: { is: { status: 'PENDING_ACTIVATION' } } } });
    expect(Number.isNaN(Date.parse(result.checkedAt))).toBe(false);
    expect(result.institution.summary).toEqual({ madrasas: 2, learners: 12, teachers: 3,
      withLearningRecords: 1, openSupportNotes: 2, lessonsTaught: 5, quranObservations: 7 });
    expect(result.institution.madrasas).toEqual([
      expect.objectContaining({ id: '1', learners: 8, teachers: 2, hasLearningRecords: true }),
      expect.objectContaining({ id: '2', learners: 4, teachers: 1, hasLearningRecords: false }),
    ]);
    expect(result.institution.receipts).toEqual([{ currency: 'TZS', amount: '1200.50' }]);
    expect(result.institution.pledges).toEqual([{ currency: 'TZS', amount: '2000.00' }]);
    expect(f.tx.user.count).toHaveBeenCalledWith({ where: { role: 'TEACHER', status: 'ACTIVE' } });
    expect(f.tx.donation.groupBy).toHaveBeenCalledWith(expect.objectContaining({
      where: { status: 'RECEIVED', receivedAt: { gte: expect.any(Date), lt: expect.any(Date) } },
    }));
  });
  it.each(['IT_SECURITY', 'ADMIN'])('denies %s without reading aggregates', async (role) => {
    const f = fixture(role);
    await expect(f.service.overview(actor)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.groupBy).not.toHaveBeenCalled();
    expect(f.tx.organization.count).not.toHaveBeenCalled();
  });
  it('does not return fabricated zeros on database failure', async () => {
    const f = fixture(); f.tx.tenantApplication.groupBy.mockRejectedValue(new Error('database unavailable'));
    await expect(f.service.overview(actor)).rejects.toThrow('database unavailable');
  });
  it('fails the whole snapshot if onboarding counts are unavailable', async () => {
    const f = fixture();
    f.tx.tenantApplication.count.mockResolvedValueOnce(1).mockRejectedValueOnce(new Error('onboarding unavailable'));
    await expect(f.service.overview(actor)).rejects.toThrow('onboarding unavailable');
  });
  it('fails the whole snapshot when institution data is unavailable', async () => {
    const f = fixture();
    f.tx.student.count.mockRejectedValue(new Error('institution unavailable'));
    await expect(f.service.overview(actor)).rejects.toThrow('institution unavailable');
  });
});
