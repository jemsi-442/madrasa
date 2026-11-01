// Rebuild from Debian iso-codes (LGPL-2.1-or-later); no network at runtime.
import { readFile, writeFile, copyFile } from 'node:fs/promises';
const root = new URL('../src/modules/platform/', import.meta.url);
const countries = JSON.parse(await readFile('/usr/share/iso-codes/json/iso_3166-1.json', 'utf8'))['3166-1'];
const divisions = JSON.parse(await readFile('/usr/share/iso-codes/json/iso_3166-2.json', 'utf8'))['3166-2'];
const catalog = countries.map(row => ({
  name: row.alpha_2 === 'TZ' ? 'Tanzania' : row.common_name || row.name,
  regions: divisions.filter(region => region.code.startsWith(row.alpha_2 + '-') && !region.parent).map(region => region.name).sort(),
}));
await writeFile(new URL('location-catalog.json', root), JSON.stringify(catalog, null, 2) + '\n');
await copyFile('/usr/share/doc/iso-codes/copyright', new URL('location-catalog.COPYRIGHT', root));
await copyFile('/usr/share/common-licenses/LGPL-2.1', new URL('location-catalog.LICENSE', root));
