import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { BackupRequestsService, restoreRequest } from '../src/modules/platform/platform.backups';

const actor = { scope: 'platform' as const, accountId: 'synthetic-it', sessionId: 'synthetic-session' };
const input = { requestId: 'synthetic-request-0001', snapshot: 'BKP-SYNTHETIC', reason: 'Test isolated recovery' };
function setup(role = 'IT_SECURITY', status = 'ACTIVE') {
  let record: any;
  const upsert = vi.fn(async ({ create }: any) => record ??= create);
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) },
    platformAuditEvent: { upsert, findMany: vi.fn().mockResolvedValue([]), count: vi.fn().mockResolvedValue(0) },
    $transaction: (queries: Promise<unknown>[]) => Promise.all(queries) };
  return { service: new BackupRequestsService(db as unknown as PrismaClient), upsert };
}
describe('Restore test requests', () => {
  it.each(['SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT', 'TEACHER'])('denies %s', async role => {
    const { service, upsert } = setup(role);
    await expect(service.request(actor, input)).rejects.toThrow('restricted');
    expect(upsert).not.toHaveBeenCalled();
  });
  it('denies disabled IT readers', async () => {
    await expect(setup('IT_SECURITY', 'DISABLED').service.list(actor, {})).rejects.toThrow('restricted');
  });
  it('records requests idempotently without claiming execution', async () => {
    const { service, upsert } = setup();
    const first = await service.request(actor, input);
    const second = await service.request(actor, input);
    expect(first.id).toBe(second.id);
    expect(first.metadata).toMatchObject({ status: 'REQUESTED', environment: 'ISOLATED_TEST' });
    expect(upsert.mock.calls[0]![0].update).toEqual({});
    await expect(service.request(actor, { ...input, reason: 'Different scope of recovery' })).rejects.toThrow('different details');
  });
  it('lists persistent requests with explicit execution limitation', async () => {
    expect(await setup().service.list(actor, {})).toMatchObject({ items: [], total: 0, executionConnected: false });
  });
  it('rejects injected status and insufficient scope', () => {
    expect(restoreRequest.safeParse({ ...input, status: 'VERIFIED' }).success).toBe(false);
    expect(restoreRequest.safeParse({ ...input, reason: ' ' }).success).toBe(false);
  });
});
