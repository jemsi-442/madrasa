import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';

const id = z.string().regex(/^[1-9]\d*$/).max(19);
const adoptionInput = z.object({ assignmentId: z.string().min(1).max(30), classId: id, subjectId: id }).strict();
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
        select: { id: true, version: { select: content }, adoptions: {
          where: { class: where }, select: { id: true, createdAt: true,
            class: { select: classSelection }, subject: { select: { id: true, name: true } } },
        } },
      });
      const classes = await tx.class.findMany({ where, select: classSelection, orderBy: { name: 'asc' } });
      const subjects = actor.role === 'ADMIN' ? await tx.subject.findMany({
        where: { orgId: BigInt(actor.orgId), isActive: true },
        select: { id: true, name: true }, orderBy: { name: 'asc' },
      }) : [];
      return serialise({ assignments, classes, subjects });
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
        }, select: { id: true } });
        const classroom = await tx.class.findFirst({ where: { ...classScope(actor), id: BigInt(input.classId) }, select: { id: true } });
        const subject = await tx.subject.findFirst({ where: { id: BigInt(input.subjectId), orgId: BigInt(actor.orgId), isActive: true }, select: { id: true } });
        if (!assignment || !classroom || !subject) throw new HttpError(404, 'Curriculum, class or subject is unavailable');
        const key = { classId: classroom.id, subjectId: subject.id };
        const existing = await tx.classCurriculum.findUnique({ where: { classId_subjectId: key } });
        if (existing) {
          if (existing.assignmentId !== assignment.id) throw new HttpError(409, 'This class subject already uses a version. Existing adoption is preserved.');
          return serialise(existing);
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
}
