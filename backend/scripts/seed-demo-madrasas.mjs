import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { PrismaClient, Prisma } from '@prisma/client';
import { developmentEnvironment } from './development-config.mjs';

// Reuse sourced geography, not generated addresses or invented street/hamlet names.
export async function demoMadrasaLocations() {
  const catalog = JSON.parse(await readFile(new URL('../src/modules/platform/tanzania-villages.json', import.meta.url), 'utf8'));
  return catalog.entries.map(({ region, district, ward, village }) => ({
    code: `demo-location-${village.toLowerCase()}`,
    name: `Afaq ${village} (Demo)`,
    location: { country: 'Tanzania', region, district, ward, village },
  }));
}

export async function seedDemoMadrasas(db) {
  const rows = await demoMadrasaLocations();
  return db.$transaction(async tx => {
    let created = 0;
    for (const row of rows) {
      const existing = await tx.organization.findUnique({ where: { code: row.code }, select: { id: true } });
      if (existing) continue; // Never overwrite edited locations, status or linked records.
      await tx.organization.create({ data: { ...row, status: 'PENDING_ACTIVATION' } });
      created++;
    }
    const main = await tx.organization.updateMany({
      where: { code: 'demo-madrasa', location: { equals: Prisma.DbNull } },
      data: { location: rows.find(row => row.location.village === 'Tondoroni').location },
    });
    return { created, existingPreserved: rows.length - created, mainLocationFilled: main.count };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let db;
  try {
    if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Confirmation required');
    const env = await developmentEnvironment(new URL('../.env', import.meta.url));
    db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
    console.log(JSON.stringify(await seedDemoMadrasas(db)));
  } catch {
    console.error('Demo madrasa seed stopped. Check the shared local development configuration; no reset was attempted.');
    process.exitCode = 1;
  } finally { await db?.$disconnect(); }
}
