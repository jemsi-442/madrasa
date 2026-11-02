import { expect, it } from 'vitest';
import { writeFileSync } from 'node:fs';
import { auditReportPdf } from '../src/shared/utils/audit-report-pdf';

it('renders a branded multipage audit summary with full reference records', async () => {
  const events = Array.from({ length: 20 }, (_, index) => ({
    id: `synthetic-event-${index + 1}`, actorId: 'synthetic-operator-000000000000',
    actorRole: index % 2 ? 'SUPER_ADMIN' : 'IT_SECURITY',
    action: index % 2 ? 'platform.login.succeeded' : 'platform.login.failed',
    entityType: 'PlatformAccount', entityId: 'synthetic-reference-000000000000',
    createdAt: new Date('2026-11-02T10:00:00Z'),
  }));
  const pdf = await auditReportPdf(events, '2026-11-02T11:00:00Z');
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1')).toContain('/Subtype /Image');
  expect(pdf.toString('latin1')).not.toContain('/Count 1\n');
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-audit-preview.pdf', pdf);
});
