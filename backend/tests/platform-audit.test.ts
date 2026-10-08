import { describe, expect, it, vi } from "vitest";
import type { PrismaClient } from "@prisma/client";
import { PlatformGovernanceService, safePlatformAuditMetadata, officeHistoryActions } from "../src/modules/platform/platform.service";
import { platformAuditQuerySchema } from "../src/modules/platform/platform.schemas";

describe("platform audit filters and privacy", () => {
  it('always applies the office allowlist for Super Admin, including unfiltered requests', async () => {
    const tx = {
      platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'office', role: 'SUPER_ADMIN', status: 'ACTIVE' }) },
      platformAuditEvent: { findMany: vi.fn().mockResolvedValue([]) },
    };
    const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
    const service = new PlatformGovernanceService(db);
    const actor = { scope: 'platform' as const, accountId: 'office', sessionId: 'session' };
    await service.listAuditEvents(actor);
    expect(tx.platformAuditEvent.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { action: { in: officeHistoryActions } } }));
    expect(officeHistoryActions).not.toContain('platform.login.failed');
    expect(officeHistoryActions).not.toContain('tenant.school.provisioned');
    expect(officeHistoryActions).not.toContain('platform.session.revoked');
    for (const query of [{ actorId: 'it' }, { actorRole: 'IT_SECURITY' }, { action: 'platform.login.failed' }, { action: 'future.technical.event' }]) {
      tx.platformAuditEvent.findMany.mockClear();
      await expect(service.listAuditEvents(actor, query)).rejects.toMatchObject({ statusCode: 403 });
      expect(tx.platformAuditEvent.findMany).not.toHaveBeenCalled();
    }
  });
  it.each(['', 'a'.repeat(31), ['application'], { id: 'application' }])('rejects invalid application scope', (applicationId) => {
    expect(() => platformAuditQuerySchema.parse({ applicationId })).toThrow();
  });
  it.each(['SUPER_ADMIN', 'IT_SECURITY'])('scopes %s history to one application without exposing invitation or activation evidence', async (role) => {
    const tx = {
      platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'operator', role, status: 'ACTIVE' }) },
      platformAuditEvent: { findMany: vi.fn().mockResolvedValue([{ id: 'event', metadata: {
        status: 'PENDING_ACTIVATION', token: 'secret', tokenHash: 'private', email: 'private@example.test',
        evidenceReference: 'private-review-record', operatorAttestations: { tenantIsolation: true },
      } }]) },
    };
    const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
    const result = await new PlatformGovernanceService(db).listAuditEvents({ scope: 'platform', accountId: 'operator', sessionId: 'session' }, {
      applicationId: 'application', action: 'tenant.application.approved', page: 2, pageSize: 10,
    });
    expect(tx.platformAuditEvent.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { entityType: 'TenantApplication', entityId: 'application', action: 'tenant.application.approved' }, skip: 10, take: 10,
    }));
    expect(result[0]?.metadata).toEqual({ status: 'PENDING_ACTIVATION' });
  });
  it.each([{ actorRole: "ADMIN" }, { from: "yesterday" }, { from: "2026-10-08T00:00:00Z", to: "2026-10-01T00:00:00Z" }, { pageSize: 101 }, { search: "secret" }])("rejects invalid query %j", (query) => {
    expect(() => platformAuditQuerySchema.parse(query)).toThrow();
  });
  it("only exposes whitelisted operational metadata", () => {
    expect(safePlatformAuditMetadata({ status: "APPROVED", previousStatus: "REQUESTED", count: 2,
      password: "secret", token: "private", email: "private@example.test", nested: { secret: true } }))
      .toEqual({ status: "APPROVED", previousStatus: "REQUESTED", count: 2 });
    expect(safePlatformAuditMetadata({ status: "secret", count: -1 })).toEqual({});
    expect(safePlatformAuditMetadata(null)).toEqual({});
  });
  it("applies exact filters, bounds pagination and redacts returned metadata", async () => {
    const tx = {
      platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: "it", role: "IT_SECURITY", status: "ACTIVE" }) },
      platformAuditEvent: { findMany: vi.fn().mockResolvedValue([{ id: "event", metadata: { count: 1, password: "secret" } }]) },
    };
    const db = { $transaction: async (run: (tx: unknown) => unknown) => run(tx) } as unknown as PrismaClient;
    const result = await new PlatformGovernanceService(db).listAuditEvents({ scope: "platform", accountId: "it", sessionId: "session" }, {
      page: 2, pageSize: 10, action: "platform.login.failed", actorRole: "SUPER_ADMIN", actorId: "target",
      from: "2026-10-01T00:00:00Z", to: "2026-10-08T00:00:00Z",
    });
    expect(tx.platformAuditEvent.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { action: "platform.login.failed", actorRole: "SUPER_ADMIN", actorId: "target", createdAt: { gte: new Date("2026-10-01T00:00:00Z"), lte: new Date("2026-10-08T00:00:00Z") } }, skip: 10, take: 10,
    }));
    expect(result[0]?.metadata).toEqual({ count: 1 });
  });
});
