import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';

const actor = { scope: 'platform' as const, accountId: 'reviewer', sessionId: 'session' };
const input = { reason: 'Suspension reviewed and resolved', suspensionEventId: 'suspension' };
function fixture() {
  const tx = {
    platformAccount: {
      findUnique: vi.fn().mockResolvedValueOnce({ id: 'reviewer', role: 'SUPER_ADMIN', status: 'ACTIVE' })
        .mockResolvedValue({ id: 'it', role: 'IT_SECURITY', status: 'DISABLED', mfaSecretEncrypted: 'encrypted' }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    platformSession: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
    platformAuditEvent: {
      findFirst: vi.fn().mockResolvedValue({ id: 'suspension', actorId: 'other-admin', action: 'platform.account.disabled' }),
      create: vi.fn().mockResolvedValue({}),
    },
  };
  const transaction = vi.fn(async (run: (tx: unknown) => unknown) => run(tx));
  const db = { $transaction: transaction } as unknown as PrismaClient;
  return { tx, transaction, service: new PlatformGovernanceService(db) };
}
describe('independent IT restoration', () => {
  it('rejects an approval for an older suspension event', async () => {
    const f = fixture();
    await expect(f.service.restoreItAccount(actor, 'it', { ...input, suspensionEventId: 'older-event' })).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('requires the reviewed event reference', async () => {
    const f = fixture();
    await expect(f.service.restoreItAccount(actor, 'it', { reason: input.reason })).rejects.toThrow();
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('restores only disabled IT, retains credentials and revokes leftover sessions atomically', async () => {
    const f = fixture();
    expect(await f.service.restoreItAccount(actor, 'it', input)).toEqual({ id: 'it', status: 'ACTIVE', revoked: 0 });
    expect(f.transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'Serializable' });
    expect(f.tx.platformAccount.updateMany).toHaveBeenCalledWith({ where: { id: 'it', role: 'IT_SECURITY', status: 'DISABLED', mfaSecretEncrypted: 'encrypted' }, data: { status: 'ACTIVE' } });
    expect(f.tx.platformSession.updateMany).toHaveBeenCalledWith({ where: { accountId: 'it', revokedAt: null }, data: { revokedAt: expect.any(Date) } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: 'platform.account.restored', metadata: expect.objectContaining({ suspensionEventId: 'suspension', reason: input.reason }) }) });
  });
  it('requires a different reviewer from the suspending admin', async () => {
    const f = fixture();
    f.tx.platformAuditEvent.findFirst.mockResolvedValue({ id: 'event', actorId: 'reviewer', action: 'platform.account.disabled' });
    await expect(f.service.restoreItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it.each([null, { id: 'event', actorId: 'other-admin', action: 'platform.account.restored' }])('rejects missing or superseded suspension %j', async (event) => {
    const f = fixture(); f.tx.platformAuditEvent.findFirst.mockResolvedValue(event);
    await expect(f.service.restoreItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it.each([
    { role: 'SUPER_ADMIN', status: 'DISABLED', mfaSecretEncrypted: 'encrypted' },
    { role: 'IT_SECURITY', status: 'ACTIVE', mfaSecretEncrypted: 'encrypted' },
    { role: 'IT_SECURITY', status: 'DISABLED', mfaSecretEncrypted: null },
  ])('rejects ineligible target %j', async (target) => {
    const f = fixture(); f.tx.platformAccount.findUnique.mockResolvedValue({ id: 'it', ...target });
    await expect(f.service.restoreItAccount(actor, 'it', input)).rejects.toThrow();
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('denies IT reviewers', async () => {
    const f = fixture(); f.tx.platformAccount.findUnique.mockReset().mockResolvedValue({ id: 'it', role: 'IT_SECURITY', status: 'ACTIVE' });
    await expect(f.service.restoreItAccount(actor, 'other', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('rejects concurrent losing updates without audit', async () => {
    const f = fixture(); f.tx.platformAccount.updateMany.mockResolvedValue({ count: 0 });
    await expect(f.service.restoreItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('propagates audit errors for transaction rollback', async () => {
    const f = fixture(); f.tx.platformAuditEvent.create.mockRejectedValue(new Error('audit failure'));
    await expect(f.service.restoreItAccount(actor, 'it', input)).rejects.toThrow('audit failure');
  });
});
