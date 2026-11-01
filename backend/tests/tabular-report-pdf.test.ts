import { expect, it } from 'vitest';
import { writeFileSync } from 'node:fs';
import { reportCsvRows, tabularReportPdf } from '../src/shared/utils/tabular-report-pdf';

it('preserves quoted commas, escaped quotes and multiline CSV fields', () => {
  expect(reportCsvRows('Name,Note\r\n"Synthetic, name","Line 1\nLine ""2"""\r\n')).toEqual([
    ['Name', 'Note'], ['Synthetic, name', 'Line 1\nLine "2"'],
  ]);
});
it('renders a branded table and splits long content across pages without dropping it', async () => {
  const pdf = await tabularReportPdf('Synthetic report', 'Synthetic data only', ['Name', 'Description'],
    [['Synthetic entry', 'Long synthetic note '.repeat(650) + 'END OF CONTENT']]);
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1')).toContain('/Subtype /Image');
  expect(pdf.toString('latin1')).not.toContain('/Count 1\n');
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-tabular-preview.pdf', pdf);
});
it('lays out report metadata, wide madrasa codes and separate reading notes', async () => {
  const pdf = await tabularReportPdf('Institutional report', 'DRAFT / Monthly summary',
    ['Madrasa', 'Data availability', 'Attendance records', 'Lessons taught', 'Quran observations', 'Confirmed receipts', 'Open support notes'],
    Array.from({ length: 6 }, (_, i) => [`Synthetic Madrasa ${i + 1}\ndemo-location-synthetic-${i + 1}`, 'Records available', '18', '0', '19', 'No receipts', '5']),
    { columnWeights: [28, 15, 12, 10, 12, 15, 12],
      metadata: [{ label: 'Reporting period', value: 'October 2026' }, { label: 'Madrasa scope', value: 'All registered madrasas' }, { label: 'Snapshot created', value: '31 Oct 2026, 02:22 UTC' }],
      notes: ['Data availability shows source records, not formal submission. No records does not mean no activity.', 'Counts represent records, not unique learners or learning attainment.', 'Support notes are those open at the end of the reporting month.'],
    });
  expect(pdf.toString('latin1')).toContain('/Count 1\n');
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-structured-report-preview.pdf', pdf);
});
