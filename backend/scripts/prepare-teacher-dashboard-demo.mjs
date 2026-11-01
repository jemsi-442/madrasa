import { PrismaClient } from '@prisma/client';
import { developmentEnvironment } from './development-config.mjs';
import { ensureTeacherDashboardDemo } from './teacher-dashboard-demo.mjs';

async function main() {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Confirmation required');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
  try { console.log(JSON.stringify(await ensureTeacherDashboardDemo(db))); }
  finally { await db.$disconnect(); }
}
main().catch(() => {
  console.error('Demo preparation failed; verify local configuration, existing demo accounts and unchanged demo scopes. No existing records were overwritten.');
  process.exitCode = 1;
});
