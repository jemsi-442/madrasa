import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';

const maxDatabaseId = 9_223_372_036_854_775_807n;
const id = z.string().regex(/^[1-9]\d{0,18}$/).refine(value => BigInt(value) <= maxDatabaseId);
const adoptionInput = z.object({ assignmentId: z.string().min(1).max(30), classId: id, subjectId: id }).strict();
const deliveryInput = z.object({
  classCurriculumId: z.string().min(1).max(30),
  assignmentId: z.string().min(1).max(30),
  lessonId: z.string().min(1).max(30),
  clientEventId: z.string().uuid(),
}).strict();
const classScope = (actor: AuthenticatedUser) => ({
  orgId: BigInt(actor.orgId),
  ...(actor.branchId ? { branchId: BigInt(actor.branchId) } : {}),
  ...(actor.role === 'TEACHER' ? { teacherId: BigInt(actor.userId) } : {}),
});
const classSelection = { id: true, name: true, level: true, academicYear: true } as const;
const content = {
  id: true, subject: true, level: true, version: true, description: true,
  topics: { orderBy: { position: 'asc' as const }, include: { objectives: true } },
  lessons: { orderBy: { position: 'asc' as const }, include: { objectives: { include: { objective: true } } } },
} satisfies Prisma.CurriculumVersionSelect;
const serialise = (value: unknown) => JSON.parse(JSON.stringify(value, (_, v) => typeof v === 'bigint' ? v.toString() : v));

export class SchoolCurriculumService {
  constructor(private readonly db: PrismaClient) {}

  private async authorize(tx: Prisma.TransactionClient, actor: AuthenticatedUser) {
    if (!['ADMIN', 'TEACHER'].includes(actor.role)) throw new HttpError(403, 'Curriculum access is not permitted');
    const active = await tx.user.findFirst({ where: {
      id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: actor.role, status: 'ACTIVE',
      branchId: actor.branchId ? BigInt(actor.branchId) : null,
      organization: { status: { in: ['ACTIVE', 'TRIAL'] } },
    }, select: { id: true } });
    if (!active) throw new HttpError(403, 'Curriculum access is not permitted');
  }

