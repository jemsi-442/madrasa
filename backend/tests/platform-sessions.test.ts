import { describe, expect, it, vi } from "vitest";
import type { PrismaClient } from "@prisma/client";
import { PlatformGovernanceService } from "../src/modules/platform/platform.service";

const id = "c222bd7e-bdbd-4698-b666-67b6b5e2d658";
const actor = { scope: "platform" as const, accountId: "operator", sessionId: id };
function fixture() {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, role: "IT_SECURITY", status: "ACTIVE" }) },
    platformSession: {
      findMany: vi.fn().mockResolvedValue([{ id, createdAt: new Date(), expiresAt: new Date(), mfaVerifiedAt: new Date() }]),
      findFirst: vi.fn().mockResolvedValue({ id }), updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}) },
  };
  const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformGovernanceService(db) };
}
describe("self-service platform sessions", () => {
  it("only lists own active sessions with minimal fields", async () => {
    const f = fixture();
    expect((await f.service.listOwnSessions(actor))[0]?.current).toBe(true);
    expect(f.tx.platformSession.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ accountId: actor.accountId, role: "IT_SECURITY", revokedAt: null, expiresAt: { gt: expect.any(Date) } }),
      select: { id: true, createdAt: true, expiresAt: true, mfaVerifiedAt: true }, take: 25, skip: 0,
    }));
  });
  it("does not permit another account's session to be revoked", async () => {
    const f = fixture();
    f.tx.platformSession.findFirst.mockResolvedValue(null);
    await expect(f.service.revokeOwnSession(actor, id)).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.platformSession.findFirst).toHaveBeenCalledWith({ where: { id, accountId: actor.accountId }, select: { id: true } });
    expect(f.tx.platformSession.updateMany).not.toHaveBeenCalled();
  });
  it("revokes an owned session and audits in the same transaction", async () => {
    const f = fixture();
    expect(await f.service.revokeOwnSession(actor, id)).toEqual({ revoked: 1, current: true });
    expect(f.tx.platformSession.updateMany).toHaveBeenCalledWith({ where: { id, accountId: actor.accountId, revokedAt: null }, data: { revokedAt: expect.any(Date) } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ entityType: "PlatformSession", entityId: id, action: "platform.session.revoked" }) });
  });
  it("does not duplicate audit records when already revoked", async () => {
    const f = fixture();
    f.tx.platformSession.updateMany.mockResolvedValue({ count: 0 });
    expect((await f.service.revokeOwnSession(actor, id)).revoked).toBe(0);
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it("validates IDs and refuses account selection via query", async () => {
    const f = fixture();
    await expect(f.service.revokeOwnSession(actor, "not-a-uuid")).rejects.toThrow();
    await expect(f.service.listOwnSessions(actor, { accountId: "someone-else" })).rejects.toThrow();
    expect(f.tx.platformSession.findMany).not.toHaveBeenCalled();
  });
  it("fails the mutation if its audit fails", async () => {
    const f = fixture();
    f.tx.platformAuditEvent.create.mockRejectedValue(new Error("audit unavailable"));
    await expect(f.service.revokeOwnSession(actor, id)).rejects.toThrow("audit unavailable");
  });
});
