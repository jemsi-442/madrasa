import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { createHash } from 'node:crypto';
import { HttpError } from '../../shared/errors/http-error';
import type { PlatformContext } from './platform.service';

export const incidentCreate = z.object({
  requestId: z.string().regex(/^[a-zA-Z0-9-]{16,80}$/).optional(),
  title: z.string().trim().min(5).max(160),
  description: z.string().trim().min(10).max(4000),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH']),
}).strict();
export const incidentUpdate = z.object({
  revision: z.number().int().positive(),
  status: z.enum(['OPEN', 'INVESTIGATING', 'RESOLVED']),
  note: z.string().trim().min(10).max(4000),
}).strict();
export const incidentQuery = z.object({
  page: z.coerce.number().int().min(1).max(10000).default(1),
  status: z.enum(['OPEN', 'INVESTIGATING', 'RESOLVED']).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH']).optional(),
}).strict();

export class SecurityIncidentsService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!account || account.status !== 'ACTIVE' || account.role !== 'IT_SECURITY') throw new HttpError(403, 'Incident access is restricted to active IT accounts');
  }
  async list(actor: PlatformContext, input: unknown) {
    const { page, status, priority } = incidentQuery.parse(input);
    const where = { ...(status ? { status } : {}), ...(priority ? { priority } : {}) };
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const now = new Date();
      const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
      const items = await tx.securityIncident.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * 20, take: 20 });
      return { items, page, total: await tx.securityIncident.count({ where }),
        open: await tx.securityIncident.count({ where: { status: { not: 'RESOLVED' } } }),
        high: await tx.securityIncident.count({ where: { priority: 'HIGH', status: { not: 'RESOLVED' } } }),
        resolved: await tx.securityIncident.count({ where: { status: 'RESOLVED', resolvedAt: { gte: start, lte: now } } }),
      };
    });
  }
  async detail(actor: PlatformContext, id: string) {
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const row = await tx.securityIncident.findUnique({ where: { id }, include: { entries: { orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] } } });
      if (!row) throw new HttpError(404, 'Incident not found');
      return row;
    });
  }
  async create(actor: PlatformContext, input: unknown) {
    const { requestId, ...data } = incidentCreate.parse(input);
    const id = requestId ? createHash('sha256').update(`${actor.accountId}:${requestId}`).digest('hex').slice(0, 30) : undefined;
    const save = () => this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const create = { ...data, ...(id ? { id } : {}), ownerId: actor.accountId,
        entries: { create: { actorId: actor.accountId, status: 'OPEN', note: 'Incident recorded.' } } };
      const row = id
        ? await tx.securityIncident.upsert({ where: { id }, create, update: {} })
        : await tx.securityIncident.create({ data: create });
      if (id && (row.ownerId !== actor.accountId || row.title !== data.title || row.description !== data.description || row.priority !== data.priority)) {
        throw new HttpError(409, 'This request was already used for a different incident.');
      }
      const audit = { actorId: actor.accountId, actorRole: 'IT_SECURITY' as const, action: 'security.incident.created', entityType: 'SecurityIncident', entityId: row.id };
      if (id) {
        await tx.platformAuditEvent.upsert({ where: { id }, create: { id, ...audit }, update: {} });
      } else {
        await tx.platformAuditEvent.create({ data: audit });
      }
      return row;
    });
    try {
      return await save();
    } catch (error) {
      // Nested upserts may race on the unique key; retry after rollback.
      if (id && error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') return save();
      throw error;
    }
  }
  async update(actor: PlatformContext, id: string, input: unknown) {
    const data = incidentUpdate.parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const changed = await tx.securityIncident.updateMany({ where: { id, revision: data.revision },
        data: { status: data.status, revision: { increment: 1 }, resolvedAt: data.status === 'RESOLVED' ? new Date() : null } });
      if (changed.count !== 1) throw new HttpError(409, 'Incident changed. Reload before updating.');
      await tx.securityIncidentEntry.create({ data: { incidentId: id, actorId: actor.accountId, status: data.status, note: data.note } });
      await tx.platformAuditEvent.create({ data: { actorId: actor.accountId, actorRole: 'IT_SECURITY', action: 'security.incident.updated', entityType: 'SecurityIncident', entityId: id } });
      return tx.securityIncident.findUniqueOrThrow({ where: { id } });
    });
  }
}
