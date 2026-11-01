import { expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { InstitutionalReportsService } from '../src/modules/platform/platform.reports';

const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 's' };
const input = { month: '2026-12', sections: ['attendance', 'learning', 'donations', 'followups'] };
const requestId = 'd480c28b-a68b-4d9f-895c-e7caaed77030';
function fixture(role = 'SUPER_ADMIN', status = 'ACTIVE') {
  const counted = () => ({ groupBy: vi.fn().mockResolvedValue([{ orgId: 1n, _count: { _all: 3 } }]) });
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}) },
    organization: { findMany: vi.fn().mockResolvedValue([{ id: 1n, name: 'Synthetic madrasa', code: 'AFQ-TEST' }, { id: 2n, name: 'Empty madrasa', code: 'AFQ-EMPTY' }]) },
    attendanceRecord: counted(), curriculumLessonDelivery: counted(), quranSession: counted(), studentSupportNote: counted(),
    donation: { groupBy: vi.fn().mockResolvedValue([
      { orgId: 1n, currency: 'TZS', _sum: { amount: new Prisma.Decimal('100.01') } },
      { orgId: 1n, currency: 'USD', _sum: { amount: new Prisma.Decimal('2.02') } },
    ]) },
    institutionalReport: { findUnique: vi.fn().mockResolvedValue(null), create: vi.fn().mockResolvedValue({ id: 'cm00000000000000000000001' }), findMany: vi.fn().mockResolvedValue([]) },
  };
  const db = { ...tx, $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
  return { tx, service: new InstitutionalReportsService(db) };
}
it('uses month boundaries, nonvoided Quran records, currency-separated receipts and honest readiness', async () => {
  const { service, tx } = fixture();
  const result = await service.preview(actor, input);
  expect(result.items[0]?.receipts).toEqual([{ currency: 'TZS', amount: '100.01' }, { currency: 'USD', amount: '2.02' }]);
  expect(result.items[1]?.hasData).toBe(false);
  expect(tx.quranSession.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: {
    orgId: { in: [1n, 2n] }, learnedOn: { gte: new Date('2026-12-01'), lt: new Date('2027-01-01') }, voidedAt: null,
  } }));
  expect(tx.studentSupportNote.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ OR: [{ resolvedAt: null }, { resolvedAt: { gte: new Date('2027-01-01') } }] }) }));
});
it('omits deselected sections and validates school scope and inputs', async () => {
  const { service, tx } = fixture();
  await service.preview(actor, { ...input, organizationId: '1', sections: ['attendance'] });
  expect(tx.organization.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ id: 1n }) }));
  expect(tx.donation.groupBy).not.toHaveBeenCalled();
  expect(tx.quranSession.groupBy).not.toHaveBeenCalled();
  for (const sections of [[], ['attendance', 'attendance'], ['unknown']]) await expect(service.preview(actor, { ...input, sections })).rejects.toThrow();
  tx.organization.findMany.mockResolvedValue([]);
  await expect(service.preview(actor, { ...input, organizationId: '99' })).rejects.toMatchObject({ statusCode: 404 });
});
for (const role of ['IT_SECURITY', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT']) it(`denies ${role} on every operation`, async () => {
  const { service, tx } = fixture(role);
  for (const operation of [() => service.options(actor), () => service.preview(actor, input), () => service.generate(actor, { ...input, requestId }), () => service.list(actor, {}), () => service.pdf(actor, 'cm00000000000000000000001')]) {
    await expect(operation()).rejects.toMatchObject({ statusCode: 403 });
  }
  expect(tx.organization.findMany).not.toHaveBeenCalled();
});
it('blocks disabled platform accounts', async () => {
  await expect(fixture('SUPER_ADMIN', 'DISABLED').service.preview(actor, input)).rejects.toMatchObject({ statusCode: 403 });
});
it('saves immutable snapshots, reuses request ids and downloads stored data without querying live records', async () => {
  const { service, tx } = fixture();
  const result = await service.generate(actor, { ...input, requestId });
  const snapshot = tx.institutionalReport.create.mock.calls[0]![0].data.snapshot;
  tx.institutionalReport.findUnique.mockResolvedValue({ ...result, snapshot, month: input.month } as never);
  expect(await service.generate(actor, { ...input, requestId })).toEqual(result);
  expect(tx.institutionalReport.create).toHaveBeenCalledTimes(1);
  await expect(service.generate(actor, { ...input, requestId, month: '2026-11' })).rejects.toMatchObject({ statusCode: 409 });
  tx.organization.findMany.mockClear();
  const pdf = await service.pdf(actor, result.id);
  expect(Buffer.from(pdf.base64, 'base64').subarray(0, 4).toString()).toBe('%PDF');
  expect(tx.organization.findMany).not.toHaveBeenCalled();
  if (process.env.AFAQ_PDF_PREVIEW === 'true') {
    const { writeFile } = await import('node:fs/promises');
    await writeFile('/tmp/afaq-institution-preview.pdf', Buffer.from(pdf.base64, 'base64'));
  }
});
it('paginates history and refuses empty-scope generation', async () => {
  const { service, tx } = fixture();
  await service.list(actor, { page: 2 });
  expect(tx.institutionalReport.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 10, take: 11 }));
  tx.organization.findMany.mockResolvedValue([]);
  await expect(service.generate(actor, { ...input, requestId })).rejects.toMatchObject({ statusCode: 422 });
});
