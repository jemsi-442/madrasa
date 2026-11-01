import { Prisma } from '@prisma/client';
import { z } from 'zod';
import catalog from './location-catalog.json';
import { tanzaniaLocationOptions } from './tanzania-locations';

const fields = ['country', 'region', 'district', 'ward', 'village', 'street', 'hamlet'] as const;
export const locationSuggestionQuery = z.object({
  field: z.enum(fields), q: z.string().trim().min(1).max(150),
  country: z.string().trim().max(100).optional(), region: z.string().trim().max(100).optional(),
  district: z.string().trim().max(100).optional(), ward: z.string().trim().max(100).optional(),
  village: z.string().trim().max(100).optional(),
}).strict();

export async function locationSuggestions(tx: Prisma.TransactionClient | null, input: unknown) {
  const query = locationSuggestionQuery.parse(input);
  const normalized = (value: string) => value.trim().toLocaleLowerCase('en');
  const country = catalog.find(row => normalized(row.name) === normalized(query.country ?? ''));
  let suggestions = query.field === 'country' ? catalog.map(row => row.name)
    : query.field === 'region' ? [...(country?.regions ?? [])] : [...tanzaniaLocationOptions(query)];
  const parents = query.field === 'country' ? [] : query.field === 'region' ? ['country']
    : query.field === 'district' ? ['country', 'region']
    : query.field === 'ward' ? ['country', 'region', 'district']
    : ['country', 'region', 'district', 'ward'];
  if (parents.some(key => !query[key as keyof typeof query])) return { items: [] };
  const where = { AND: [
    ...parents.map(key => ({ location: { path: `$.${key}`, equals: query[key as keyof typeof query]! } })),
    { location: { path: `$.${query.field}`, string_starts_with: query.q } },
  ] };
  // Tenant forms use catalog-only suggestions, never another school's saved data.
  const organizations = tx ? await tx.organization.findMany({ where, select: { location: true }, take: 100 }) : [];
  const applications = tx ? await tx.tenantApplication.findMany({ where, select: { location: true }, take: 100 }) : [];
  for (const row of [...organizations, ...applications]) {
    const value = (row.location as Record<string, unknown> | null)?.[query.field];
    if (typeof value === 'string') suggestions.push(value);
  }
  return { items: [...new Map(suggestions.filter(value => normalized(value).startsWith(normalized(query.q)))
    .map(value => [normalized(value), value])).values()].sort().slice(0, 15) };
}
