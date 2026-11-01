export const directoryLocationFields = ['country', 'region', 'district', 'ward', 'village', 'street', 'hamlet'] as const;

export function directoryLocationValues(location: unknown): string[] {
  if (!location || typeof location !== 'object' || Array.isArray(location)) return [];
  const record = location as Record<string, unknown>;
  return directoryLocationFields.flatMap(key => typeof record[key] === 'string' && record[key].trim() ? [record[key].trim()] : []);
}

export function directoryLocationFilters(value: string, exact = false) {
  return directoryLocationFields.map(key => ({ location: {
    path: `$.${key}`,
    ...(exact ? { equals: value } : { string_contains: value }),
  } }));
}
