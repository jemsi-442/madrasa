import type { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { hasPlatformPermission, platformPermissions } from "../src/modules/platform/platform.permissions";
import { verifyPlatformAccess, PLATFORM_AUDIENCE, PLATFORM_ISSUER } from "../src/modules/platform/platform.authentication";
import { tenantApplicationSchema } from "../src/modules/platform/platform.schemas";
import { PlatformGovernanceService, type PlatformContext } from "../src/modules/platform/platform.service";

const actor: PlatformContext = { scope: "platform", accountId: "reviewer", sessionId: "c222bd7e-bdbd-4698-b666-67b6b5e2d658" };
const input = { schoolName: "Afaq School", requestedCode: "afaq-school", adminEmail: "admin@example.test" };
const decision = { decision: "APPROVED", reason: "School ownership verified" };
const secret = "test-platform-secret-not-for-use-in-production";

function fixture() {
  const tx = {
    platformSession: { findUnique: vi.fn().mockResolvedValue({
      id: actor.sessionId, accountId: actor.accountId, role: "SUPER_ADMIN", revokedAt: null,
      createdAt: new Date(Math.floor(Date.now() / 1000) * 1000), mfaVerifiedAt: new Date(), expiresAt: new Date(Date.now() + 900_000),
    }), updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, role: "SUPER_ADMIN", status: "ACTIVE" }) },
    organization: { findUnique: vi.fn().mockResolvedValue(null) },
    tenantApplication: {
      create: vi.fn().mockResolvedValue({ id: "application", ...input, status: "REQUESTED" }),
      findUnique: vi.fn().mockResolvedValue({ id: "application", ...input, status: "REQUESTED", requestedById: "requester" }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findUniqueOrThrow: vi.fn().mockResolvedValue({ id: "application", status: "APPROVED" }),
      findMany: vi.fn().mockResolvedValue([]),
    },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}), findMany: vi.fn().mockResolvedValue([]) },
  };
  const db = { ...tx, $transaction: vi.fn(async (run: (client: typeof tx) => unknown) => run(tx)) };
  const client = db as unknown as PrismaClient;
  return { tx, db, client, service: new PlatformGovernanceService(client) };
}

