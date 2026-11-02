import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { SecurityIncidentsService, incidentCreate, incidentUpdate, incidentQuery } from '../src/modules/platform/platform.incidents';

const actor = { scope: 'platform' as const, accountId: 'synthetic-it', sessionId: 'synthetic-session' };
function fixture(role = 'IT_SECURITY', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    securityIncident: { create: vi.fn().mockResolvedValue({ id: 'synthetic-incident' }), updateMany: vi.fn().mockResolvedValue({ count: 1 }), findUniqueOrThrow: vi.fn().mockResolvedValue({ id: 'synthetic-incident' }) },
    securityIncidentEntry: { create: vi.fn() }, platformAuditEvent: { create: vi.fn() },
  };
  const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
  return { tx, service };
}
describe('Security incidents', () => {
  it('filters unresolved high-priority incidents before pagination', async () => {
    const base = fixture().tx;
    const findMany = vi.fn().mockResolvedValue([]);
    const tx = { ...base, securityIncident: { ...base.securityIncident, findMany, count: vi.fn().mockResolvedValue(0) } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    await service.list(actor, { status: 'UNRESOLVED', priority: 'HIGH', page: 2 });
    expect(findMany).toHaveBeenNthCalledWith(1, expect.objectContaining({
      where: { status: { not: 'RESOLVED' }, priority: 'HIGH' }, skip: 20,
    }));
    expect(incidentUpdate.safeParse({ revision: 1, status: 'UNRESOLVED', note: 'Synthetic response' }).success).toBe(false);
  });
  it('builds a bounded priority queue independently of the register page', async () => {
    const base = fixture().tx;
    const findMany = vi.fn(async (args: any) => {
      if (args.skip !== undefined) return [];
      return [{ id: `synthetic-${args.where.priority}`, title: 'Synthetic concern', priority: args.where.priority }];
    });
    const tx = { ...base, securityIncident: { ...base.securityIncident, findMany, count: vi.fn().mockResolvedValue(0) } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    const result = await service.list(actor, { page: 2, status: 'RESOLVED' });
    expect(result.attention.map(row => row.priority)).toEqual(['HIGH', 'MEDIUM', 'LOW']);
    expect(findMany.mock.calls.slice(1).map(([args]) => args.take)).toEqual([3, 2, 1]);
    for (const [args] of findMany.mock.calls.slice(1)) {
      expect(args.where.status).toEqual({ not: 'RESOLVED' });
      expect(args.select).toEqual({ id: true, title: true, priority: true });
      expect(args.orderBy[0]).toEqual({ createdAt: 'asc' });
    }
  });
  it('retries a saved response without duplicating history or overwriting later changes', async () => {
    const base = fixture().tx;
    const receipts = new Map<string, Record<string, unknown>>();
    const tx = { ...base, platformAuditEvent: {
      findUnique: vi.fn(async ({ where }: { where: { id: string } }) => receipts.get(where.id) ?? null),
      create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
        receipts.set(data.id as string, data);
        return data;
      }),
    } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    const input = { requestId: 'synthetic-response-001', revision: 1, status: 'RESOLVED', note: 'Synthetic resolution' };
    await service.update(actor, 'synthetic-incident', input);
    tx.securityIncident.findUniqueOrThrow.mockResolvedValue({ id: 'synthetic-incident', status: 'INVESTIGATING', revision: 3 } as never);
    const replay = await service.update(actor, 'synthetic-incident', input);
    expect(replay).toMatchObject({ status: 'INVESTIGATING', revision: 3 });
    expect(tx.securityIncident.updateMany).toHaveBeenCalledTimes(1);
    expect(tx.securityIncidentEntry.create).toHaveBeenCalledTimes(1);
    expect(tx.platformAuditEvent.create).toHaveBeenCalledTimes(1);
    expect(JSON.stringify([...receipts.values()])).not.toContain(input.note);
    for (const changed of [{ note: 'Different synthetic resolution' }, { revision: 2 }, { status: 'OPEN' }]) {
      await expect(service.update(actor, 'synthetic-incident', { ...input, ...changed })).rejects.toThrow('different response');
    }
    tx.platformAccount.findUnique.mockResolvedValue({ role: 'IT_SECURITY', status: 'DISABLED' });
    await expect(service.update(actor, 'synthetic-incident', input)).rejects.toThrow('restricted');
    expect(tx.securityIncident.updateMany).toHaveBeenCalledTimes(1);
  });
  it('keeps response retry keys scoped to the actor and incident', async () => {
    const base = fixture().tx;
    const tx = { ...base, platformAuditEvent: { ...base.platformAuditEvent, findUnique: vi.fn().mockResolvedValue(null) } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    const input = { requestId: 'synthetic-response-001', revision: 1, status: 'OPEN', note: 'Synthetic response note' };
    await service.update(actor, 'synthetic-incident', input);
    await service.update({ ...actor, accountId: 'another-synthetic-it' }, 'synthetic-incident', input);
    await service.update(actor, 'another-incident', input);
    const ids = tx.platformAuditEvent.findUnique.mock.calls.map(call => call[0].where.id);
    expect(new Set(ids).size).toBe(3);
    expect(incidentUpdate.safeParse({ ...input, requestId: 'bad/key' }).success).toBe(false);
  });
  it('does not create a retry receipt for a stale response', async () => {
    const base = fixture().tx;
    base.securityIncident.updateMany.mockResolvedValue({ count: 0 });
    const tx = { ...base, platformAuditEvent: { ...base.platformAuditEvent, findUnique: vi.fn().mockResolvedValue(null) } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    await expect(service.update(actor, 'synthetic-incident', {
      requestId: 'synthetic-response-stale', revision: 1, status: 'RESOLVED', note: 'Synthetic stale response',
    })).rejects.toThrow('Reload');
    expect(tx.securityIncidentEntry.create).not.toHaveBeenCalled();
    expect(tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('replays a creation request without replacing the incident or its audit history', async () => {
    const base = fixture().tx;
    const rows = new Map<string, Record<string, unknown>>();
    const upsert = vi.fn(async ({ where, create }: { where: { id: string }, create: Record<string, unknown> }) => {
      if (!rows.has(where.id)) rows.set(where.id, create);
      return rows.get(where.id);
    });
    const auditUpsert = vi.fn();
    const tx = { ...base, securityIncident: { ...base.securityIncident, upsert }, platformAuditEvent: { ...base.platformAuditEvent, upsert: auditUpsert } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    const input = { requestId: 'synthetic-request-001', title: 'Synthetic alert', description: 'Synthetic investigation', priority: 'HIGH' };
    const first = await service.create(actor, input);
    const replay = await service.create(actor, input);
    expect(replay.id).toBe(first.id);
    expect(rows.size).toBe(1);
    expect(upsert).toHaveBeenLastCalledWith(expect.objectContaining({ update: {} }));
    expect(auditUpsert.mock.calls[0]![0]).toEqual(auditUpsert.mock.calls[1]![0]);
    expect(auditUpsert.mock.calls[0]![0].update).toEqual({});
    await expect(service.create(actor, { ...input, title: 'Different synthetic alert' })).rejects.toThrow('different incident');
    expect(auditUpsert).toHaveBeenCalledTimes(2);
    await service.create({ ...actor, accountId: 'another-synthetic-it' }, input);
    expect(rows.size).toBe(2);
  });
  it('rejects malformed retry identifiers', () => {
    expect(incidentCreate.safeParse({ requestId: 'bad/key', title: 'Synthetic alert', description: 'Synthetic investigation', priority: 'HIGH' }).success).toBe(false);
  });
  it('filters the register and count while keeping summary counts global', async () => {
    const base = fixture().tx;
    const tx = { ...base, securityIncident: { ...base.securityIncident,
      findMany: vi.fn().mockResolvedValue([]), count: vi.fn().mockResolvedValue(0),
    } };
    const service = new SecurityIncidentsService({ $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient);
    await service.list(actor, { page: '2', status: 'INVESTIGATING', priority: 'HIGH' });
    expect(tx.securityIncident.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { status: 'INVESTIGATING', priority: 'HIGH' }, skip: 20, take: 20,
    }));
    expect(tx.securityIncident.count).toHaveBeenNthCalledWith(1, { where: { status: 'INVESTIGATING', priority: 'HIGH' } });
    expect(tx.securityIncident.count).toHaveBeenNthCalledWith(2, { where: { status: { not: 'RESOLVED' } } });
  });
  it('rejects invalid filters and pagination', () => {
    for (const query of [{ status: 'UNKNOWN' }, { priority: 'CRITICAL' }, { page: 0 }, { page: 1.5 }, { ownerId: 'other' }]) {
      expect(incidentQuery.safeParse(query).success).toBe(false);
    }
    expect(incidentQuery.parse({})).toEqual({ page: 1 });
  });
  it.each(['SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT'])('denies %s', async role => {
    const { service, tx } = fixture(role);
    await expect(service.create(actor, { title: 'Synthetic alert', description: 'Synthetic investigation', priority: 'HIGH' })).rejects.toThrow('restricted');
    expect(tx.securityIncident.create).not.toHaveBeenCalled();
  });
  it('denies disabled IT accounts', async () => {
    await expect(fixture('IT_SECURITY', 'DISABLED').service.list(actor, {})).rejects.toThrow('restricted');
  });
  it('validates content and prohibits injected owner or invalid status', () => {
    expect(incidentCreate.safeParse({ title: 'x', description: 'short', priority: 'HIGH' }).success).toBe(false);
    expect(incidentCreate.safeParse({ title: 'Synthetic alert', description: 'Synthetic investigation', priority: 'HIGH', ownerId: 'other' }).success).toBe(false);
    expect(incidentUpdate.safeParse({ revision: 1, status: 'RESOLVED', note: '' }).success).toBe(false);
  });
  it('records ownership and creation history without copying description to audit', async () => {
    const { service, tx } = fixture();
    await service.create(actor, { title: 'Synthetic alert', description: 'Synthetic investigation', priority: 'HIGH' });
    expect(tx.securityIncident.create.mock.calls[0]![0].data.ownerId).toBe(actor.accountId);
    expect(tx.platformAuditEvent.create.mock.calls[0]![0].data.metadata).toBeUndefined();
  });
  it('rejects stale revision without appending history', async () => {
    const { service, tx } = fixture();
    tx.securityIncident.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.update(actor, 'synthetic-incident', { revision: 1, status: 'RESOLVED', note: 'Synthetic resolution' })).rejects.toThrow('Reload');
    expect(tx.securityIncidentEntry.create).not.toHaveBeenCalled();
  });
  it('appends a resolution note with the actor and increments revision', async () => {
    const { service, tx } = fixture();
    await service.update(actor, 'synthetic-incident', { revision: 1, status: 'RESOLVED', note: 'Synthetic resolution' });
    expect(tx.securityIncident.updateMany.mock.calls[0]![0].data.revision).toEqual({ increment: 1 });
    expect(tx.securityIncidentEntry.create.mock.calls[0]![0].data.actorId).toBe(actor.accountId);
  });
});
