import { PrismaClient } from '@prisma/client';
import { fileURLToPath } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';
import { ensureTeacherCourseDemo } from './teacher-course-demo.mjs';

if (process.argv[2] !== '--confirm-local-development') throw new Error('Explicit local development confirmation required.');
const env = await developmentEnvironment(fileURLToPath(new URL('../.env', import.meta.url)));
const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
try {
  console.log(JSON.stringify(await ensureTeacherCourseDemo(db)));
} catch {
  console.error('Demo preparation failed. No existing course was overwritten. Check local demo account and subject setup.');
  process.exitCode = 1;
} finally {
  await db.$disconnect();
}
