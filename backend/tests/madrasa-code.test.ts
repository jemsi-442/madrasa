import { expect, it, vi } from 'vitest';
import type { Prisma } from '@prisma/client';
import { allocateMadrasaCode } from '../src/modules/platform/madrasa-code';
import { tenantApplicationSchema } from '../src/modules/platform/platform.schemas';

it('allocates padded codes and skips pre-existing school and application codes', async () => {
  let id = 0n;
  const tx = {
    madrasaCodeSequence: { create: vi.fn(async () => ({ id: ++id })) },
    organization: { findUnique: vi.fn(async () => id === 1n ? { id: 1n } : null) },
    tenantApplication: { findUnique: vi.fn(async () => id === 2n ? { id: 'existing' } : null) },
  };
  expect(await allocateMadrasaCode(tx as unknown as Prisma.TransactionClient)).toBe('AFQ-000003');
  expect(await allocateMadrasaCode(tx as unknown as Prisma.TransactionClient)).toBe('AFQ-000004');
});
it('accepts automatic codes and separate government references but rejects impersonated generated codes', () => {
  const data = { schoolName: 'Synthetic Madrasa', adminEmail: 'admin@example.test',
    location: { country: 'Tanzania', region: 'Synthetic', district: 'Synthetic', ward: 'Synthetic' },
    governmentRegistrationNumber: ' GOV/123 ' };
  expect(tenantApplicationSchema.parse(data).governmentRegistrationNumber).toBe('GOV/123');
  expect(tenantApplicationSchema.parse(data).requestedCode).toBeUndefined();
  expect(() => tenantApplicationSchema.parse({ ...data, requestedCode: 'AFQ-000001' })).toThrow();
});
