import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../shared/db/prisma';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';
import { residenceLocationSchema } from '../../shared/validation/location';

export const studentResidenceSchema = z.object({
  revision: z.string().datetime(), reason: z.string().trim().min(10).max(500),
  residence: z.discriminatedUnion('mode', [
    z.object({ mode: z.literal('UNKNOWN') }).strict(),
    z.object({ mode: z.literal('GUARDIAN'), guardianId: z.string().regex(/^\d+$/) }).strict(),
    z.object({ mode: z.literal('SEPARATE'), location: residenceLocationSchema }).strict(),
  ]),
}).strict();

async function record(tx: Prisma.TransactionClient, user: AuthenticatedUser, rawId: unknown) {
  if (user.role !== 'ADMIN') throw new HttpError(403, 'Administrator required');
  const id = BigInt(z.string().regex(/^\d+$/).parse(rawId));
  const student = await tx.student.findFirst({ where: { id, orgId: BigInt(user.orgId),
    ...(user.branchId ? { branchId: BigInt(user.branchId) } : {}) },
    select: { id: true, fullName: true, residence: true, updatedAt: true, primaryGuardianId: true } });
  if (!student) throw new HttpError(404, 'Student not found');
  const guardian = student.primaryGuardianId ? await tx.guardian.findFirst({
    where: { id: student.primaryGuardianId, orgId: BigInt(user.orgId) },
    select: { id: true, fullName: true, residenceLocation: true, address: true },
  }) : null;
  return { student, guardian };
}

export async function readStudentResidence(user: AuthenticatedUser, id: unknown) {
  return prisma.$transaction(async tx => {
    const { student, guardian } = await record(tx, user, id);
    const residence = student.residence as { mode?: string; guardianId?: string; location?: unknown } | null;
    const needsReview = residence?.mode === 'GUARDIAN' && residence.guardianId !== guardian?.id.toString();
    return { fullName: student.fullName, revision: student.updatedAt.toISOString(),
      residence: student.residence ?? { mode: 'UNKNOWN' }, needsReview,
      guardian: guardian ? { id: guardian.id.toString(), fullName: guardian.fullName,
        location: guardian.residenceLocation, legacyAddress: guardian.address } : null,
      effectiveLocation: needsReview ? null : residence?.mode === 'GUARDIAN'
        ? guardian?.residenceLocation ?? null : residence?.mode === 'SEPARATE' ? residence.location : null,
    };
  });
}

export async function saveStudentResidence(user: AuthenticatedUser, id: unknown, input: unknown) {
  const data = studentResidenceSchema.parse(input);
  return prisma.$transaction(async tx => {
    const { student, guardian } = await record(tx, user, id);
    if (data.residence.mode === 'GUARDIAN' && data.residence.guardianId !== guardian?.id.toString()) {
      throw new HttpError(409, 'Primary guardian changed or is unavailable. Reopen the form.');
    }
    const changed = await tx.student.updateMany({ where: { id: student.id, orgId: BigInt(user.orgId),
      updatedAt: new Date(data.revision) }, data: { residence: data.residence,
      updatedAt: new Date(Math.max(Date.now(), student.updatedAt.getTime() + 1)) } });
    if (changed.count !== 1) throw new HttpError(409, 'Student changed. Reopen the form.');
    await tx.auditLog.create({ data: { orgId: BigInt(user.orgId), actorUserId: BigInt(user.userId),
      action: 'student.residence.updated', entityType: 'Student', entityId: student.id.toString(),
      metadata: { mode: data.residence.mode, reason: data.reason } } });
    return { saved: true };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
