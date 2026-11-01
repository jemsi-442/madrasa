import data from './tanzania-locations.json';
import villages from './tanzania-villages.json';

// Suggestions, not boundary validation. Villages come from separately sourced
// records; never infer village/hamlet types from postal localities.
export function tanzaniaLocationOptions(query: {
  field: string; country?: string | undefined; region?: string | undefined;
  district?: string | undefined; ward?: string | undefined;
}): string[] {
  const slug = (value: string) => value.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  if (slug(query.country ?? '') !== 'tanzania') return [];
  if (query.field === 'village') {
    return villages.entries.filter(row =>
      slug(row.region) === slug(query.region ?? '') &&
      slug(row.district) === slug(query.district ?? '') &&
      slug(row.ward) === slug(query.ward ?? '')
    ).map(row => row.village);
  }
  const tables: Record<string, Record<string, string[]>> = {
    district: data.districts, ward: data.wards, street: data.streets,
  };
  const parents = query.field === 'district' ? [query.region]
    : query.field === 'ward' ? [query.region, query.district]
    : [query.region, query.district, query.ward];
  if (parents.some(value => !value?.trim())) return [];
  return tables[query.field]?.[parents.map(value => slug(value!)).join('/')] ?? [];
}
