import { topicInput, publicationContent } from '../src/modules/platform/curriculum-content';
import { expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
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
  const query = tx.curriculumVersion.findMany.mock.calls[0]?.[0];
  expect(query?.include.assignments.select._count).toEqual({
    select: { adoptions: true },
  });
  expect(query?.include.assignments.select.subjectId).toBe(true);
  expect(query?.include.assignments.select.subject).toEqual({
    select: { name: true, isActive: true },
  });
});
it('resolves curriculum history actor IDs to names without exposing email addresses', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.findMany.mockResolvedValue([{
    id: 'v1',
    createdBy: 'author',
    reviews: [{ actorId: 'publisher', action: 'publish' }],
  }]);
  tx.platformAccount.findMany.mockResolvedValue([
    { id: 'author', fullName: 'Curriculum Author' },
    { id: 'publisher', fullName: 'Super Admin' },
  ]);

  const result = await service.list(actor, { id: 'v1' });

  expect(tx.platformAccount.findMany).toHaveBeenCalledWith({
    where: { id: { in: ['author', 'publisher'] } },
    select: { id: true, fullName: true },
  });
  expect(result.items[0]).toMatchObject({
    createdByName: 'Curriculum Author',
    reviews: [{ actorName: 'Super Admin' }],
  });
  expect(result.items[0]).not.toHaveProperty('createdBy');
  expect(result.items[0]?.reviews?.[0]).not.toHaveProperty('actorId');
  expect(JSON.stringify(result)).not.toContain('@');
});
it('returns clone lineage from the audit record for the version detail', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.findMany.mockResolvedValue([{ id: 'v1' }]);
  tx.platformAuditEvent.findFirst.mockResolvedValue({
    metadata: { sourceVersionId: 'source-v1', reason: 'Update the teaching sequence' },
  });
  const result = await service.list(actor, { id: 'v1' });
  expect(tx.platformAuditEvent.findFirst).toHaveBeenCalledWith(expect.objectContaining({
    where: { entityType: 'CurriculumVersion', entityId: 'v1', action: 'curriculum.draft.cloned' },
  }));
  expect(result.cloneInfo).toEqual({
    sourceVersionId: 'source-v1',
    reason: 'Update the teaching sequence',
    sourceVersion: expect.objectContaining({ subject: 'Quran', version: '1.0' }),
  });
});
it('searches subject, level and description within the selected library scope', async () => {
  const { service, tx } = fixture();
  await service.list(actor, { q: 'Arabic', review: 'true' });
  expect(tx.curriculumVersion.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: {
      status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] },
      OR: [
        { subject: { contains: 'Arabic' } },
        { level: { contains: 'Arabic' } },
        { description: { contains: 'Arabic' } },
        { topics: { some: { title: { contains: 'Arabic' } } } },
        { topics: { some: { objectives: { some: { OR: [
          { code: { contains: 'Arabic' } },
          { description: { contains: 'Arabic' } },
          { criteria: { contains: 'Arabic' } },
        ] } } } } },
        { lessons: { some: { OR: [
          { title: { contains: 'Arabic' } },
          { activities: { contains: 'Arabic' } },
        ] } } },
      ],
    },
  }));
  expect(tx.organization.count).toHaveBeenCalledWith({ where: { status: 'ACTIVE' } });
});
it('keeps detail filters together and skips clone lineage when the detail is filtered out', async () => {
  const { service, tx } = fixture();
  await service.list(actor, { id: 'v1', review: 'true', q: 'Arabic' });
  expect(tx.curriculumVersion.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: {
      id: 'v1',
      status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] },
      OR: [
        { subject: { contains: 'Arabic' } },
        { level: { contains: 'Arabic' } },
        { description: { contains: 'Arabic' } },
        { topics: { some: { title: { contains: 'Arabic' } } } },
        { topics: { some: { objectives: { some: { OR: [
          { code: { contains: 'Arabic' } },
          { description: { contains: 'Arabic' } },
          { criteria: { contains: 'Arabic' } },
        ] } } } } },
        { lessons: { some: { OR: [
          { title: { contains: 'Arabic' } },
          { activities: { contains: 'Arabic' } },
        ] } } },
      ],
    },
  }));
  const filteredWhere = tx.curriculumVersion.findMany.mock.calls[0]?.[0]?.where;
  expect(tx.curriculumVersion.count).toHaveBeenCalledWith({ where: filteredWhere });
  expect(tx.platformAuditEvent.findFirst).not.toHaveBeenCalled();
});
it('uses the same filters for the total and applies the requested page offset', async () => {
  const { service, tx } = fixture();
  await service.list(actor, { page: '3', q: 'Arabic', review: 'true' });
  const expectedWhere = {
    status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] },
    OR: [
      { subject: { contains: 'Arabic' } },
      { level: { contains: 'Arabic' } },
      { description: { contains: 'Arabic' } },
      { topics: { some: { title: { contains: 'Arabic' } } } },
      { topics: { some: { objectives: { some: { OR: [
        { code: { contains: 'Arabic' } },
        { description: { contains: 'Arabic' } },
        { criteria: { contains: 'Arabic' } },
      ] } } } } },
      { lessons: { some: { OR: [
        { title: { contains: 'Arabic' } },
        { activities: { contains: 'Arabic' } },
      ] } } },
    ],
  };
  expect(tx.curriculumVersion.findMany).toHaveBeenCalledWith(expect.objectContaining({
    where: expectedWhere,
    take: 24,
    skip: 48,
  }));
  expect(tx.curriculumVersion.count).toHaveBeenCalledWith({ where: expectedWhere });
});
function fixture(role = 'SUPER_ADMIN', status = 'DRAFT', createdBy = 'author') {
  const tx = {
    platformAccount: {
      findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, role, status: 'ACTIVE' }),
      findMany: vi.fn().mockResolvedValue([]),
    },
    curriculumVersion: {
      create: vi.fn().mockResolvedValue({ id: 'v1', ...input, status: 'DRAFT' }),
      findUnique: vi.fn().mockResolvedValue({ id: 'v1', ...input, level: 'Level 1', topics: [topic], lessons: [], status, createdBy, updatedAt: new Date('2026-01-01') }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findMany: vi.fn().mockResolvedValue([]), count: vi.fn().mockResolvedValue(0),
    },
    curriculumTopic: { create: vi.fn().mockResolvedValue({ id: 't1' }), findFirst: vi.fn().mockResolvedValue(null), delete: vi.fn() },
    curriculumObjective: { count: vi.fn().mockResolvedValue(2), deleteMany: vi.fn() },
    curriculumLessonObjective: { count: vi.fn().mockResolvedValue(0), deleteMany: vi.fn() },
    curriculumLesson: { create: vi.fn(), findFirst: vi.fn().mockResolvedValue(null), update: vi.fn(), delete: vi.fn() },
    curriculumReview: { create: vi.fn() },
    curriculumAssignment: {
      upsert: vi.fn().mockImplementation(({ create }) => Promise.resolve({ id: 'a1', organizationId: create.organizationId })),
      findUnique: vi.fn().mockResolvedValue(null), findMany: vi.fn().mockResolvedValue([]),
    },
    class: { groupBy: vi.fn().mockResolvedValue([]) },
    organization: {
      findUnique: vi.fn().mockResolvedValue({ id: 1n, name: 'Afaq Madrasa', code: 'AFQ', status: 'ACTIVE',
        branches: [{ name: 'Main', location: 'Dar es Salaam' }],
        subjects: [{ id: 20n, code: 'AR', name: 'Quran' }], _count: { classes: 2 } }),
      findMany: vi.fn().mockImplementation(({ where }) => Promise.resolve(where.id.in.map((id: bigint) => ({ id })))),
      count: vi.fn().mockResolvedValue(1),
    },
    platformAuditEvent: { create: vi.fn(), findFirst: vi.fn().mockResolvedValue(null) },
  };
  return { tx, service: new PlatformCurriculumService({ $transaction: (fn: (tx: unknown) => unknown) => fn(tx) } as unknown as PrismaClient) };
}
it('previews a published framework against madrasa classes and active subjects without assigning it', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  tx.curriculumVersion.findUnique.mockResolvedValue({
    id: 'v1', subject: 'Quran', level: 'Level 1', version: '1.0', status: 'PUBLISHED',
  });
  tx.class.groupBy.mockResolvedValue([{ level: 'Level 1', academicYear: '2026', _count: { _all: 2 } }]);
  tx.curriculumAssignment.findUnique.mockResolvedValue({
    id: 'assignment-1', subjectId: 20n, _count: { adoptions: 1 },
  });
  const result = await service.assignmentPreview(actor, 'v1', '1');
  expect(result).toMatchObject({
    framework: { subject: 'Quran', level: 'Level 1', version: '1.0' },
    madrasa: {
      id: '1', name: 'Afaq Madrasa', status: 'ACTIVE', classCount: 2,
      classLevels: [{ level: 'Level 1', academicYear: '2026', classCount: 2 }],
      activeSubjects: [{ id: '20', name: 'Quran', nameMatchesFramework: true }],
    },
    existingAssignment: { id: 'assignment-1', subjectId: '20', classAdoptionCount: 1 },
  });
  expect(tx.class.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: { orgId: 1n } }));
  expect(tx.curriculumAssignment.upsert).not.toHaveBeenCalled();
});
it('limits assignment previews to published frameworks and active madrasas', async () => {
  const unpublished = fixture('SUPER_ADMIN', 'DRAFT');
  await expect(unpublished.service.assignmentPreview(actor, 'v1', '1'))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(unpublished.tx.organization.findUnique).not.toHaveBeenCalled();
  const trial = fixture('SUPER_ADMIN', 'PUBLISHED');
  trial.tx.curriculumVersion.findUnique.mockResolvedValue({
    id: 'v1', subject: 'Quran', level: 'Level 1', version: '1.0', status: 'PUBLISHED',
  });
  trial.tx.organization.findUnique.mockResolvedValue({ id: 1n, status: 'TRIAL' });
  await expect(trial.service.assignmentPreview(actor, 'v1', '1'))
    .rejects.toMatchObject({ statusCode: 422 });
  expect(trial.tx.class.groupBy).not.toHaveBeenCalled();
});
it('denies curriculum assignment previews to IT and non-platform roles', async () => {
  for (const role of ['IT_SECURITY', 'ADMIN', 'TEACHER', 'PARENT']) {
    const { service, tx } = fixture(role, 'PUBLISHED');
    await expect(service.assignmentPreview(actor, 'v1', '1')).rejects.toMatchObject({ statusCode: 403 });
    expect(tx.curriculumVersion.findUnique).not.toHaveBeenCalled();
  }
});
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
for (const state of ['DRAFT', 'IN_REVIEW', 'APPROVED']) it(`publishes ${state} directly without requiring lesson plans`, async () => {
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
it('does not publish legacy topics with invalid ordering, size or duplicate objective codes', async () => {
  for (const invalidTopic of [
    { ...topic, position: 0 },
    { ...topic, title: 'x'.repeat(151) },
    { ...topic, objectives: Array.from({ length: 51 }, (_, index) => ({
      ...topic.objectives[0], code: `READ-${index}`,
    })) },
    { ...topic, objectives: [topic.objectives[0], { ...topic.objectives[0], code: 'read-1' }] },
  ]) {
    const { service, tx } = fixture();
    tx.curriculumVersion.findUnique.mockResolvedValue({
      id: 'v1', ...input, level: 'Level 1', topics: [invalidTopic], status: 'DRAFT',
    });
    await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({
      statusCode: 422,
    });
    expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  }
});
it('does not publish duplicate lesson positions from stored draft content', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.findUnique.mockResolvedValue({
    id: 'v1', ...input, level: 'Level 1', topics: [topic],
    lessons: [
      { title: 'Lesson one', position: 2, durationMinutes: 20, activities: 'Read and discuss this passage.', objectives: [] },
      { title: 'Lesson two', position: 2, durationMinutes: 20, activities: 'Read and discuss this passage.', objectives: [] },
    ], status: 'DRAFT',
    updatedAt: new Date('2026-01-01'),
  });
  await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({
    statusCode: 422,
  });
  expect(tx.curriculumVersion.findUnique).toHaveBeenCalledWith({
    where: { id: 'v1' },
    include: {
      topics: { include: { objectives: true } },
      lessons: {
        select: {
          position: true,
          title: true,
          durationMinutes: true,
          activities: true,
          objectives: {
            select: {
              objective: {
                select: { topic: { select: { versionId: true } } },
              },
            },
          },
        },
      },
    },
  });
  expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  expect(tx.curriculumReview.create).not.toHaveBeenCalled();
  expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
});
it('does not publish lessons without objectives or linked to another framework', async () => {
  for (const objectives of [
    [],
    [{ objective: { topic: { versionId: 'different-version' } } }],
  ]) {
    const { service, tx } = fixture();
    tx.curriculumVersion.findUnique.mockResolvedValue({
      id: 'v1', ...input, level: 'Level 1', topics: [topic],
      lessons: [{ position: 1, objectives }], status: 'DRAFT',
      updatedAt: new Date('2026-01-01'),
    });

    await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({
      statusCode: 422,
    });
    expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
    expect(tx.curriculumReview.create).not.toHaveBeenCalled();
    expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
  }
});
it('does not publish malformed stored lesson details', async () => {
  for (const invalidLesson of [
    { title: 'x', position: 1, durationMinutes: 20, activities: 'Read and discuss this passage.', objectives: [{ objective: { topic: { versionId: 'v1' } } }] },
    { title: 'Lesson one', position: 1, durationMinutes: 0, activities: 'Read and discuss this passage.', objectives: [{ objective: { topic: { versionId: 'v1' } } }] },
    { title: 'Lesson one', position: 1, durationMinutes: 20, activities: 'short', objectives: [{ objective: { topic: { versionId: 'v1' } } }] },
  ]) {
    const { service, tx } = fixture();
    tx.curriculumVersion.findUnique.mockResolvedValue({
      id: 'v1', ...input, level: 'Level 1', topics: [topic],
      lessons: [invalidLesson], status: 'DRAFT',
      updatedAt: new Date('2026-01-01'),
    });

    await expect(service.transition(actor, 'v1', { action: 'publish' })).rejects.toMatchObject({
      statusCode: 422,
    });
    expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  }
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
    where: { id: 'v1', status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] }, updatedAt: new Date('2026-01-01') },
    data: { description: input.description, objectives: input.objectives,
      status: 'DRAFT', reviewedBy: null, updatedAt: expect.any(Date) },
  }));
  const nextUpdatedAt = tx.curriculumVersion.updateMany.mock.calls[0]?.[0]?.data.updatedAt as Date;
  expect(nextUpdatedAt.getTime()).toBeGreaterThan(new Date('2026-01-01').getTime());
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.edit(actor, 'v1', { description: input.description, objectives: input.objectives })).rejects.toMatchObject({ statusCode: 409 });
});
it('returns a conflict when changing level collides with an existing subject version', async () => {
  const { service, tx } = fixture();
  tx.curriculumVersion.updateMany.mockRejectedValueOnce(
    new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002', clientVersion: 'test',
    }),
  );
  await expect(service.edit(actor, 'v1', {
    level: 'Level 2', description: input.description, objectives: input.objectives,
  })).rejects.toMatchObject({
    statusCode: 409,
    message: 'This subject version already exists at the selected level',
  });
  expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
});
it('rejects a draft edit when the client loaded an older framework timestamp', async () => {
  const { service, tx } = fixture();
  await expect(service.edit(actor, 'v1', {
    description: input.description,
    objectives: input.objectives,
    expectedUpdatedAt: '2025-12-31T23:59:59.999Z',
  })).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
});
it('rejects stale timestamps for topic, lesson, delete and publish writes before changing content', async () => {
  const stale = '2025-12-31T23:59:59.999Z';

  const topicDraft = fixture();
  await expect(topicDraft.service.addTopic(actor, 'v1', { ...topic, expectedUpdatedAt: stale }))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(topicDraft.tx.curriculumTopic.create).not.toHaveBeenCalled();

  const lessonDraft = fixture();
  await expect(lessonDraft.service.saveLesson(actor, 'v1', { ...lesson, expectedUpdatedAt: stale }))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(lessonDraft.tx.curriculumLesson.create).not.toHaveBeenCalled();

  const topicDelete = fixture();
  await expect(topicDelete.service.deleteTopic(actor, 'v1', 't1', stale))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(topicDelete.tx.curriculumTopic.delete).not.toHaveBeenCalled();

  const lessonDelete = fixture();
  await expect(lessonDelete.service.deleteLesson(actor, 'v1', 'l1', stale))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(lessonDelete.tx.curriculumLesson.delete).not.toHaveBeenCalled();

  const publish = fixture();
  await expect(publish.service.transition(actor, 'v1', { action: 'publish', expectedUpdatedAt: stale }))
    .rejects.toMatchObject({ statusCode: 409 });
  expect(publish.tx.curriculumVersion.updateMany).not.toHaveBeenCalled();
  expect(publish.tx.curriculumReview.create).not.toHaveBeenCalled();
});
it('assigns published versions idempotently without changing lessons', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  const result = await service.assign(actor, 'v1', { organizationId: '1' });
  expect(result.assignments).toEqual([{ id: 'a1', organizationId: '1' }]);
  expect(tx.curriculumAssignment.upsert).toHaveBeenCalledWith(expect.objectContaining({ update: {} }));
  await expect(fixture().service.assign(actor, 'v1', { organizationId: '1' })).rejects.toMatchObject({ statusCode: 409 });
  tx.organization.findMany.mockResolvedValue([]);
  await expect(service.assign(actor, 'v1', { organizationId: '1' })).rejects.toMatchObject({ statusCode: 422 });
});

