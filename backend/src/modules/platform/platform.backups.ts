import { createHash } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import type { PlatformContext } from './platform.service';

export const restoreRequest = z.object({
  requestId: z.string().min(16).max(80).regex(/^[a-zA-Z0-9-]+$/),
  snapshot: z.string().trim().min(3).max(100),
  reason: z.string().trim().min(10).max(1000),
}).strict();
const action = 'backup.restore_test.requested';

// Requests are immutable audit records, not jobs or evidence of a completed restore.
export class BackupRequestsService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const account = await this.db.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!account || account.role !== 'IT_SECURITY' || account.status !== 'ACTIVE') {
      throw new HttpError(403, 'Backup requests are restricted to active IT accounts');
    }
  }
  async list(actor: PlatformContext, input: unknown) {
    await this.authorize(actor);
    const { page } = z.object({ page: z.coerce.number().int().min(1).max(10000).default(1) }).strict().parse(input);
    const where = { action, entityType: 'RestoreTestRequest' };
    const [items, total] = await this.db.$transaction([
      this.db.platformAuditEvent.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * 20, take: 20,
        select: { id: true, createdAt: true, metadata: true } }),
      this.db.platformAuditEvent.count({ where }),
    ]);
    return { items, total, page, executionConnected: false };
  }
  async request(actor: PlatformContext, input: unknown) {
    await this.authorize(actor);
    const data = restoreRequest.parse(input);
    const id = createHash('sha256').update(`${actor.accountId}:${data.requestId}`).digest('hex').slice(0, 28);
    const metadata = { snapshot: data.snapshot, reason: data.reason, status: 'REQUESTED', environment: 'ISOLATED_TEST' };
    const record = await this.db.platformAuditEvent.upsert({
      where: { id }, update: {},
      create: { id, actorId: actor.accountId, actorRole: 'IT_SECURITY', action, entityType: 'RestoreTestRequest', entityId: id, metadata },
      select: { id: true, metadata: true, createdAt: true },
    });
    const saved = record.metadata as Record<string, unknown>;
    if (saved.snapshot !== data.snapshot || saved.reason !== data.reason) {
      throw new HttpError(409, 'Request already recorded with different details. Review request history.');
    }
    return record;
  }
}