  async list(actor: AuthenticatedUser) {
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const where = classScope(actor);
      const assignments = await tx.curriculumAssignment.findMany({
        where: { organizationId: BigInt(actor.orgId), version: { status: 'PUBLISHED' },
          ...(actor.role === 'TEACHER' ? { adoptions: { some: { class: where } } } : {}) },
        orderBy: { createdAt: 'desc' },
        select: { id: true, subjectId: true, version: { select: content }, adoptions: {
          where: { class: where }, select: { id: true, createdAt: true,
            class: { select: classSelection }, subject: { select: { id: true, name: true } },
            history: { orderBy: { replacedAt: 'desc' }, select: { id: true, replacedAt: true, previousAdoptedAt: true,
              previousAssignment: { select: { version: { select: { subject: true, level: true, version: true } } } } } },
          },
        } },
      });
      const classes = await tx.class.findMany({ where, select: classSelection, orderBy: { name: 'asc' } });
      const mappedSubjectIds = assignments.flatMap(assignment =>
        assignment.subjectId === null ? [] : [assignment.subjectId],
      );
      const subjects = actor.role === 'ADMIN' ? await tx.subject.findMany({
        where: { orgId: BigInt(actor.orgId), OR: [
          { isActive: true },
          ...(mappedSubjectIds.length ? [{ id: { in: mappedSubjectIds } }] : []),
        ] },
        select: { id: true, name: true, isActive: true }, orderBy: { name: 'asc' },
      }) : [];
      const coverageScopes = assignments.filter(assignment => assignment.adoptions.length > 0).map(assignment => ({
        assignmentId: assignment.id,
        classCurriculumId: { in: assignment.adoptions.map(adoption => adoption.id) },
        lesson: { versionId: assignment.version.id },
      }));
      const taught = coverageScopes.length === 0 ? [] : await tx.curriculumLessonDelivery.groupBy({
        by: ['classCurriculumId', 'assignmentId', 'lessonId'],
        where: { orgId: BigInt(actor.orgId), OR: coverageScopes },
      });
      const counts = new Map<string, number>();
      for (const row of taught) {
        const key = `${row.assignmentId}/${row.classCurriculumId}`;
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
      const withCoverage = assignments.map(assignment => ({
        ...assignment,
        adoptions: assignment.adoptions.map(adoption => ({
          ...adoption,
          teachingCoverage: {
            version: assignment.version.version,
            taughtLessons: counts.get(`${assignment.id}/${adoption.id}`) ?? 0,
            totalLessons: assignment.version.lessons.length,
          },
        })),
      }));
      return serialise({ assignments: withCoverage, classes, subjects });
    });
  }

  async adopt(actor: AuthenticatedUser, raw: unknown) {
    if (actor.role !== 'ADMIN') throw new HttpError(403, 'Only madrasa administrators can adopt curriculum');
    const input = adoptionInput.parse(raw);
    try {
      return await this.db.$transaction(async tx => {
        await this.authorize(tx, actor);
        const assignment = await tx.curriculumAssignment.findFirst({ where: {
          id: input.assignmentId, organizationId: BigInt(actor.orgId), version: { status: 'PUBLISHED' },
        }, select: { id: true, subjectId: true } });
        const classroom = await tx.class.findFirst({ where: { ...classScope(actor), id: BigInt(input.classId) }, select: { id: true } });
        const subject = await tx.subject.findFirst({ where: { id: BigInt(input.subjectId), orgId: BigInt(actor.orgId), isActive: true }, select: { id: true } });
        if (!assignment || !classroom || !subject) throw new HttpError(404, 'Curriculum, class or subject is unavailable');
        if (assignment.subjectId !== null && assignment.subjectId !== subject.id) {
          throw new HttpError(422, 'This curriculum assignment is linked to a different school subject');
        }
        if (assignment.subjectId === null) {
          const conflictingAdoption = await tx.classCurriculum.findFirst({ where: {
            orgId: BigInt(actor.orgId), assignmentId: assignment.id, subjectId: { not: subject.id },
          }, select: { id: true } });
          if (conflictingAdoption) throw new HttpError(409, 'This curriculum assignment already has an adoption for another school subject');
          const mapped = await tx.curriculumAssignment.updateMany({
            where: { id: assignment.id, organizationId: BigInt(actor.orgId), subjectId: null },
            data: { subjectId: subject.id },
          });
          if (mapped.count !== 1) {
            const currentAssignment = await tx.curriculumAssignment.findFirst({ where: {
              id: assignment.id, organizationId: BigInt(actor.orgId),
            }, select: { subjectId: true } });
            if (currentAssignment?.subjectId !== subject.id) {
              throw new HttpError(409, 'Curriculum subject mapping changed. Refresh and try again.');
            }
          }
        }
        const key = { classId: classroom.id, subjectId: subject.id };
        const existing = await tx.classCurriculum.findUnique({ where: { classId_subjectId: key } });
        if (existing) {
          if (existing.assignmentId === assignment.id) return serialise(existing);
          const changedAt = new Date();
          await tx.classCurriculumHistory.create({ data: {
            classCurriculumId: existing.id,
            orgId: BigInt(actor.orgId),
            classId: classroom.id,
            subjectId: subject.id,
            previousAssignmentId: existing.assignmentId,
            previousAdoptedBy: existing.adoptedBy,
            previousAdoptedAt: existing.createdAt,
            replacedBy: BigInt(actor.userId),
          } });
          const updated = await tx.classCurriculum.updateMany({
            where: { id: existing.id, assignmentId: existing.assignmentId, orgId: BigInt(actor.orgId) },
            data: { assignmentId: assignment.id, adoptedBy: BigInt(actor.userId), createdAt: changedAt },
          });
          if (updated.count !== 1) throw new HttpError(409, 'Adoption changed. Refresh before trying again.');
          const current = { ...existing, assignmentId: assignment.id, adoptedBy: BigInt(actor.userId), createdAt: changedAt };
          await tx.auditLog.create({ data: { orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId), action: 'curriculum.class.version_changed', entityType: 'ClassCurriculum', entityId: existing.id,
            metadata: { previousAssignmentId: existing.assignmentId, assignmentId: assignment.id, classId: input.classId, subjectId: input.subjectId } } });
          return serialise(current);
        }
        const created = await tx.classCurriculum.create({ data: { ...key, orgId: BigInt(actor.orgId), assignmentId: assignment.id, adoptedBy: BigInt(actor.userId) } });
        await tx.auditLog.create({ data: { orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId), action: 'curriculum.class.adopted', entityType: 'ClassCurriculum', entityId: created.id,
          metadata: { assignmentId: assignment.id, classId: input.classId, subjectId: input.subjectId } } });
        return serialise(created);
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new HttpError(409, 'Adoption changed. Refresh before trying again.');
      throw error;
    }
  }

  async recordDelivery(actor: AuthenticatedUser, raw: unknown) {
    if (actor.role !== 'TEACHER') throw new HttpError(403, 'Only the assigned teacher can record teaching');
    const input = deliveryInput.parse(raw);
    try {
      return await this.db.$transaction(async tx => {
        await this.authorize(tx, actor);
        const adoption = await tx.classCurriculum.findFirst({
          where: { id: input.classCurriculumId, orgId: BigInt(actor.orgId), class: classScope(actor) },
          include: { assignment: { include: { version: true } }, subject: true },
        });
        if (!adoption) throw new HttpError(404, 'Class curriculum is unavailable');
        const existing = await tx.curriculumLessonDelivery.findUnique({ where: {
          orgId_teacherId_clientEventId: {
            orgId: BigInt(actor.orgId), teacherId: BigInt(actor.userId), clientEventId: input.clientEventId,
          },
        } });
        if (existing) {
          if (existing.classCurriculumId !== input.classCurriculumId || existing.assignmentId !== input.assignmentId || existing.lessonId !== input.lessonId) {
            throw new HttpError(409, 'This event ID was already used for another delivery');
          }
          return serialise(existing);
        }
        if (adoption.assignmentId !== input.assignmentId || adoption.assignment.version.status !== 'PUBLISHED' || !adoption.subject.isActive) {
          throw new HttpError(409, 'Class curriculum changed. Refresh before recording teaching.');
        }
        const lesson = await tx.curriculumLesson.findFirst({ where: {
          id: input.lessonId, versionId: adoption.assignment.versionId,
        }, select: { id: true } });
        if (!lesson) throw new HttpError(422, 'Choose a lesson from the adopted curriculum version');
        const delivery = await tx.curriculumLessonDelivery.create({ data: {
          ...input, orgId: BigInt(actor.orgId), teacherId: BigInt(actor.userId),
        } });
        await tx.auditLog.create({ data: {
          orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId),
          action: 'curriculum.lesson.taught', entityType: 'CurriculumLessonDelivery', entityId: delivery.id,
          metadata: { classCurriculumId: adoption.id, assignmentId: input.assignmentId, lessonId: input.lessonId },
        } });
        return serialise(delivery);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && ['P2002', 'P2034'].includes(error.code)) {
        throw new HttpError(409, 'Concurrent update. Retry with the same event ID.');
      }
      throw error;
    }
  }

  async deliveryHistory(actor: AuthenticatedUser, raw: unknown) {
    const query = z.object({
      classCurriculumId: z.string().min(1).max(30),
      page: z.coerce.number().int().min(1).max(10000).default(1),
    }).strict().parse(raw);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const adoption = await tx.classCurriculum.findFirst({
        where: { id: query.classCurriculumId, orgId: BigInt(actor.orgId), class: classScope(actor) },
        select: { id: true, assignmentId: true, assignment: { select: { versionId: true, version: { select: { version: true } } } } },
      });
      if (!adoption) throw new HttpError(404, 'Class curriculum is unavailable');
      const rows = await tx.curriculumLessonDelivery.findMany({
        where: { orgId: BigInt(actor.orgId), classCurriculumId: adoption.id },
        orderBy: [{ taughtAt: 'desc' }, { id: 'desc' }],
        skip: (query.page - 1) * 20, take: 21,
        select: {
          id: true, taughtAt: true,
          lesson: { select: { title: true } },
          teacher: { select: { fullName: true } },
          assignment: { select: { version: { select: { subject: true, level: true, version: true } } } },
        },
      });
      const totalLessons = await tx.curriculumLesson.count({ where: { versionId: adoption.assignment.versionId } });
      const taughtLessons = await tx.curriculumLessonDelivery.groupBy({
        by: ['lessonId'],
        where: {
          orgId: BigInt(actor.orgId), classCurriculumId: adoption.id,
          assignmentId: adoption.assignmentId,
          lesson: { versionId: adoption.assignment.versionId },
        },
      });
      const pendingLessons = await tx.curriculumLesson.findMany({
        where: {
          versionId: adoption.assignment.versionId,
          id: { notIn: taughtLessons.map(row => row.lessonId) },
        },
        orderBy: [{ position: 'asc' }, { id: 'asc' }],
        take: 10,
        select: { id: true, title: true },
      });
      return serialise({
        items: rows.slice(0, 20), page: query.page, hasMore: rows.length > 20,
        pendingLessons,
        teachingCoverage: {
          version: adoption.assignment.version.version,
          taughtLessons: taughtLessons.length, totalLessons,
        },
      });
    });
  }
}