it('does not record a new assignment audit event when retrying an existing assignment', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  tx.curriculumAssignment.findMany.mockResolvedValue([{ organizationId: 1n }]);

  const result = await service.assign(actor, 'v1', { organizationId: '1' });

  expect(result.assignments).toEqual([{ id: 'a1', organizationId: '1' }]);
  expect(tx.curriculumAssignment.upsert).toHaveBeenCalledWith(expect.objectContaining({ update: {} }));
  expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
});

it('assigns a published version to several active madrasas atomically', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  const result = await service.assign(actor, 'v1', { organizationIds: ['1', '2', '3'] });
  expect(tx.organization.findMany).toHaveBeenCalledWith({
    where: { id: { in: [1n, 2n, 3n] }, status: 'ACTIVE' },
    select: { id: true },
  });
  expect(tx.curriculumAssignment.upsert).toHaveBeenCalledTimes(3);
  expect(result.assignments).toHaveLength(3);
  expect(tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({
    action: 'curriculum.assigned',
    metadata: { organizationIds: ['1', '2', '3'] },
  }) });
  tx.organization.findMany.mockResolvedValue([{ id: 1n }]);
  tx.curriculumAssignment.upsert.mockClear();
  await expect(service.assign(actor, 'v1', { organizationIds: ['1', '2'] })).rejects.toMatchObject({ statusCode: 422 });
  expect(tx.curriculumAssignment.upsert).not.toHaveBeenCalled();
});

