import { describe, expect, it } from 'vitest';
import { residenceLocationSchema } from '../src/shared/validation/location';
import { madrasaLocationSchema } from '../src/modules/platform/platform.schemas';
import { createStudentSchema } from '../src/modules/students/students.schemas';
import { locationSuggestions } from '../src/modules/platform/location-suggestions';

describe('shared residence locations', () => {
  it('allows partial residence without weakening madrasa requirements', () => {
    expect(residenceLocationSchema.parse({ country: ' Tanzania ' })).toEqual({ country: 'Tanzania' });
    expect(madrasaLocationSchema.safeParse({ country: 'Tanzania' }).success).toBe(false);
    for (const input of [{}, { country: 'x' }, { street: 'x'.repeat(151) }, { privateField: 'bad' }]) {
      expect(residenceLocationSchema.safeParse(input).success).toBe(false);
    }
  });
  it('retains optional residence in nested guardian admission data', () => {
    const body = { admissionNo: 'SYN-1', fullName: 'Synthetic Learner', gender: 'female', branchId: '1',
      guardian: { fullName: 'Synthetic Guardian', phone: '255700000000' } };
    expect(createStudentSchema.parse(body).guardian?.residenceLocation).toBeUndefined();
    const result = createStudentSchema.parse({ ...body, guardian: { ...body.guardian,
      residenceLocation: { country: 'Tanzania', ward: 'Synthetic Ward' } } });
    expect(result.guardian?.residenceLocation?.ward).toBe('Synthetic Ward');
  });
  it('serves catalog suggestions without database or household lookups', async () => {
    expect((await locationSuggestions(null, { field: 'country', q: 'Tan' })).items).toContain('Tanzania');
    expect((await locationSuggestions(null, { field: 'ward', q: 'Syn' })).items).toEqual([]);
  });
});