describe("platform governance foundation", () => {
  let f: ReturnType<typeof fixture>;
  beforeEach(() => { f = fixture(); });

  it.each(["ADMIN", "ACCOUNTANT", "TEACHER", "PARENT", "LEARNER", "UNKNOWN", "constructor", "toString"])("denies school/unknown role %s", (role) => {
    for (const permission of platformPermissions) expect(hasPlatformPermission(role, permission)).toBe(false);
  });

  it("limits IT to platform operational reads", () => {
    expect(hasPlatformPermission("IT_SECURITY", "platform.audit.read")).toBe(true);
    expect(hasPlatformPermission("IT_SECURITY", "platform.health.read")).toBe(true);
    expect(hasPlatformPermission("IT_SECURITY", "tenant.application.create")).toBe(false);
    expect(hasPlatformPermission("IT_SECURITY", "tenant.application.review")).toBe(false);
    expect(hasPlatformPermission("IT_SECURITY", "tenant.application.read")).toBe(false);
  });

  it("normalizes school identifiers and rejects privilege injection", () => {
    expect(tenantApplicationSchema.parse({ ...input, requestedCode: " AFAQ-SCHOOL ", adminEmail: " ADMIN@EXAMPLE.TEST " }))
      .toEqual(input);
    expect(() => tenantApplicationSchema.parse({ ...input, status: "APPROVED" })).toThrow();
    expect(() => tenantApplicationSchema.parse({ ...input, requestedCode: "../school" })).toThrow();
  });

  it("creates a request and audit in the same transaction without activating a school", async () => {
    await f.service.createApplication(actor, input);
    expect(f.db.$transaction).toHaveBeenCalledTimes(1);
    expect(f.tx.tenantApplication.create).toHaveBeenCalledWith({ data: { ...input, requestedById: actor.accountId } });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: "tenant.application.requested", metadata: { status: "REQUESTED" } }) });
  });

  it("fails the mutation when its audit write fails", async () => {
    f.tx.platformAuditEvent.create.mockRejectedValue(new Error("audit unavailable"));
    await expect(f.service.createApplication(actor, input)).rejects.toThrow("audit unavailable");
    // Actual database rollback is Prisma's responsibility; this unit test checks propagation.
  });

  it("rejects duplicate existing school codes", async () => {
    f.tx.organization.findUnique.mockResolvedValue({ id: 1n });
    await expect(f.service.createApplication(actor, input)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.tenantApplication.create).not.toHaveBeenCalled();
  });

  it.each(["DISABLED", "MISSING"])("rejects %s platform accounts", async (status) => {
    f.tx.platformAccount.findUnique.mockResolvedValue(status === "MISSING" ? null : { id: "reviewer", role: "SUPER_ADMIN", status });
    await expect(f.service.createApplication(actor, input)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.create).not.toHaveBeenCalled();
  });

  it("does not trust caller-supplied school scope", async () => {
    await expect(f.service.listApplications({ scope: "tenant", accountId: "reviewer" } as unknown as PlatformContext))
      .rejects.toMatchObject({ statusCode: 401 });
    expect(f.tx.platformAccount.findUnique).not.toHaveBeenCalled();
  });

  it("IT cannot create, review or read school applications", async () => {
    f.tx.platformAccount.findUnique.mockResolvedValue({ id: "it", role: "IT_SECURITY", status: "ACTIVE" });
    await expect(f.service.createApplication(actor, input)).rejects.toMatchObject({ statusCode: 403 });
    await expect(f.service.reviewApplication(actor, "application", decision)).rejects.toMatchObject({ statusCode: 403 });
    await expect(f.service.listApplications(actor)).rejects.toMatchObject({ statusCode: 403 });
    await expect(f.service.listAuditEvents(actor)).resolves.toEqual([]);
    expect(f.tx.tenantApplication.updateMany).not.toHaveBeenCalled();
  });

  it("requires a second Super Admin to review", async () => {
    f.tx.tenantApplication.findUnique.mockResolvedValue({ ...input, id: "application", status: "REQUESTED", requestedById: actor.accountId });
    await expect(f.service.reviewApplication(actor, "application", decision)).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.updateMany).not.toHaveBeenCalled();
  });

  it.each(["APPROVED", "REJECTED"])("records a %s decision with a conditional update", async (status) => {
    await f.service.reviewApplication(actor, "application", { ...decision, decision: status });
    expect(f.tx.tenantApplication.updateMany).toHaveBeenCalledWith({
      where: { id: "application", status: "REQUESTED" },
      data: expect.objectContaining({ status, reviewedById: actor.accountId, decisionReason: decision.reason }),
    });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledTimes(1);
  });

  it.each(["APPROVED", "REJECTED"])("cannot overwrite a %s application", async (status) => {
    f.tx.tenantApplication.findUnique.mockResolvedValue({ ...input, id: "application", status, requestedById: "requester" });
    await expect(f.service.reviewApplication(actor, "application", decision)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.tenantApplication.updateMany).not.toHaveBeenCalled();
  });

  it("rejects a concurrent decision without appending a success audit", async () => {
    f.tx.tenantApplication.updateMany.mockResolvedValue({ count: 0 });
    await expect(f.service.reviewApplication(actor, "application", decision)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.platformAuditEvent.create).not.toHaveBeenCalled();
  });

  it("bounds and orders listings", async () => {
    await f.service.listApplications(actor, { page: 2, pageSize: 10 });
    expect(f.tx.tenantApplication.findMany).toHaveBeenCalledWith({ where: {}, orderBy: [{ createdAt: "desc" }, { id: "desc" }], skip: 10, take: 10 });
    await expect(f.service.listAuditEvents(actor, { pageSize: 1000 })).rejects.toThrow();
  });

  function token(payload: Record<string, unknown> = {}, signingKey = secret) {
    const now = Math.floor(Date.now() / 1000);
    const claims = Object.fromEntries(Object.entries({ sub: "reviewer", sid: actor.sessionId, role: "SUPER_ADMIN", type: "platform_access", iat: now, exp: now + 900, ...payload })
      .filter(([, value]) => value !== undefined));
    return jwt.sign(claims, signingKey,
      { algorithm: "HS256", issuer: PLATFORM_ISSUER, audience: PLATFORM_AUDIENCE });
  }

  it("verifies a distinct platform token and resolves role from the database", async () => {
    await expect(verifyPlatformAccess(f.client, token(), secret)).resolves.toEqual(actor);
  });

  it.each([
    { type: "access" }, { role: "ADMIN" }, { exp: 1 }, { exp: undefined },
    { iat: Math.floor(Date.now() / 1000) + 60 }, { exp: Math.floor(Date.now() / 1000) + 3600 },
  ])("rejects malformed, school or expired claims %j", async (payload) => {
    await expect(verifyPlatformAccess(f.client, token(payload), secret)).rejects.toMatchObject({ statusCode: 401 });
    expect(f.tx.platformAccount.findUnique).not.toHaveBeenCalled();
  });

  it("rejects wrong signing key and audience", async () => {
    await expect(verifyPlatformAccess(f.client, token({}, "another-signing-secret"), secret)).rejects.toMatchObject({ statusCode: 401 });
    const wrongAudience = jwt.sign({ type: "platform_access", sub: "reviewer", role: "SUPER_ADMIN" }, secret, { audience: "school", issuer: PLATFORM_ISSUER, expiresIn: 900 });
    await expect(verifyPlatformAccess(f.client, wrongAudience, secret)).rejects.toMatchObject({ statusCode: 401 });
  });

  it("fails closed for unconfigured signing keys", async () => {
    await expect(verifyPlatformAccess(f.client, token(), "")).rejects.toMatchObject({ statusCode: 503 });
    expect(f.tx.platformAccount.findUnique).not.toHaveBeenCalled();
  });

  it("returns not found without writing when an application is missing", async () => {
    f.tx.tenantApplication.findUnique.mockResolvedValue(null);
    await expect(f.service.reviewApplication(actor, "missing", decision)).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.tenantApplication.updateMany).not.toHaveBeenCalled();
  });

  it("rechecks code availability at approval", async () => {
    f.tx.organization.findUnique.mockResolvedValue({ id: 1n });
    await expect(f.service.reviewApplication(actor, "application", decision)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.tx.tenantApplication.updateMany).not.toHaveBeenCalled();
  });

  it("rejects role changes and disabled accounts even with a valid token", async () => {
    f.tx.platformAccount.findUnique.mockResolvedValue({ id: "reviewer", role: "IT_SECURITY", status: "ACTIVE" });
    await expect(verifyPlatformAccess(f.client, token(), secret)).rejects.toMatchObject({ statusCode: 401 });
    f.tx.platformAccount.findUnique.mockResolvedValue({ id: "reviewer", role: "SUPER_ADMIN", status: "DISABLED" });
    await expect(verifyPlatformAccess(f.client, token(), secret)).rejects.toMatchObject({ statusCode: 401 });
  });

  it("rejects deleted sessions", async () => {
    f.tx.platformSession.findUnique.mockResolvedValue(null);
    await expect(verifyPlatformAccess(f.client, token(), secret)).rejects.toMatchObject({ statusCode: 401 });
  });

  it.each([
    { revokedAt: new Date() }, { accountId: "another-account" }, { role: "IT_SECURITY" },
    { expiresAt: new Date(0) }, { mfaVerifiedAt: new Date(0) },
    { mfaVerifiedAt: new Date(Date.now() + 60_000) }, { createdAt: new Date(0) },
  ])("rejects invalid session state %j", async (overrides) => {
    const session = await f.tx.platformSession.findUnique();
    f.tx.platformSession.findUnique.mockResolvedValue({ ...session, ...overrides });
    await expect(verifyPlatformAccess(f.client, token(), secret)).rejects.toMatchObject({ statusCode: 401 });
  });

  it.each([false, true])("revokes own sessions only (all=%s), with an audit record", async (all) => {
    await f.service.logout(actor, all);
    expect(f.tx.platformSession.updateMany).toHaveBeenCalledWith({
      where: { accountId: actor.accountId, ...(all ? {} : { id: actor.sessionId }), revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
    expect(f.tx.platformAuditEvent.create).toHaveBeenCalledTimes(1);
  });
});
