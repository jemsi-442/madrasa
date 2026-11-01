import { z } from 'zod';

export const locationSchema = z.object({
  country: z.string().trim().min(2).max(100),
  region: z.string().trim().min(2).max(100),
  district: z.string().trim().min(2).max(100),
  ward: z.string().trim().min(2).max(100),
  village: z.string().trim().max(100).optional(),
  street: z.string().trim().max(150).optional(),
  hamlet: z.string().trim().max(100).optional(),
  address: z.string().trim().max(255).optional(),
}).strict();

// Household addresses are optional and may be partial; reject empty submissions.
export const residenceLocationSchema = locationSchema.partial().refine(
  value => Object.values(value).some(part => part?.trim()),
  'Enter at least one location field or omit the location',
);
