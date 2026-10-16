import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';

import { curriculumDemoData } from './curriculum-demo-data';

// Persistent synthetic examples, allowed only in the disposable local demo.
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
    for (const example of curriculumDemoData) {
      const result = await db.$transaction(async tx => {
        const where = { subject: example.subject, level: example.level, version: '1.0' };
        const existing = await tx.curriculumVersion.findFirst({ where });
        if (existing) return { id: existing.id, created: false };
        const user = await tx.platformAccount.findFirstOrThrow({ where: { role: 'SUPER_ADMIN', status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
        const actor = { scope: 'platform' as const, accountId: user.id, sessionId: 'local-demo-examples' };
        const service = new PlatformCurriculumService({ $transaction: (fn: (client: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
        const draft = await service.save(actor, {
          ...where, description: 'DEMO ONLY: draft planning example for education-team checking, not approved teaching content.',
          objectives: example.topics.flatMap(topic => [...topic.skills]),
        });
        for (const [index, topic] of example.topics.entries()) {
          const result = await service.addTopic(actor, draft.id, {
            title: topic.title, position: index + 1,
            objectives: topic.skills.map((description, i) => ({
              code: `${example.prefix}-${index + 1}${i + 1}`, description,
              assessmentMethod: topic.method, criteria: topic.criteria[i],
            })),
          });
          assert(result.topic);
          await service.saveLesson(actor, draft.id, {
            title: `${topic.title} - guided practice (demo)`, position: index + 1,
            durationMinutes: index === 0 ? 35 : 40,
            activities: `DEMO DRAFT: introduce ${topic.title.toLowerCase()}, model the skill with teacher-prepared materials, guide paired practice and give individual feedback. Use only education-team-checked sources. ${example.prefix === 'QR1' ? 'No Quran text or verse mappings are provided. Actual passage events belong in Quran Tracking, with recitation, hifz and revision kept separate.' : 'Materials must be supplied before teaching.'} This plan does not mark attendance, teaching completion or learner achievement.`,
            objectiveIds: result.topic.objectives.map(objective => objective.id),
          });
        }
        const saved = await tx.curriculumVersion.findUniqueOrThrow({ where: { id: draft.id }, include: {
          topics: { include: { objectives: true } }, lessons: { include: { objectives: true } }, assignments: true,
        } });
        assert.equal(saved.status, 'DRAFT');
        assert.equal(saved.topics.length, 2);
        assert.equal(saved.topics.reduce((n, t) => n + t.objectives.length, 0), 4);
        assert.equal(saved.lessons.length, 2);
        const ids = new Set(saved.topics.flatMap(topic => topic.objectives.map(o => o.id)));
        assert(saved.lessons.every(l => l.objectives.length === 2 && l.objectives.every(o => ids.has(o.objectiveId))));
        assert.equal(saved.assignments.length, 0);
        return { id: draft.id, created: true };
      }, { timeout: 20000 });
      console.log(JSON.stringify({ ...result, subject: example.subject, level: example.level,
        message: result.created ? 'Verified: 2 topics, 4 objectives, 2 lessons. Draft and unassigned.' : 'Existing example preserved without changes.' }));
    }
  } finally { await db.$disconnect(); }
}
main().catch(() => { console.error('Demo preparation failed; no credentials printed. Previously completed examples are retained; rerun safely.'); process.exitCode = 1; });
