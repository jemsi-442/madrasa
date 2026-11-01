// Usage: node scripts/build-tanzania-locations.mjs /path/to/tz-locations-1.0.2.tgz
// Data only: no third-party package code or install scripts are executed.
import { execFileSync } from 'node:child_process';
import { writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const archive = process.argv[2];
if (!archive) throw new Error('Provide the tz-locations 1.0.2 npm archive.');
const read = name => JSON.parse(execFileSync('tar', ['-xOf', archive, `package/dist/data/${name}.json`], { maxBuffer: 30 * 1024 * 1024 }).toString());
const result = { districts: {}, wards: {}, streets: {} };
for (const [name, target, keys] of [
  ['districts', 'districts', ['region_slug']],
  ['wards', 'wards', ['region_slug', 'district_slug']],
  ['streets', 'streets', ['region_slug', 'district_slug', 'ward_slug']],
]) {
  for (const row of read(name)) {
    if (typeof row.name !== 'string' || keys.some(key => typeof row[key] !== 'string')) throw new Error('Invalid location row');
    const key = keys.map(key => row[key]).join('/');
    (result[target][key] ??= []).push(row.name);
  }
  for (const key of Object.keys(result[target])) result[target][key] = [...new Set(result[target][key])].sort();
}
const output = {
  source: 'https://github.com/mwemanoor/tz-locations',
  version: '1.0.2', license: 'MIT',
  archiveSha256: createHash('sha256').update(readFileSync(archive)).digest('hex'),
  ...result,
};
await writeFile(new URL('../src/modules/platform/tanzania-locations.json', import.meta.url), JSON.stringify(output) + '\n');
console.log('Generated district, ward and postal locality suggestion indexes.');
