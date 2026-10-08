import type { PrismaClient } from "@prisma/client";
import { describe, expect, it, vi } from "vitest";
import { PlatformGovernanceService } from "../src/modules/platform/platform.service";

const actor = { scope: "platform" as const, accountId: "admin", sessionId: "session" };
const input = { reason: "Operator access no longer required" };
function fixture(role = "SUPER_ADMIN", targetRole = "IT_SECURITY", status = "ACTIVE") {
  const tx = {
    platformAccount: {
      findUnique: vi.fn().mockResolvedValueOnce({ id: 'admin', role, status: 'ACTIVE' }).mockResolvedValue({ id: 'it', role: targetRole, status }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    platformSession: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}) },
  };
  const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformGovernanceService(db) };
}
describe('disable IT platform accounts', () => {
  it('conditionally disables IT, revokes only its sessions and records audit', async () => {
    const f = fixture();
    expect(await f.service.disableItAccount(actor, 'it', input)).toEqual({ id: 'it', status: 'DISABLED', revoked: 2 });
    expect(f.tx.platformAccount.updateMany).toHaveBeenCalledWith({ where: { id: 'it', role: 'IT_SECURITY', status: 'ACTIVE' }, data: { status: 'DISABLED' } });
    expect(f.tx.platformSession.updateMany).toHaveBeenCalledWith({ where: { accountId: 'it', revokedAt: null }, data: { revokedAt: expect.any(Date) } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ actorId: 'admin', action: 'platform.account.disabled', entityId: 'it', metadata: { previousStatus: 'ACTIVE', status: 'DISABLED', count: 2, reason: input.reason } }) });
  });
  it.each(['IT_SECURITY', 'ADMIN', 'UNKNOWN'])('denies actor %s', async (role) => {
    const f = fixture(role);
    await expect(f.service.disableItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it.each(['SUPER_ADMIN', 'ADMIN'])('protects target role %s', async (role) => {
    const f = fixture('SUPER_ADMIN', role);
    await expect(f.service.disableItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformSession.updateMany).not.toHaveBeenCalled();
  });
  it('prevents self-disable', async () => {
    const f = fixture();
    await expect(f.service.disableItAccount(actor, 'admin', input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('does not mutate an already disabled target', async () => {
    const f = fixture('SUPER_ADMIN', 'IT_SECURITY', 'DISABLED');
    await expect(f.service.disableItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('does not audit a losing concurrent update', async () => {
    const f = fixture(); f.tx.platformAccount.updateMany.mockResolvedValue({ count: 0 });
    await expect(f.service.disableItAccount(actor, 'it', input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformSession.updateMany).not.toHaveBeenCalled();
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('rejects injected fields and short reasons', async () => {
    const f = fixture();
    await expect(f.service.disableItAccount(actor, 'it', { reason: 'short' })).rejects.toThrow();
    await expect(f.service.disableItAccount(actor, 'it', { ...input, role: 'SUPER_ADMIN' })).rejects.toThrow();
    expect(f.tx.platformAccount.updateMany).not.toHaveBeenCalled();
  });
  it('propagates audit failure', async () => {
    const f = fixture(); f.tx.platformAuditEvent.create.mockRejectedValue(new Error('audit unavailable'));
    await expect(f.service.disableItAccount(actor, 'it', input)).rejects.toThrow('audit unavailable');
  });
});
