import { expect, it, vi } from 'vitest';
import PDFDocument from 'pdfkit';
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
  const pageCount = Number(pdf.toString('latin1').match(/\/Type \/Pages\s+[\s\S]*?\/Count (\d+)/)?.[1]);
  expect(pageCount).toBeGreaterThan(1);
  expect(pageCount).toBeLessThanOrEqual(7);
  const source = pdf.toString('latin1');
  expect(source).toContain('/Outlines');
  expect(source.match(/\/S \/GoTo\b/g)).toHaveLength(40);
  for (let number = 1; number <= 20; number++) {
    expect(source).toContain(`(reference-${number})`);
    expect(source).toContain(`(summary-${number})`);
  }
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-audit-preview.pdf', pdf);
});

it('renders an unpaired reference card with missing optional identifiers', async () => {
  const pdf = await auditReportPdf([{
    id: 'synthetic-single', actorId: null, actorRole: null,
    action: 'synthetic.unknown.action', entityType: null, entityId: null,
    createdAt: new Date('2026-11-02T10:00:00Z'),
  }], '2026-11-02T11:00:00Z');
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1')).toContain('/Count 2\n');
});

it('keeps maximum-length identifiers above the footer and links each record both ways', async () => {
  const events = Array.from({ length: 5 }, (_, index) => ({
    id: `${index}`.padEnd(30, 'W'), actorId: 'W'.repeat(30), actorRole: 'IT_SECURITY',
    action: 'W'.repeat(100), entityType: 'W'.repeat(100), entityId: 'W'.repeat(100),
    createdAt: new Date('2026-11-02T10:00:00Z'),
  }));
  const rendered: { value: string; top: number; bottom: number }[] = [];
  const originalText = PDFDocument.prototype.text;
  const textSpy = vi.spyOn(PDFDocument.prototype, 'text').mockImplementation(function (
    this: PDFKit.PDFDocument, ...args: unknown[]
  ) {
    const top = typeof args[2] === 'number' ? args[2] : this.y;
    const result = Reflect.apply(originalText, this, args);
    rendered.push({ value: String(args[0]), top, bottom: this.y });
    return result;
  });
  const destinationSpy = vi.spyOn(PDFDocument.prototype, 'addNamedDestination');
  const linkSpy = vi.spyOn(PDFDocument.prototype, 'goTo');
  try {
    await auditReportPdf(events, '2026-11-02T11:00:00Z');
    for (const event of events) {
      for (const value of [event.id, event.actorId, event.action, event.entityType, event.entityId]) {
        expect(rendered.some(item => item.value === value)).toBe(true);
      }
    }
    for (const item of rendered.filter(item => item.top < 783)) {
      expect(item.bottom, `Text crosses footer: ${item.value}`).toBeLessThanOrEqual(758);
    }
    const destinations = destinationSpy.mock.calls.map(call => call[0]);
    const targets = linkSpy.mock.calls.map(call => call[4]);
    for (let number = 1; number <= events.length; number++) {
      for (const name of [`reference-${number}`, `summary-${number}`]) {
        expect(destinations.filter(value => value === name)).toHaveLength(1);
        expect(targets.filter(value => value === name)).toHaveLength(1);
      }
    }
  } finally {
    textSpy.mockRestore();
    destinationSpy.mockRestore();
    linkSpy.mockRestore();
  }
});
