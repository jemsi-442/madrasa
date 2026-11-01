import { expect, it } from 'vitest';
import { tenantApplicationSchema, madrasaLocationSchema } from '../src/modules/platform/platform.schemas';
it('validates structured locations without forcing lower divisions', () => {
  expect(madrasaLocationSchema.parse({ country: ' Kenya ', region: 'Synthetic County', district: 'Synthetic District', ward: 'Synthetic Ward' }).country).toBe('Kenya');
  expect(madrasaLocationSchema.parse({ country: 'Tanzania', region: 'Synthetic Region', district: 'Synthetic District', ward: 'Synthetic Ward', village: 'Synthetic Village', street: 'Synthetic Street', hamlet: 'Synthetic Hamlet' }).hamlet).toBe('Synthetic Hamlet');
});
it('rejects incomplete, oversized and unknown location values', () => {
  for (const location of [{ country: 'Tanzania' }, { country: '', region: 'Region' }, { country: 'Kenya', region: 'County', ward: 'x'.repeat(101) }, { country: 'Kenya', region: 'County', latitude: 1 }]) {
    expect(() => madrasaLocationSchema.parse(location)).toThrow();
  }
});
it('requires location on new applications without a missing-location bypass', () => {
  expect(() => tenantApplicationSchema.parse({ schoolName: 'Synthetic School', requestedCode: 'synthetic-school', adminEmail: 'admin@example.test' })).toThrow();
});
it('requires nonblank district and ward while accepting manual names', () => {
  const valid = { country: 'Tanzania', region: 'Synthetic Region', district: 'Synthetic District', ward: 'Synthetic Ward' };
  for (const field of ['district', 'ward']) {
    for (const value of [undefined, '', '   ']) {
      expect(() => madrasaLocationSchema.parse({ ...valid, [field]: value })).toThrow();
    }
  }
  expect(madrasaLocationSchema.parse(valid)).toEqual(valid);
});
