import type { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import type { PlatformContext } from './platform.service';

export class PlatformSyncService {
  constructor(private readonly db: PrismaClient) {}
  async received(actor: PlatformContext, raw: unknown) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const { page } = z.object({ page: z.coerce.number().int().min(1).max(10000).default(1) }).strict().parse(raw);
    return this.db.$transaction(async tx => {
      const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId }, select: { role: true, status: true } });
      if (!account || account.role !== 'IT_SECURITY' || account.status !== 'ACTIVE') {
        throw new HttpError(403, 'Sync metadata is restricted to active IT accounts');
      }
      const where = { action: 'curriculum.lesson.taught', entityType: 'CurriculumLessonDelivery' };
      // Deliberately exclude actor, payload, lesson and learner identifiers.
      const rows = await tx.auditLog.findMany({ where, select: { id: true, orgId: true, createdAt: true },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * 20, take: 20 });
      return { items: rows.map(row => ({ receiptId: String(row.id), madrasaId: String(row.orgId), receivedAt: row.createdAt })),
        total: await tx.auditLog.count({ where }), page, capturedAt: new Date().toISOString(),
        deviceReportingConnected: false, conflictQueueConnected: false };
    });
  }
}
