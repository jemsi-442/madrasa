import { describe, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
import { locationSuggestions } from '../src/modules/platform/location-suggestions';
import villages from '../src/modules/platform/tanzania-villages.json';
import postalData from '../src/modules/platform/tanzania-locations.json';

function database(locations: object[] = []) {
  const findMany = vi.fn().mockResolvedValue(locations.map(location => ({ location })));
  return { tx: { organization: { findMany }, tenantApplication: { findMany } } as unknown as Prisma.TransactionClient, findMany };
}

describe('location suggestions', () => {
  it.each(villages.entries)('offers sourced village $village only in its parent area', async (row) => {
    const scope = { country: 'Tanzania', region: row.region, district: row.district, ward: row.ward, field: 'village', q: row.village.slice(0, 2) };
    expect((await locationSuggestions(database().tx, scope)).items).toContain(row.village);
    expect((await locationSuggestions(database().tx, { ...scope, ward: 'Synthetic Other Ward' })).items).not.toContain(row.village);
    expect((await locationSuggestions(database().tx, { ...scope, country: 'Kenya' })).items).not.toContain(row.village);
    expect((await locationSuggestions(database().tx, { ...scope, field: 'hamlet' })).items).not.toContain(row.village);
    const key = `${row.region}/${row.district}`.toLowerCase();
    expect((postalData.wards as Record<string, string[]>)[key]).toContain(row.ward);
    expect(new URL(row.source).hostname.endsWith('.go.tz')).toBe(true);
  });
  it('combines manually saved village names with reference suggestions', async () => {
    const result = await locationSuggestions(database([{ village: 'Kwala Test Village' }]).tx, {
      country: 'Tanzania', region: 'Pwani', district: 'Kisarawe', ward: 'Chole', field: 'village', q: 'Kw',
    });
    expect(result.items).toEqual(['Kwala', 'Kwala Test Village']);
  });
  it('offers Tanzania districts without any saved madrasas', async () => {
    const result = await locationSuggestions(database().tx, {
      field: 'district', q: 'Kin', country: 'Tanzania', region: 'Dar es Salaam',
    });
    expect(result.items).toContain('Kinondoni');
  });
  it('offers wards and streets within the complete selected hierarchy', async () => {
    const scope = { country: 'Tanzania', region: 'Dar es Salaam', district: 'Kinondoni' };
    expect((await locationSuggestions(database().tx, { ...scope, field: 'ward', q: 'Msa' })).items).toContain('Msasani');
    expect((await locationSuggestions(database().tx, { ...scope, ward: 'Msasani', field: 'street', q: 'Mas' })).items).toContain('Masaki');
    expect((await locationSuggestions(database().tx, { ...scope, district: 'Ilala', field: 'ward', q: 'Msa' })).items).not.toContain('Msasani');
  });
  it('does not offer Tanzanian locations for Kenya or invent village classifications', async () => {
    expect((await locationSuggestions(database().tx, { field: 'district', q: 'Kin', country: 'Kenya', region: 'Dar es Salaam' })).items).toEqual([]);
    expect((await locationSuggestions(database().tx, { field: 'village', q: 'Mas', country: 'Tanzania', region: 'Dar es Salaam', district: 'Kinondoni', ward: 'Msasani' })).items).toEqual([]);
  });
  it.each(['IT_SECURITY', 'ACCOUNTANT', 'TEACHER'])('denies saved-location access to %s', async (role) => {
    const { tx, findMany } = database();
    const scoped = { ...tx, platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'actor', role, status: 'ACTIVE' }) } };
    const service = new PlatformGovernanceService({ $transaction: async (run: (tx: unknown) => unknown) => run(scoped) } as unknown as PrismaClient);
    await expect(service.suggestLocations({ scope: 'platform', accountId: 'actor', sessionId: 'session' }, { field: 'country', q: 'Tan' })).rejects.toMatchObject({ statusCode: 403 });
    expect(findMany).not.toHaveBeenCalled();
  });
  it('offers Tanzania for a case-insensitive prefix', async () => {
    expect((await locationSuggestions(database().tx, { field: 'country', q: 'tan' })).items).toContain('Tanzania');
  });
  it('limits region suggestions to the selected country', async () => {
    expect((await locationSuggestions(database().tx, { field: 'region', q: 'Dar', country: 'Tanzania' })).items).toContain('Dar es Salaam');
    expect((await locationSuggestions(database().tx, { field: 'region', q: 'Dar', country: 'Kenya' })).items).not.toContain('Dar es Salaam');
  });
  it('requires parent areas and scopes saved local suggestions', async () => {
    const { tx, findMany } = database([{ district: 'Synthetic District' }]);
    expect(await locationSuggestions(tx, { field: 'district', q: 'Syn' })).toEqual({ items: [] });
    expect(findMany).not.toHaveBeenCalled();
    expect(await locationSuggestions(tx, { field: 'district', q: 'Syn', country: 'Tanzania', region: 'Arusha' })).toEqual({ items: ['Synthetic District'] });
    expect(findMany.mock.calls[0]?.[0].where.AND).toContainEqual({ location: { path: '$.region', equals: 'Arusha' } });
  });
  it('does not leak saved region suggestions into the catalog', async () => {
    await locationSuggestions(database([{ region: 'Synthetic Region' }]).tx, { field: 'region', q: 'Syn', country: 'Tanzania' });
    expect(await locationSuggestions(database().tx, { field: 'region', q: 'Syn', country: 'Tanzania' })).toEqual({ items: [] });
  });
  it('rejects unsupported fields', async () => {
    await expect(locationSuggestions(database().tx, { field: 'password', q: 'a' })).rejects.toThrow();
  });
});
