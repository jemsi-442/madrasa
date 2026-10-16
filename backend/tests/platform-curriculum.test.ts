import { topicInput, publicationContent } from '../src/modules/platform/curriculum-content';
import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { curriculumInput, PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
const actor = { scope: 'platform' as const, accountId: 'reviewer', sessionId: 's' };
const topic = { title: 'Reading', position: 1, objectives: [{ code: 'READ-1', description: 'Read a passage fluently', assessmentMethod: 'ORAL', criteria: 'Read with accurate pronunciation' }] };
const input = { subject: 'Quran', version: '1.0', description: 'Recitation and revision', objectives: ['Recite clearly'] };
it('copies published content to an unassigned draft and records its source', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  await service.clone(actor, 'v1', { version: '1.1', reason: 'Clarify learning objectives' });
  expect(tx.curriculumVersion.create).toHaveBeenCalledWith({ data: { ...input, version: '1.1', level: 'Level 1', topics: { create: [{ ...topic, objectives: { create: topic.objectives.map(o => ({ ...o, id: expect.any(String) })) } }] }, createdBy: actor.accountId } });
  expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  expect(tx.curriculumAssignment.upsert).not.toHaveBeenCalled();
  expect(tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({
    action: 'curriculum.draft.cloned', metadata: { sourceVersionId: 'v1', reason: 'Clarify learning objectives' },
  }) });
});
it('rejects cloning drafts, unauthorized roles and reused version numbers', async () => {
  const data = { version: '1.1', reason: 'Clarify learning objectives' };
  await expect(fixture().service.clone(actor, 'v1', data)).rejects.toMatchObject({ statusCode: 409 });
  await expect(fixture('IT_SECURITY', 'PUBLISHED').service.clone(actor, 'v1', data)).rejects.toMatchObject({ statusCode: 403 });
  await expect(fixture('SUPER_ADMIN', 'PUBLISHED').service.clone(actor, 'v1', { ...data, version: '1.0' })).rejects.toMatchObject({ statusCode: 422 });
  await expect(fixture('SUPER_ADMIN', 'PUBLISHED').service.clone(actor, 'v1', { ...data, reason: '' })).rejects.toThrow();
});
it('loads the exact saved version independent of library pagination', async () => {
  const { service, tx } = fixture();
  await service.list(actor, { id: 'v1' });
  expect(tx.curriculumVersion.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'v1' }, skip: 0 }));
});
function fixture(role = 'SUPER_ADMIN', status = 'DRAFT', createdBy = 'author') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, role, status: 'ACTIVE' }) },
    curriculumVersion: {
      create: vi.fn().mockResolvedValue({ id: 'v1', ...input, status: 'DRAFT' }),
      findUnique: vi.fn().mockResolvedValue({ id: 'v1', ...input, level: 'Level 1', topics: [topic], lessons: [], status, createdBy, updatedAt: new Date('2026-01-01') }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findMany: vi.fn().mockResolvedValue([]), count: vi.fn().mockResolvedValue(0),
    },
    curriculumTopic: { create: vi.fn().mockResolvedValue({ id: 't1' }) },
    curriculumObjective: { count: vi.fn().mockResolvedValue(2) },
    curriculumLesson: { create: vi.fn(), findFirst: vi.fn().mockResolvedValue(null) },
    curriculumReview: { create: vi.fn() },
    curriculumAssignment: { upsert: vi.fn().mockResolvedValue({ id: 'a1', organizationId: 1n }) },
    organization: { findUnique: vi.fn().mockResolvedValue({ id: 1n, status: 'ACTIVE' }), count: vi.fn().mockResolvedValue(1) },
    platformAuditEvent: { create: vi.fn() },
  };
  return { tx, service: new PlatformCurriculumService({ $transaction: (fn: (tx: unknown) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
for (const role of ['IT_SECURITY', 'ADMIN', 'TEACHER', 'PARENT']) it(`denies curriculum access to ${role}`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.list(actor, {})).rejects.toMatchObject({ statusCode: 403 });
  await expect(service.save(actor, input)).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.curriculumVersion.findMany).not.toHaveBeenCalled();
  expect(tx.curriculumVersion.create).not.toHaveBeenCalled();
});
it('creates a validated draft with atomic audit', async () => {
  const { service, tx } = fixture();
  await service.save(actor, input);
  expect(tx.curriculumVersion.create).toHaveBeenCalledWith({ data: { ...input, level: '', createdBy: actor.accountId } });
  expect(tx.platformAuditEvent.create).toHaveBeenCalled();
  expect(() => curriculumInput.parse({ ...input, objectives: [] })).toThrow();
  expect(() => curriculumInput.parse({ ...input, status: 'PUBLISHED' })).toThrow();
});
for (const state of ['DRAFT', 'IN_REVIEW', 'APPROVED']) it(`publishes ${state} directly including own drafts`, async () => {
  const { service, tx } = fixture('SUPER_ADMIN', state, actor.accountId);
  await expect(service.transition(actor, 'v1', { action: 'publish' })).resolves.toEqual({ id: 'v1', status: 'PUBLISHED' });
  expect(tx.curriculumVersion.updateMany).toHaveBeenCalledWith({
    where: { id: 'v1', status: state, updatedAt: expect.any(Date) },
    data: { status: 'PUBLISHED', reviewedBy: null, publishedAt: expect.any(Date) },
  });
  expect(tx.curriculumReview.create).toHaveBeenCalledWith({ data: {
    versionId: 'v1', actorId: actor.accountId, action: 'publish',
    fromStatus: state, toStatus: 'PUBLISHED', comment: null,
  } });
});
it('rejects obsolete approval actions', async () => {
  const { service, tx } = fixture();
  for (const action of ['submit', 'approve', 'return']) {
    await expect(service.transition(actor, 'v1', { action })).rejects.toThrow();
  }
  expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
});
it('rejects invalid content and already published versions', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.findUnique.mockResolvedValue({ id: 'v1', ...input, objectives: [], status: 'DRAFT' });
  await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toThrow();
  expect(tx.curriculumReview.create).not.toHaveBeenCalled();
  await expect(fixture('SUPER_ADMIN', 'PUBLISHED').service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({ statusCode: 409 });
});
it('rejects a concurrent edit without recording publication', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.curriculumReview.create).not.toHaveBeenCalled();
  expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
});
for (const role of ['IT_SECURITY', 'ACCOUNTANT', 'TEACHER', 'ADMIN', 'PARENT']) it(`denies direct publication to ${role}`, async () => {
  const { service, tx } = fixture(role);
  await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({ statusCode: 403 });
  expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
});
it('allows superadmins to edit unpublished versions regardless of author', async () => {
  const { service, tx } = fixture();
  await service.edit(actor, 'v1', { description: input.description, objectives: input.objectives });
  expect(tx.curriculumVersion.updateMany).toHaveBeenCalledWith(expect.objectContaining({
    where: { id: 'v1', status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] } },
    data: { description: input.description, objectives: input.objectives, status: 'DRAFT', reviewedBy: null },
  }));
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.edit(actor, 'v1', { description: input.description, objectives: input.objectives })).rejects.toMatchObject({ statusCode: 409 });
});
it('assigns published versions idempotently without changing lessons', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  const result = await service.assign(actor, 'v1', { organizationId: '1' });
  expect(result.organizationId).toBe('1');
  expect(tx.curriculumAssignment.upsert).toHaveBeenCalledWith(expect.objectContaining({ update: {} }));
  await expect(fixture().service.assign(actor, 'v1', { organizationId: '1' })).rejects.toMatchObject({ statusCode: 409 });
  tx.organization.findUnique.mockResolvedValue({ id: 1n, status: 'SUSPENDED' });
  await expect(service.assign(actor, 'v1', { organizationId: '1' })).rejects.toMatchObject({ statusCode: 422 });
});

