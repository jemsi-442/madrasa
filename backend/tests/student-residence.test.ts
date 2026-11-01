import { expect, it } from 'vitest';
import { studentResidenceSchema } from '../src/modules/students/student-residence';

it('validates living arrangements without inferring a guardian or accepting mixed addresses', () => {
  const base = { revision: '2030-01-01T00:00:00.000Z', reason: 'Synthetic correction' };
  for (const residence of [ { mode: 'UNKNOWN' }, { mode: 'GUARDIAN', guardianId: '1' },
    { mode: 'SEPARATE', location: { country: 'Tanzania' } } ]) {
    expect(studentResidenceSchema.safeParse({ ...base, residence }).success).toBe(true);
  }
  for (const residence of [ {}, { mode: 'GUARDIAN' }, { mode: 'SEPARATE', location: {} },
    { mode: 'UNKNOWN', location: { country: 'Tanzania' } },
    { mode: 'GUARDIAN', guardianId: '1', location: { country: 'Tanzania' } } ]) {
    expect(studentResidenceSchema.safeParse({ ...base, residence }).success).toBe(false);
  }
});
