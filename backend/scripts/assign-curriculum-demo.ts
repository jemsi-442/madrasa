import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
import { curriculumDemoData } from './curriculum-demo-data';

async function main() {
  const pid = process.argv[2];
  if (!/^\d+$/.test(pid ?? '')) throw Error('Provide the demo database PID');
  const args = readFileSync(`/proc/${pid}/cmdline`, 'utf8');
  if (!args.includes('mariadbd') || !args.includes('/tmp/afaq-local-demo-')) throw Error('Not a demo database');
  const env = Object.fromEntries(readFileSync(`/proc/${pid}/environ`, 'utf8')
    .split('\0').filter(Boolean).map(entry => {
      const i = entry.indexOf('=');
      return [entry.slice(0, i), entry.slice(i + 1)];
    }));
  const url = new URL(env.DATABASE_URL!);
  if (env.NODE_ENV !== 'development' || url.hostname !== '127.0.0.1'
    || url.pathname !== '/afaq_local_demo' || !url.port || url.port === '3306'
    || !args.includes(`--port=${url.port}`)) throw Error('Unsafe database');
  const db = new PrismaClient({ datasourceUrl: url.toString(), log: [] });
  try {
    // Publish and assign atomically; never change school adoption or learner records.
    const result = await db.$transaction(async tx => {
      const schools = await tx.organization.findMany({
        where: { code: 'demo-madrasa', status: 'ACTIVE' },
        select: { id: true, name: true },
      });
      assert(schools.length > 0, 'Active demo madrasa required');
      const user = await tx.platformAccount.findFirstOrThrow({
        where: { role: 'SUPER_ADMIN', status: 'ACTIVE' },
        orderBy: { createdAt: 'asc' },
      });
      const actor = { scope: 'platform' as const, accountId: user.id, sessionId: 'local-demo-assignments' };
      const service = new PlatformCurriculumService({
        $transaction: (fn: (client: typeof tx) => unknown) => fn(tx),
      } as unknown as PrismaClient);
      const versions = [];
      for (const example of curriculumDemoData) {
        const version = await tx.curriculumVersion.findFirstOrThrow({
          where: { subject: example.subject, level: example.level, version: '1.0' },
        });
        assert(version.description?.includes('DEMO ONLY'), 'Only marked demo content may be assigned');
        if (version.status !== 'PUBLISHED') {
          await service.transition(actor, version.id, {
            action: 'publish', expectedUpdatedAt: version.updatedAt.toISOString(),
            comment: 'Synthetic demo publication for assignment testing; not approved teaching content.',
          });
        }
        await service.assign(actor, version.id, {
          organizationIds: schools.map(school => school.id.toString()),
        });
        const count = await tx.curriculumAssignment.count({
          where: { versionId: version.id, organizationId: { in: schools.map(school => school.id) } },
        });
        assert.equal(count, schools.length);
        versions.push({ subject: version.subject, level: version.level, assignments: count });
      }
      return { madrasas: schools.map(school => school.name), versions };
    }, { timeout: 30000 });
    console.log(JSON.stringify(result));
  } finally {
    await db.$disconnect();
  }
}
main().catch(() => {
  console.error('Demo assignment failed; transaction rolled back. No credentials printed.');
  process.exitCode = 1;
});
