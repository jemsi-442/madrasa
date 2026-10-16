import { randomBytes } from 'node:crypto';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import { assertPlatformPermission } from './platform.permissions';
import type { PlatformContext } from './platform.service';

import { topicInput, publicationContent, curriculumLessonInput } from './curriculum-content';

export const curriculumInput = z.object({
  level: z.string().trim().min(1).max(80).optional(),
  subject: z.string().trim().min(2).max(120),
  version: z.string().trim().regex(/^\d+\.\d+(?:\.\d+)?$/).max(30),
  description: z.string().trim().min(2).max(500),
  objectives: z.array(z.string().trim().min(2).max(1000)).min(1).max(50),
}).strict();
const idSchema = z.string().min(1).max(30);
export const curriculumDecisionInput = z.object({
  action: z.literal('publish'),
  comment: z.string().trim().max(2000).optional(),
}).strict();

export class PlatformCurriculumService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const user = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!user || user.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
    assertPlatformPermission(user.role, 'curriculum.manage');
    return user;
  }
  async list(actor: PlatformContext, input: unknown) {
    const query = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1), review: z.enum(['true']).optional(), id: idSchema.optional() }).strict().parse(input);
    const where: Prisma.CurriculumVersionWhereInput = query.review ? { status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] } } : {};
    if (query.id) where.id = query.id;
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const [items, total, madrasaCount] = await Promise.all([
        tx.curriculumVersion.findMany({ where, take: 24, skip: (query.page - 1) * 24,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], include: { lessons: { orderBy: [{ position: 'asc' }, { id: 'asc' }], include: { objectives: { include: { objective: true } } } }, topics: { orderBy: [{ position: 'asc' }, { id: 'asc' }], include: { objectives: { orderBy: { code: 'asc' } } } }, reviews: { orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 30 }, assignments: { select: { id: true, createdAt: true, organization: { select: { name: true, code: true } } } }, _count: { select: { assignments: true } } } }),
        tx.curriculumVersion.count({ where }), tx.organization.count(),
      ]);
      return { items, total, madrasaCount, page: query.page };
    });
  }
  async save(actor: PlatformContext, input: unknown) {
    const data = curriculumInput.parse(input);
    try {
      return await this.db.$transaction(async tx => {
        const user = await this.authorize(tx, actor);
        const row = await tx.curriculumVersion.create({ data: { ...data, level: data.level ?? '', createdBy: user.id } });
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.draft.created', entityType: 'CurriculumVersion', entityId: row.id } });
        return row;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new HttpError(409, 'This subject version already exists');
      throw error;
    }
  }
  async transition(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const { action, comment } = curriculumDecisionInput.parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const row = await tx.curriculumVersion.findUnique({ where: { id: versionId }, include: { topics: { include: { objectives: true } } } });
      if (!row) throw new HttpError(404, 'Framework not found');
      // Legacy review states remain publishable without an approval step.
      const from = row.status;
      const to = 'PUBLISHED' as const;
      if (from === 'PUBLISHED') throw new HttpError(409, 'This version is already published');
      if (!publicationContent.safeParse(row).success) throw new HttpError(422, 'Add a level, topics and measurable objectives with assessment criteria before publishing');
      curriculumInput.parse({ subject: row.subject, version: row.version,
        description: row.description, objectives: row.objectives });
      const updated = await tx.curriculumVersion.updateMany({ where: { id: versionId, status: from, updatedAt: row.updatedAt },
        data: { status: to,
          reviewedBy: null, publishedAt: new Date(),
        } });
      if (updated.count !== 1) throw new HttpError(409, 'Framework status has changed');
      await tx.curriculumReview.create({ data: {
        versionId, actorId: user.id, action, fromStatus: from, toStatus: to,
        comment: comment || null,
      } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: `curriculum.${action}`, entityType: 'CurriculumVersion', entityId: versionId } });
      return { id: versionId, status: to };
    });
  }
  async clone(actor: PlatformContext, id: unknown, input: unknown) {
    const sourceId = idSchema.parse(id);
    const data = curriculumInput.pick({ version: true }).extend({
      reason: z.string().trim().min(10).max(1000),
    }).strict().parse(input);
    try {
      return await this.db.$transaction(async tx => {
        const user = await this.authorize(tx, actor);
        const source = await tx.curriculumVersion.findUnique({ where: { id: sourceId }, include: { lessons: { include: { objectives: true } }, topics: { include: { objectives: true } } } });
        if (!source || source.status !== 'PUBLISHED') throw new HttpError(409, 'Choose a published version');
        if (data.version === source.version) throw new HttpError(422, 'Choose a different version number');
        const copied = curriculumInput.parse({ subject: source.subject, version: data.version,
          description: source.description, objectives: source.objectives });
        const objectiveIds = new Map(source.topics.flatMap(topic => topic.objectives.map(objective =>
          [objective.id, randomBytes(12).toString('hex')] as const)));
        const draft = await tx.curriculumVersion.create({ data: { ...copied, level: source.level, createdBy: user.id,
          topics: { create: source.topics.map(topic => ({
            title: topic.title, position: topic.position,
            objectives: { create: topic.objectives.map(objective => ({
              id: objectiveIds.get(objective.id)!, code: objective.code, description: objective.description,
              assessmentMethod: objective.assessmentMethod, criteria: objective.criteria,
            })) },
          })) },
        } });
        for (const lesson of source.lessons) {
          const ids = lesson.objectives.map(link => objectiveIds.get(link.objectiveId));
          if (ids.some(id => !id)) throw new HttpError(409, 'Source lesson has an invalid objective link');
          await tx.curriculumLesson.create({ data: {
            versionId: draft.id, title: lesson.title, position: lesson.position,
            durationMinutes: lesson.durationMinutes, activities: lesson.activities,
            objectives: { create: ids.map(id => ({ objectiveId: id! })) },
          } });
        }
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.draft.cloned', entityType: 'CurriculumVersion', entityId: draft.id,
          metadata: { sourceVersionId: sourceId, reason: data.reason } } });
        return draft;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new HttpError(409, 'This subject version already exists');
      throw error;
    }
  }
  async edit(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const { level, ...data } = curriculumInput.omit({ subject: true, version: true }).parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const changed = await tx.curriculumVersion.updateMany({ where: { id: versionId, status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] } }, data: { ...data, ...(level === undefined ? {} : { level }), status: 'DRAFT', reviewedBy: null } });
      if (changed.count !== 1) throw new HttpError(409, 'Only unpublished versions can be edited');
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role, action: 'curriculum.draft.updated', entityType: 'CurriculumVersion', entityId: versionId } });
      return { id: versionId };
    });
  }
  async addTopic(actor: PlatformContext, id: unknown, input: unknown, existingId?: unknown) {
    const versionId = idSchema.parse(id);
    const topicId = existingId === undefined ? undefined : idSchema.parse(existingId);
    const data = topicInput.parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      // Lock the parent before changing its outline so publication cannot race a content write.
      const changed = await tx.curriculumVersion.updateMany({
        where: { id: versionId, status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] } },
        data: { status: 'DRAFT', reviewedBy: null, updatedAt: new Date() },
      });
      if (changed.count !== 1) throw new HttpError(409, 'Only unpublished versions can be edited');
      if (topicId) {
        const existing = await tx.curriculumTopic.findFirst({ where: { id: topicId, versionId } });
        if (!existing) throw new HttpError(404, 'Topic not found in this version');
        await tx.curriculumTopic.update({ where: { id: topicId }, data: { title: data.title, position: data.position } });
        // Preserve IDs of retained objectives. Only unused draft objectives may be removed.
        const linked = await tx.curriculumObjective.count({ where: {
          topicId, code: { notIn: data.objectives.map(o => o.code) }, lessons: { some: {} },
        } });
        if (linked) throw new HttpError(409, 'Remove this objective from lesson plans before changing its code or removing it');
        await tx.curriculumObjective.deleteMany({ where: { topicId, code: { notIn: data.objectives.map(o => o.code) } } });
        for (const objective of data.objectives) {
          await tx.curriculumObjective.upsert({ where: { topicId_code: { topicId, code: objective.code } },
            create: { topicId, ...objective }, update: objective });
        }
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.topic.updated', entityType: 'CurriculumVersion', entityId: versionId,
          metadata: { topicId } } });
        return { id: versionId };
      }
      const topic = await tx.curriculumTopic.create({ data: {
        versionId, title: data.title, position: data.position,
        objectives: { create: data.objectives },
      }, include: { objectives: true } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: 'curriculum.topic.created', entityType: 'CurriculumVersion', entityId: versionId,
        metadata: { topicId: topic.id, objectiveCount: data.objectives.length } } });
      return { id: versionId, topic };
    });
  }
  async saveLesson(actor: PlatformContext, id: unknown, input: unknown, existingId?: unknown) {
    const versionId = idSchema.parse(id);
    const lessonId = existingId === undefined ? undefined : idSchema.parse(existingId);
    const { objectiveIds, ...data } = curriculumLessonInput.parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const changed = await tx.curriculumVersion.updateMany({
        where: { id: versionId, status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] } },
        data: { status: 'DRAFT', reviewedBy: null, updatedAt: new Date() },
      });
      if (changed.count !== 1) throw new HttpError(409, 'Only unpublished versions can be edited');
      const count = await tx.curriculumObjective.count({ where: { id: { in: objectiveIds }, topic: { versionId } } });
      if (count !== objectiveIds.length) throw new HttpError(422, 'Choose objectives from this framework version');
      if (lessonId) {
        const existing = await tx.curriculumLesson.findFirst({ where: { id: lessonId, versionId } });
        if (!existing) throw new HttpError(404, 'Lesson not found in this version');
        await tx.curriculumLessonObjective.deleteMany({ where: { lessonId } });
        await tx.curriculumLesson.update({ where: { id: lessonId }, data: {
          ...data, objectives: { create: objectiveIds.map(objectiveId => ({ objectiveId })) },
        } });
      } else {
        await tx.curriculumLesson.create({ data: { ...data, versionId,
          objectives: { create: objectiveIds.map(objectiveId => ({ objectiveId })) },
        } });
      }
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: lessonId ? 'curriculum.lesson.updated' : 'curriculum.lesson.created',
        entityType: 'CurriculumVersion', entityId: versionId } });
      return { id: versionId };
    });
  }
  async assign(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const { organizationId } = z.object({ organizationId: z.string().regex(/^[1-9]\d{0,18}$/) }).strict().parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const row = await tx.curriculumVersion.findUnique({ where: { id: versionId }, include: { topics: { include: { objectives: true } } } });
      if (!row || row.status !== 'PUBLISHED') throw new HttpError(409, 'Only published versions can be assigned');
      const school = await tx.organization.findUnique({ where: { id: BigInt(organizationId) } });
      if (!school || school.status !== 'ACTIVE') throw new HttpError(422, 'Choose an active madrasa');
      const assignment = await tx.curriculumAssignment.upsert({
        where: { versionId_organizationId: { versionId, organizationId: school.id } }, update: {},
        create: { versionId, organizationId: school.id, assignedBy: user.id },
      });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: 'curriculum.assigned', entityType: 'CurriculumVersion', entityId: versionId, metadata: { organizationId } } });
      return { ...assignment, organizationId };
    });
  }
}
