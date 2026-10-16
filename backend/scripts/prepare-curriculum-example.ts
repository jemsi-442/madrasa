import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';

// Persistent synthetic example, allowed only in the disposable local demo.
async function main() {
  const pid = process.argv[2];
  if (!/^\d+$/.test(pid ?? '')) throw Error('Provide the demo database PID');
  const args = readFileSync(`/proc/${pid}/cmdline`, 'utf8');
  if (!args.includes('mariadbd') || !args.includes('/tmp/afaq-local-demo-')) throw Error('Not a demo database');
  const env = Object.fromEntries(readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0').filter(Boolean).map(entry => {
    const i = entry.indexOf('='); return [entry.slice(0, i), entry.slice(i + 1)];
  }));
  const url = new URL(env.DATABASE_URL!);
  if (env.NODE_ENV !== 'development' || url.hostname !== '127.0.0.1' || url.pathname !== '/afaq_local_demo'
    || !url.port || url.port === '3306' || !args.includes(`--port=${url.port}`)) throw Error('Unsafe database');
  const db = new PrismaClient({ datasourceUrl: url.toString() });
  try {
    const result = await db.$transaction(async tx => {
      const where = { subject: 'Fiqh (Demo)', level: 'Level 1', version: '1.0' };
      const existing = await tx.curriculumVersion.findFirst({ where });
      if (existing) return { id: existing.id, created: false };
      const user = await tx.platformAccount.findFirstOrThrow({ where: { role: 'SUPER_ADMIN', status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
      const actor = { scope: 'platform' as const, accountId: user.id, sessionId: 'local-demo-example' };
      const service = new PlatformCurriculumService({ $transaction: (fn: (client: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
      const draft = await service.save(actor, {
        ...where, description: 'DEMO ONLY: draft for education-team content checking. Not an approved religious curriculum.',
        objectives: ['Explain the purpose of cleanliness', 'Practise a teacher-provided sequence', 'Reflect on safe and responsible use of water'],
      });
      const first = await service.addTopic(actor, draft.id, {
        title: 'Taharah - introductory practice (demo)', position: 1, objectives: [
          { code: 'FIQH-001', description: 'Explain why cleanliness matters using a classroom example', assessmentMethod: 'ORAL',
            criteria: 'Explain one relevant example using guidance checked by the education team' },
          { code: 'FIQH-002', description: 'Demonstrate the sequence provided by the teacher', assessmentMethod: 'PRACTICAL',
            criteria: 'Follow the education-team-checked demonstration checklist; the checklist content must be supplied before teaching' },
        ],
      });
      const second = await service.addTopic(actor, draft.id, {
        title: 'Responsible practice and reflection (demo)', position: 2, objectives: [
          { code: 'FIQH-003', description: 'Demonstrate responsible use of classroom practice materials', assessmentMethod: 'OBSERVATION',
            criteria: 'Use materials safely, avoid wasting water and explain one improvement with teacher support' },
        ],
      });
      assert(first.topic && second.topic);
      const ids = first.topic.objectives.map(o => o.id);
      await service.saveLesson(actor, draft.id, {
        title: 'Introduction and guided demonstration (demo)', position: 1, durationMinutes: 35,
        activities: 'Draft plan: 5 min discussion, 10 min teacher demonstration using an education-team-checked checklist, 15 min guided practice, 5 min reflection. No student achievement is recorded by saving this plan.',
        objectiveIds: ids,
      });
      await service.saveLesson(actor, draft.id, {
        title: 'Practice, observation and feedback (demo)', position: 2, durationMinutes: 30,
        activities: 'Draft plan: revisit the teacher-provided sequence, observe practice and discuss responsible use of materials. Record individual assessments separately when that workflow is available.',
        objectiveIds: [ids[1]!, second.topic.objectives[0]!.id],
      });
      const saved = await tx.curriculumVersion.findUniqueOrThrow({ where: { id: draft.id }, include: {
        topics: { include: { objectives: true } }, lessons: { include: { objectives: true } }, assignments: true,
      } });
      assert.equal(saved.status, 'DRAFT');
      assert.equal(saved.topics.length, 2);
      assert.equal(saved.topics.reduce((n, t) => n + t.objectives.length, 0), 3);
      assert.equal(saved.lessons.length, 2);
      assert(saved.lessons.every(l => l.objectives.length === 2));
      assert.equal(saved.assignments.length, 0);
      return { id: draft.id, created: true };
    }, { timeout: 20000 });
    console.log(JSON.stringify({ ...result, subject: 'Fiqh (Demo)', level: 'Level 1', message: result.created
      ? 'Saved and verified: 2 topics, 3 objectives, 2 lessons. Unpublished and unassigned.'
      : 'Existing example retained without overwriting any changes.' }));
  } finally { await db.$disconnect(); }
}
main().catch(() => { console.error('Example preparation failed; no credentials printed.'); process.exitCode = 1; });
