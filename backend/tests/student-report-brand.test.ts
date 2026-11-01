import { expect, it } from 'vitest';
import { writeFileSync } from 'node:fs';
import { reportPdf } from '../src/modules/student-reports/report-pdf';

it('keeps the Afaq logo on a multi-page student report with long feedback', async () => {
  const pdf = await reportPdf({ school: 'Synthetic school', period: { name: 'Synthetic term', startsOn: '2026-01-01', endsOn: '2026-04-01' },
    student: { id: '1', fullName: 'Synthetic learner', admissionNo: 'TEST-1' }, className: 'Synthetic class', teacher: 'Synthetic teacher',
    feedback: 'Synthetic feedback. '.repeat(500), policy: 'Synthetic report policy.', assessments: [],
    attendance: { present: 0, late: 0, absent: 0, excused: 0, recorded: 0, rate: null },
    quran: { sessions: 0, memorisedAyahs: 0, reading: 0, revision: 0, tajweed: 0 },
  }, 'SYNTHETIC-REF');
  expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdf.toString('latin1')).toContain('/Subtype /Image');
  if (process.env.AFAQ_PDF_PREVIEW === 'true') writeFileSync('/tmp/afaq-student-preview.pdf', pdf);
});