it('validates measurable topic objectives and publication readiness', () => {
  expect(topicInput.safeParse(topic).success).toBe(true);
  expect(topicInput.safeParse({ ...topic, objectives: [...topic.objectives, ...topic.objectives] }).success).toBe(false);
  expect(topicInput.safeParse({ ...topic, objectives: [{ ...topic.objectives[0], criteria: '' }] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: '', topics: [topic] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [] }).success).toBe(false);
});
it('adds a topic only to unpublished versions and audits it', async () => {
  const { service, tx } = fixture();
  await service.addTopic(actor, 'v1', topic);
  expect(tx.curriculumTopic.create).toHaveBeenCalled();
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  tx.curriculumTopic.create.mockClear();
  await expect(service.addTopic(actor, 'v1', topic)).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.curriculumTopic.create).not.toHaveBeenCalled();
  await expect(fixture('IT_SECURITY').service.addTopic(actor, 'v1', topic)).rejects.toMatchObject({ statusCode: 403 });
});

const lesson = { title: 'Practice reading', position: 1, durationMinutes: 40, activities: 'Read together then practise individually', objectiveIds: ['o1', 'o2'] };
it('links several objectives to a planned lesson without learner outcomes', async () => {
  const { service, tx } = fixture();
  await service.saveLesson(actor, 'v1', lesson);
  expect(tx.curriculumObjective.count).toHaveBeenCalledWith({ where: { id: { in: ['o1', 'o2'] }, topic: { versionId: 'v1' } } });
  expect(tx.curriculumLesson.create).toHaveBeenCalledWith({ data: {
    title: lesson.title, position: 1, durationMinutes: 40, activities: lesson.activities,
    versionId: 'v1', objectives: { create: [{ objectiveId: 'o1' }, { objectiveId: 'o2' }] },
  } });
});
it('rejects foreign objectives, foreign lessons, duplicate links and published edits', async () => {
  const { service, tx } = fixture();
  tx.curriculumObjective.count.mockResolvedValue(1);
  await expect(service.saveLesson(actor, 'v1', lesson)).rejects.toMatchObject({ statusCode: 422 });
  expect(tx.curriculumLesson.create).not.toHaveBeenCalled();
  tx.curriculumObjective.count.mockResolvedValue(2);
  await expect(service.saveLesson(actor, 'v1', lesson, 'foreign')).rejects.toMatchObject({ statusCode: 404 });
  await expect(service.saveLesson(actor, 'v1', { ...lesson, objectiveIds: ['o1', 'o1'] })).rejects.toThrow();
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.saveLesson(actor, 'v1', lesson)).rejects.toMatchObject({ statusCode: 409 });
  await expect(fixture('IT_SECURITY').service.saveLesson(actor, 'v1', lesson)).rejects.toMatchObject({ statusCode: 403 });
});
