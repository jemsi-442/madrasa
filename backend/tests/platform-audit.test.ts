import { describe, expect, it, vi } from "vitest";
import type { PrismaClient } from "@prisma/client";
import { PlatformGovernanceService, safePlatformAuditMetadata } from "../src/modules/platform/platform.service";
import { platformAuditQuerySchema } from "../src/modules/platform/platform.schemas";

describe("platform audit filters and privacy", () => {
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
