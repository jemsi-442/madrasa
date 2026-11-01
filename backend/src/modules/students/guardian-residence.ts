import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../shared/db/prisma';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';
import { residenceLocationSchema } from '../../shared/validation/location';

export const guardianResidenceUpdateSchema = z.object({
  guardianId: z.string().regex(/^\d+$/),
  revision: z.string().datetime(),
  location: residenceLocationSchema.nullable(),
  reason: z.string().trim().min(10).max(500),
}).strict();

async function scopedGuardian(tx: Prisma.TransactionClient, user: AuthenticatedUser, rawId: unknown) {
  if (user.role !== 'ADMIN') throw new HttpError(403, 'Administrator required');
  const id = BigInt(z.string().regex(/^\d+$/).parse(rawId));
  const student = await tx.student.findFirst({ where: {
    id, orgId: BigInt(user.orgId), ...(user.branchId ? { branchId: BigInt(user.branchId) } : {}),
  }, select: { primaryGuardianId: true } });
  if (!student) throw new HttpError(404, 'Student not found');
  if (!student.primaryGuardianId) throw new HttpError(409, 'No primary guardian is linked');
  const guardian = await tx.guardian.findFirst({ where: { id: student.primaryGuardianId, orgId: BigInt(user.orgId) },
    select: { id: true, fullName: true, address: true, residenceLocation: true, updatedAt: true } });
  if (!guardian) throw new HttpError(404, 'Guardian not found');
  // Changing a shared guardian affects every linked child, not only this record.
  if (user.branchId && await tx.student.count({ where: {
    branchId: { not: BigInt(user.branchId) },
    OR: [{ primaryGuardianId: guardian.id }, { guardians: { some: { guardianId: guardian.id } } }],
  } })) throw new HttpError(403, 'A school-wide administrator must update this shared guardian');
  return guardian;
}

export async function readGuardianResidence(user: AuthenticatedUser, studentId: unknown) {
  return prisma.$transaction(async tx => {
    const row = await scopedGuardian(tx, user, studentId);
    return { guardianId: row.id.toString(), fullName: row.fullName,
      legacyAddress: row.address, location: row.residenceLocation,
      revision: row.updatedAt.toISOString() };
  });
}

export async function updateGuardianResidence(user: AuthenticatedUser, studentId: unknown, input: unknown) {
  const data = guardianResidenceUpdateSchema.parse(input);
  return prisma.$transaction(async tx => {
    const row = await scopedGuardian(tx, user, studentId);
    if (row.id.toString() !== data.guardianId) throw new HttpError(409, 'Primary guardian changed. Reopen the form.');
    const changed = await tx.guardian.updateMany({
      where: { id: row.id, orgId: BigInt(user.orgId), updatedAt: new Date(data.revision) },
      data: { residenceLocation: data.location ?? Prisma.DbNull,
        updatedAt: new Date(Math.max(Date.now(), row.updatedAt.getTime() + 1)) },
    });
    if (changed.count !== 1) throw new HttpError(409, 'Guardian changed. Reopen the form.');
    await tx.auditLog.create({ data: {
      orgId: BigInt(user.orgId), actorUserId: BigInt(user.userId),
      action: 'guardian.residence.updated', entityType: 'Guardian', entityId: row.id.toString(),
      metadata: { reason: data.reason, cleared: data.location === null },
    } });
    return { saved: true };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
}
