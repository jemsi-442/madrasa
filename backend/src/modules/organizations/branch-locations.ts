import { z } from 'zod';
import { prisma } from '../../shared/db/prisma';
import { HttpError } from '../../shared/errors/http-error';
import type { AuthenticatedUser } from '../../shared/middleware/authenticate';
import { locationSchema } from '../../shared/validation/location';

function scope(user: AuthenticatedUser) {
  if (user.role !== 'ADMIN') throw new HttpError(403, 'Administrator required');
  return { orgId: BigInt(user.orgId), ...(user.branchId ? { id: BigInt(user.branchId) } : {}) };
}

export async function listBranchLocations(user: AuthenticatedUser) {
  const rows = await prisma.branch.findMany({ where: scope(user), orderBy: { name: 'asc' },
    select: { id: true, name: true, location: true, structuredLocation: true, updatedAt: true } });
  return rows.map(row => ({ ...row, id: row.id.toString(), revision: row.updatedAt.toISOString() }));
}

export async function saveBranchLocation(user: AuthenticatedUser, rawId: unknown, input: unknown) {
  const allowed = scope(user);
  const id = BigInt(z.string().regex(/^\d+$/).parse(rawId));
  const data = z.object({ revision: z.string().datetime(), location: locationSchema }).strict().parse(input);
  if (allowed.id && allowed.id !== id) throw new HttpError(404, 'Branch not found');
  return prisma.$transaction(async tx => {
    const row = await tx.branch.findFirst({ where: { ...allowed, id }, select: { updatedAt: true } });
    if (!row) throw new HttpError(404, 'Branch not found');
    const updatedAt = new Date(Math.max(Date.now(), row.updatedAt.getTime() + 1));
    const changed = await tx.branch.updateMany({ where: { ...allowed, id, updatedAt: new Date(data.revision) },
      data: { structuredLocation: data.location, updatedAt } });
    if (changed.count !== 1) throw new HttpError(409, 'Branch changed. Reload before saving.');
    await tx.auditLog.create({ data: { orgId: allowed.orgId, actorUserId: BigInt(user.userId),
      action: 'branch.location.updated', entityType: 'Branch', entityId: id.toString() } });
    return { saved: true };
  });
}