it('rejects oversized or duplicate assignment batches before database writes', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  await expect(service.assign(actor, 'v1', {
    organizationIds: Array.from({ length: 101 }, (_, index) => `${index + 1}`),
  })).rejects.toThrow();
  await expect(service.assign(actor, 'v1', {
    organizationIds: ['1', '1'],
  })).rejects.toThrow();
  expect(tx.platformAccount.findUnique).not.toHaveBeenCalled();
  expect(tx.curriculumAssignment.upsert).not.toHaveBeenCalled();
});

it('rejects madrasa identifiers outside the database BIGINT range', async () => {
  const { service, tx } = fixture('SUPER_ADMIN', 'PUBLISHED');
  await expect(service.assign(actor, 'v1', {
    organizationId: '9223372036854775808',
  })).rejects.toThrow();
  expect(tx.platformAccount.findUnique).not.toHaveBeenCalled();
  expect(tx.curriculumAssignment.upsert).not.toHaveBeenCalled();
});

it('validates measurable topic objectives and publication readiness', () => {
  expect(topicInput.safeParse(topic).success).toBe(true);
  expect(topicInput.safeParse({ ...topic, objectives: [...topic.objectives, ...topic.objectives] }).success).toBe(false);
  expect(topicInput.safeParse({ ...topic, objectives: [{ ...topic.objectives[0], criteria: '' }] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: '', topics: [topic] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [topic, { ...topic, title: 'Duplicate position' }] }).success).toBe(false);
  const lesson = { title: 'Practice reading', position: 1, durationMinutes: 40,
    activities: 'Read together then practise individually' };
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [topic], lessons: [lesson, { ...lesson, title: 'Second practice' }] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [{
    ...topic, title: 'x'.repeat(151),
  }] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [{
    ...topic, objectives: Array.from({ length: 51 }, (_, index) => ({
      ...topic.objectives[0], code: `READ-${index}`,
    })),
  }] }).success).toBe(false);
  expect(publicationContent.safeParse({ level: 'Level 1', topics: [{
    ...topic, objectives: [topic.objectives[0], { ...topic.objectives[0], code: 'read-1' }],
  }] }).success).toBe(false);
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
it('prevents duplicate positions when drafting topics and lesson plans', async () => {
  const topicDraft = fixture();
  topicDraft.tx.curriculumTopic.findFirst.mockResolvedValue({ id: 'existing-topic' });
  await expect(topicDraft.service.addTopic(actor, 'v1', topic)).rejects.toMatchObject({ statusCode: 409 });
  expect(topicDraft.tx.curriculumTopic.create).not.toHaveBeenCalled();

  const lessonDraft = fixture();
  lessonDraft.tx.curriculumLesson.findFirst.mockResolvedValue({ id: 'existing-lesson' });
  await expect(lessonDraft.service.saveLesson(actor, 'v1', lesson)).rejects.toMatchObject({ statusCode: 409 });
  expect(lessonDraft.tx.curriculumLesson.create).not.toHaveBeenCalled();
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
it('deletes only draft lesson plans and their objective links with an audit event', async () => {
  const { service, tx } = fixture();
  tx.curriculumLesson.findFirst.mockResolvedValue({ id: 'l1' });
  await service.deleteLesson(actor, 'v1', 'l1');
  expect(tx.curriculumLessonObjective.deleteMany).toHaveBeenCalledWith({ where: { lessonId: 'l1' } });
  expect(tx.curriculumLesson.delete).toHaveBeenCalledWith({ where: { id: 'l1' } });
  expect(tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({
    action: 'curriculum.lesson.deleted', entityId: 'v1', metadata: { lessonId: 'l1' },
  }) });
  tx.curriculumVersion.updateMany.mockResolvedValue({ count: 0 });
  await expect(service.deleteLesson(actor, 'v1', 'l1')).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.curriculumLesson.delete).toHaveBeenCalledTimes(1);
});
it('deletes a draft topic only after linked lesson objectives have been removed', async () => {
  const { service, tx } = fixture();
  tx.curriculumTopic.findFirst.mockResolvedValue({ id: 't1' });
  tx.curriculumLessonObjective.count.mockResolvedValue(1);
  await expect(service.deleteTopic(actor, 'v1', 't1')).rejects.toMatchObject({ statusCode: 409 });
  expect(tx.curriculumTopic.delete).not.toHaveBeenCalled();
  tx.curriculumLessonObjective.count.mockResolvedValue(0);
  await service.deleteTopic(actor, 'v1', 't1');
  expect(tx.curriculumObjective.deleteMany).toHaveBeenCalledWith({ where: { topicId: 't1' } });
  expect(tx.curriculumTopic.delete).toHaveBeenCalledWith({ where: { id: 't1' } });
  expect(tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({
    action: 'curriculum.topic.deleted', entityId: 'v1', metadata: { topicId: 't1' },
  }) });
  await expect(fixture('IT_SECURITY').service.deleteTopic(actor, 'v1', 't1')).rejects.toMatchObject({ statusCode: 403 });
});
