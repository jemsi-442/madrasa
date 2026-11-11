import { PrismaClient } from '@prisma/client';
import { developmentEnvironment } from './development-config.mjs';
import { ensureTeacherCurriculumDemo } from './teacher-curriculum-demo.ts';

async function main() {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Confirmation required');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
  try { console.log(JSON.stringify(await ensureTeacherCurriculumDemo(db))); }
  finally { await db.$disconnect(); }
}
main().catch(() => {
  console.error('Curriculum demo preparation failed; all changes rolled back. Check local mode, demo staff, class ownership and existing curriculum mappings. No credentials printed.');
  process.exitCode = 1;
});
