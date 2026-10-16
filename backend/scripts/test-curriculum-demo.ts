import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
import { SchoolCurriculumService } from '../src/modules/learning/school-curriculum';

// All test writes are rolled back. Accept only a surviving disposable demo DB.
async function main() {
  const pid = process.argv[2];
  if (!/^\d+$/.test(pid ?? '')) throw Error('Provide the local demo database PID');
  const args = readFileSync(`/proc/${pid}/cmdline`, 'utf8');
  if (!args.includes('mariadbd') || !args.includes('/tmp/afaq-local-demo-')) throw Error('Not a demo database');
  const env = Object.fromEntries(readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0').filter(Boolean).map(value => {
    const split = value.indexOf('='); return [value.slice(0, split), value.slice(split + 1)];
  }));
  const url = new URL(env.DATABASE_URL!);
  if (url.pathname !== '/afaq_local_demo' || url.hostname !== '127.0.0.1' || url.port === '3306') throw Error('Unsafe database');
  const db = new PrismaClient({ datasourceUrl: url.toString() });
  const rollback = new Error('Expected rollback');
  try {
    await db.$transaction(async tx => {
      const create = (name: string) => tx.platformAccount.create({ data: {
        fullName: name, email: `${name}-${Date.now()}@example.invalid`, passwordHash: 'unusable-test-hash', role: 'SUPER_ADMIN', status: 'ACTIVE',
      } });
      const author = await create('curriculum-author');
      const actor = { scope: 'platform' as const, accountId: author.id, sessionId: 'test' };
      const service = new PlatformCurriculumService({ $transaction: (fn: (client: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
      const data = { subject: `Smoke test ${Date.now()}`, level: 'Level 1', version: '1.0', description: 'Test framework', objectives: ['Read clearly'] };
      const draft = await service.save(actor, data);
      await service.edit(actor, draft.id, { description: 'Updated draft', objectives: ['Read with fluency'] });
      await assert.rejects(service.transition(actor, draft.id, { action: 'publish' }));
      await service.addTopic(actor, draft.id, { title: 'Reading practice', position: 1, objectives: [{
        code: 'READ-1', description: 'Read a short passage clearly', assessmentMethod: 'ORAL', criteria: 'Read the passage with accurate pronunciation',
      }] });
      const originalTopic = await tx.curriculumTopic.findFirstOrThrow({ where: { versionId: draft.id }, include: { objectives: true } });
      await service.addTopic(actor, draft.id, { title: 'Reading practice revised', position: 1, objectives: [{
        code: 'READ-1', description: 'Read a short passage clearly', assessmentMethod: 'ORAL', criteria: 'Read the passage with accurate pronunciation',
      }] }, originalTopic.id);
      assert.equal((await tx.curriculumObjective.findFirstOrThrow({ where: { topicId: originalTopic.id } })).id, originalTopic.objectives[0]?.id);
      const objectiveId = originalTopic.objectives[0]!.id;
      for (const position of [1, 2]) {
        await service.saveLesson(actor, draft.id, { title: `Reading lesson ${position}`, position,
          durationMinutes: 40, activities: 'Read aloud and practise with teacher guidance', objectiveIds: [objectiveId] });
      }
      assert.equal(await tx.curriculumLessonObjective.count({ where: { objectiveId } }), 2);
      await assert.rejects(service.transition(actor, draft.id, { action: 'submit' }));
      await service.transition(actor, draft.id, { action: 'publish' });
      await assert.rejects(service.edit(actor, draft.id, { description: 'Cannot edit', objectives: ['Changed objective'] }));
      const school = await tx.organization.findFirstOrThrow({ where: { status: 'ACTIVE' } });
      await service.assign(actor, draft.id, { organizationId: school.id.toString() });
      await service.assign(actor, draft.id, { organizationId: school.id.toString() });
      assert.equal(await tx.curriculumAssignment.count({ where: { versionId: draft.id } }), 1);
      const list = await service.list(actor, {});
      assert(list.items.some(row => row.id === draft.id && row.status === 'PUBLISHED'));
      assert.equal(await tx.platformAuditEvent.count({ where: { entityId: draft.id } }), 9);
      const history = await tx.curriculumReview.findMany({ where: { versionId: draft.id } });
      assert.equal(history.length, 1);
      assert.equal(history[0]?.action, 'publish');
      assert.equal(history[0]?.actorId, author.id);
      assert((await tx.curriculumVersion.findUniqueOrThrow({ where: { id: draft.id } })).publishedAt);
      const copy = await service.clone(actor, draft.id, { version: '1.1', reason: 'Clarify learning objectives' });
      assert.equal(copy.status, 'DRAFT');
      assert.deepEqual(copy.objectives, ['Read with fluency']);
      assert.equal(await tx.curriculumAssignment.count({ where: { versionId: copy.id } }), 0);
      const copiedTopics = await tx.curriculumTopic.findMany({ where: { versionId: copy.id }, include: { objectives: true } });
      assert.equal(copiedTopics.length, 1);
      assert.equal(copiedTopics[0]?.objectives[0]?.code, 'READ-1');
      const newObjectiveId = copiedTopics[0]!.objectives[0]!.id;
      assert.notEqual(newObjectiveId, objectiveId);
      const copiedLessons = await tx.curriculumLesson.findMany({ where: { versionId: copy.id }, include: { objectives: true } });
      assert.equal(copiedLessons.length, 2);
      assert(copiedLessons.every(lesson => lesson.objectives[0]?.objectiveId === newObjectiveId));
      assert.equal(await tx.curriculumAssignment.count({ where: { versionId: draft.id } }), 1);
      await assert.rejects(service.clone(actor, draft.id, { version: '1.1', reason: 'Duplicate version test' }));
      const branch = await tx.branch.findFirstOrThrow({ where: { orgId: school.id } });
      const schoolUser = (role: 'ADMIN' | 'TEACHER', suffix: string) => tx.user.create({ data: {
        orgId: school.id, branchId: branch.id, fullName: `Synthetic curriculum ${suffix}`,
        email: `curriculum-${suffix}-${Date.now()}@example.invalid`, passwordHash: 'unusable-test-hash', role, status: 'ACTIVE',
      } });
      const admin = await schoolUser('ADMIN', 'admin');
      const teacher = await schoolUser('TEACHER', 'teacher');
      const other = await schoolUser('TEACHER', 'other');
      const classroom = await tx.class.create({ data: { orgId: school.id, branchId: branch.id, teacherId: teacher.id,
        name: 'Synthetic curriculum class', level: 'Level 1', academicYear: '2026' } });
      const subject = await tx.subject.create({ data: { orgId: school.id, code: `TEST-${Date.now()}`, name: 'Synthetic reading' } });
      const schoolService = new SchoolCurriculumService({ $transaction: (fn: (client: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
      const context = (user: typeof admin) => ({ userId: user.id.toString(), orgId: school.id.toString(), branchId: branch.id.toString(), role: user.role });
      const assignment = await tx.curriculumAssignment.findFirstOrThrow({ where: { versionId: draft.id, organizationId: school.id } });
      assert.equal((await schoolService.list(context(teacher))).assignments.length, 0);
      const adoptionInput = { assignmentId: assignment.id, classId: classroom.id.toString(), subjectId: subject.id.toString() };
      const adoption = await schoolService.adopt(context(admin), adoptionInput);
      assert.equal((await schoolService.adopt(context(admin), adoptionInput)).id, adoption.id);
      const teaching = await schoolService.list(context(teacher));
      assert.equal(teaching.assignments.length, 1);
      assert.equal(teaching.assignments[0].version.lessons.length, 2);
      assert.equal(teaching.assignments[0].adoptions[0].class.id, classroom.id.toString());
      assert.equal((await schoolService.list(context(other))).assignments.length, 0);
      await assert.rejects(schoolService.adopt(context(teacher), adoptionInput));
      await service.transition(actor, copy.id, { action: 'publish' });
      await service.assign(actor, copy.id, { organizationId: school.id.toString() });
      const newer = await tx.curriculumAssignment.findFirstOrThrow({ where: { versionId: copy.id, organizationId: school.id } });
      await assert.rejects(schoolService.adopt(context(admin), { ...adoptionInput, assignmentId: newer.id }));
      assert.equal(await tx.auditLog.count({ where: { entityId: adoption.id, action: 'curriculum.class.adopted' } }), 1);
      throw rollback;
    }, { timeout: 20000 });
  } catch (error) { if (error !== rollback) throw error; }
  finally { await db.$disconnect(); }
  console.log('Curriculum database lifecycle passed; all test records rolled back.');
}
main().catch(() => { console.error('Curriculum database lifecycle failed. Test transaction rolled back.'); process.exitCode = 1; });
