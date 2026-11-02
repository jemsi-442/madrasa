import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
import { auditReportPdf } from '../src/shared/utils/audit-report-pdf';

vi.mock('../src/shared/utils/audit-report-pdf', () => ({ auditReportPdf: vi.fn() }));
const actor = { scope: 'platform' as const, accountId: 'it', sessionId: 'session' };
function fixture(role = 'IT_SECURITY', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'it', role, status }) },
    platformAuditEvent: {
      findMany: vi.fn().mockResolvedValue([{
        id: 'event', actorId: 'operator', actorRole: 'IT_SECURITY',
        action: 'platform.login.failed', entityType: 'Account', entityId: 'target',
        createdAt: new Date('2026-11-02T10:00:00Z'), metadata: { token: 'private-test-marker' },
      }]),
      create: vi.fn().mockResolvedValue({ id: 'export-event' }),
    },
  };
  const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformGovernanceService(db) };
}
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auditReportPdf).mockResolvedValue(Buffer.from('%PDF-test'));
});
describe('IT audit PDF export', () => {
  it('renders server records only and audits generation before returning the PDF', async () => {
    const { tx, service } = fixture();
    const result = await service.exportAuditEvents(actor, { ids: ['event'] });
    expect(tx.platformAuditEvent.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: { in: ['event'] } },
      select: { id: true, actorId: true, actorRole: true, action: true, entityType: true, entityId: true, createdAt: true },
    }));
    expect(JSON.stringify(vi.mocked(auditReportPdf).mock.calls)).not.toContain('private-test-marker');
    expect(vi.mocked(auditReportPdf).mock.calls[0]?.[0][0]).toEqual({
      id: 'event', actorId: 'operator', actorRole: 'IT_SECURITY',
      action: 'platform.login.failed', entityType: 'Account', entityId: 'target',
      createdAt: new Date('2026-11-02T10:00:00Z'),
    });
    expect(tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      actorId: 'it', action: 'platform.audit.exported',
      metadata: expect.objectContaining({ count: 1, eventIds: ['event'] }),
    }) });
    expect(Buffer.from(result.base64, 'base64').toString()).toBe('%PDF-test');
    expect(result.fileName).toMatch(/^afaq-audit-\d{4}-\d{2}-\d{2}\.pdf$/);
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT'])('rejects %s', async role => {
    const { tx, service } = fixture(role);
    await expect(service.exportAuditEvents(actor, { ids: ['event'] })).rejects.toMatchObject({ statusCode: 403 });
    expect(tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
    expect(auditReportPdf).not.toHaveBeenCalled();
  });
  it('rejects disabled IT accounts', async () => {
    const { tx, service } = fixture('IT_SECURITY', 'DISABLED');
    await expect(service.exportAuditEvents(actor, { ids: ['event'] })).rejects.toMatchObject({ statusCode: 403 });
    expect(tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
  it.each([{ ids: [] }, { ids: ['event', 'event'] }, { ids: Array.from({ length: 21 }, (_, i) => `event-${i}`) },
    { ids: ['event'], rows: ['client content'] }])('rejects invalid selection %j', async input => {
    const { tx, service } = fixture();
    await expect(service.exportAuditEvents(actor, input)).rejects.toThrow();
    expect(tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
  it('does not export a partial selection', async () => {
    const { tx, service } = fixture();
    tx.platformAuditEvent.findMany.mockResolvedValue([]);
    await expect(service.exportAuditEvents(actor, { ids: ['event'] })).rejects.toMatchObject({ statusCode: 409 });
    expect(auditReportPdf).not.toHaveBeenCalled();
    expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('does not record success when rendering fails', async () => {
    const { tx, service } = fixture();
    vi.mocked(auditReportPdf).mockRejectedValueOnce(new Error('render failed'));
    await expect(service.exportAuditEvents(actor, { ids: ['event'] })).rejects.toThrow('render failed');
    expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('does not return a report when recording the export fails', async () => {
    const { tx, service } = fixture();
    tx.platformAuditEvent.create.mockRejectedValueOnce(new Error('audit failed'));
    await expect(service.exportAuditEvents(actor, { ids: ['event'] })).rejects.toThrow('audit failed');
  });
});
