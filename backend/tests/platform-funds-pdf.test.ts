import { expect, it } from 'vitest';
import { fundsPdf } from '../src/modules/platform/platform.funds-pdf';
import { writeFileSync } from 'node:fs';

const snapshot = {
  month: '2026-10', currency: 'TZS', page: 1, pageSize: 10, total: 10,
  generatedAt: '2026-10-31T10:30:00.000Z',
  summary: { donors: 8, pledged: '2400000.00', received: '1920000.00', outstanding: '480000.00' },
  items: Array.from({ length: 10 }, (_, i) => ({ id: String(i + 1), donorReference: `DON-${i + 1}`,
    fund: 'Synthetic education support fund', madrasa: 'Synthetic madrasa with a longer display name',
    pledged: '100000.00', received: i % 2 ? '0.00' : '100000.00', status: i % 2 ? 'Pending' : 'Received' })),
};
it('creates a branded multi-page PDF from a synthetic snapshot', async () => {
  const pdf = await fundsPdf(snapshot);
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1')).toContain('/Count 2');
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-financial-summary-preview.pdf', pdf);
});
it('renders an empty month without creating empty extra pages', async () => {
  const pdf = await fundsPdf({ ...snapshot, total: 0, items: [] });
  expect(pdf.toString('latin1')).toContain('/Count 1');
});
