import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../shared/db/prisma';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';

const ids = z.array(z.string().regex(/^[1-9][0-9]*$/)).min(1).max(1000);
export const courseOrderSchema = z.object({ ids, expectedIds: ids }).strict();

export function validateCourseOrder(current: string[], expected: string[], next: string[]) {
  if (current.length !== expected.length || current.some((id, i) => id !== expected[i])) {
    throw new HttpError(409, 'The outline changed. Reopen the course before reordering.');
  }
  if (next.length !== current.length || new Set(next).size !== next.length ||
      next.some(id => !current.includes(id))) {
    throw new HttpError(400, 'Include each item in this outline exactly once.');
  }
}

export async function reorderCourseOutline(
  actor: AuthenticatedUser, parentId: string, kind: 'modules' | 'lessons', input: unknown,
) {
  if (!['ADMIN', 'TEACHER'].includes(actor.role)) throw new HttpError(403, 'Author access required');
  if (!/^[1-9][0-9]*$/.test(parentId)) throw new HttpError(400, 'Invalid outline identifier');
  const order = courseOrderSchema.parse(input);
  return prisma.$transaction(async tx => {
    const orgId = BigInt(actor.orgId);
    const parent = kind === 'lessons'
      ? await tx.courseModule.findFirst({ where: { id: BigInt(parentId), orgId } })
      : null;
    if (kind === 'lessons' && !parent) throw new HttpError(404, 'Module not found');
    const course = await tx.course.findFirst({
      where: { id: parent?.courseId ?? BigInt(parentId), orgId },
    });
    if (!course) throw new HttpError(404, 'Course not found');
    if (actor.role === 'TEACHER' && course.primaryInstructorUserId !== BigInt(actor.userId)) {
      throw new HttpError(403, 'You can only arrange your assigned courses');
    }
    const rows = kind === 'modules'
      ? await tx.courseModule.findMany({ where: { courseId: course.id, orgId }, orderBy: { position: 'asc' } })
      : await tx.courseLesson.findMany({ where: { moduleId: BigInt(parentId), orgId }, orderBy: { position: 'asc' } });
    validateCourseOrder(rows.map(row => String(row.id)), order.expectedIds, order.ids);
    const offset = Math.max(0, ...rows.map(row => row.position));
    if (offset + rows.length > 2147483647) throw new HttpError(409, 'Outline positions exceed supported range');
    // Move to unused positions first so swaps respect the unique position indexes.
    for (const [index, id] of order.ids.entries()) {
      const data = { position: offset + index + 1 };
      if (kind === 'modules') await tx.courseModule.update({ where: { id: BigInt(id) }, data });
      else await tx.courseLesson.update({ where: { id: BigInt(id) }, data });
    }
    for (const [index, id] of order.ids.entries()) {
      const data = { position: index + 1 };
      if (kind === 'modules') await tx.courseModule.update({ where: { id: BigInt(id) }, data });
      else await tx.courseLesson.update({ where: { id: BigInt(id) }, data });
    }
    return { ids: order.ids };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
