import type { PrismaClient } from "@prisma/client";
import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import { createPlatformRouter } from "../src/modules/platform/platform.routes";
import { PLATFORM_AUDIENCE, PLATFORM_ISSUER } from "../src/modules/platform/platform.authentication";
import { errorHandler } from "../src/shared/middleware/error-handler";
import { authenticate } from "../src/shared/middleware/authenticate";

vi.mock("../src/config/env", () => ({ env: { JWT_SECRET: "school-test-key-not-used-in-production" } }));
const key = "platform-test-key-not-used-in-production";
const schoolKey = "school-test-key-not-used-in-production";
const sid = "c222bd7e-bdbd-4698-b666-67b6b5e2d658";

function fixture(role = "SUPER_ADMIN", secret = key) {
  const now = Math.floor(Date.now() / 1000);
  const account = { id: "operator", fullName: "Platform Operator", role, status: "ACTIVE" };
  const session = { id: sid, accountId: account.id, role, revokedAt: null as Date | null,
    createdAt: new Date(now * 1000), mfaVerifiedAt: new Date(now * 1000), expiresAt: new Date((now + 900) * 1000) };
  const db = {
    platformAccount: { findMany: vi.fn().mockResolvedValue([]), findUnique: vi.fn().mockResolvedValue(account), findUniqueOrThrow: vi.fn().mockResolvedValue({ id: account.id, fullName: account.fullName, role }) },
    platformSession: { findFirst: vi.fn().mockResolvedValue({ id: sid }), findMany: vi.fn().mockResolvedValue([]), findUnique: vi.fn().mockImplementation(async () => session), updateMany: vi.fn().mockImplementation(async () => {
      session.revokedAt = new Date(); return { count: 1 };
    }) },
    tenantApplication: { findFirst: vi.fn().mockResolvedValue(null), findMany: vi.fn().mockResolvedValue([]), create: vi.fn().mockResolvedValue({ id: "application", status: "REQUESTED" }) },
    organization: { findUnique: vi.fn().mockResolvedValue(null) },
    platformAuditEvent: { findMany: vi.fn().mockResolvedValue([]), create: vi.fn().mockResolvedValue({}) },
    $transaction: vi.fn(),
  };
  db.$transaction.mockImplementation(async (run) => run(db));
  const app = express();
  app.use(express.json());
  const health = vi.fn().mockResolvedValue({ status: "healthy", checkedAt: new Date().toISOString(), checks: [] });
  app.use("/api/platform", createPlatformRouter(db as unknown as PrismaClient, secret, [schoolKey], undefined, health));
  app.get("/school", authenticate, (_req, res) => res.json({ success: true }));
  app.use(errorHandler);
  const claims = { sub: account.id, sid, type: "platform_access", role, iat: now, exp: now + 900 };
  const token = jwt.sign(claims, key, { audience: PLATFORM_AUDIENCE, issuer: PLATFORM_ISSUER });
  return { app, db, session, token, claims, health };
}

describe("platform HTTP boundary", () => {
  it.each(['SUPER_ADMIN', 'IT_SECURITY'])('provides sanitized onboarding progress to %s', async (role) => {
    const f = fixture(role);
    const url = '/api/platform/tenant-applications/application/onboarding-progress';
    expect((await request(f.app).get(url)).status).toBe(401);
    expect((await request(f.app).get(url).set('Authorization', `Bearer ${f.token}`)).status).toBe(404);
    f.db.tenantApplication.findFirst.mockResolvedValue({ id: 'application', schoolName: 'School', requestedCode: 'school',
      adminEmail: 'private@example.test', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date(),
      organization: null, adminInvitation: null });
    const response = await request(f.app).get(url).set('Authorization', `Bearer ${f.token}`);
    expect(response.status).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.body.data.stage).toBe('PROVISIONING_PENDING');
    expect(JSON.stringify(response.body)).not.toContain('private@example.test');
    if (role === 'SUPER_ADMIN') {
      expect(response.body.data.activationReview).toMatchObject({ prerequisitesPassed: false, activationEnabled: false });
    } else {
      expect(response.body.data).not.toHaveProperty('activationReview');
    }
    expect(f.db.platformAuditEvent.create).not.toHaveBeenCalled();
    expect(f.db.tenantApplication.create).not.toHaveBeenCalled();
  });
  it('serves the approved-only IT queue without granting access to the application directory', async () => {
    const operator = fixture('IT_SECURITY');
    const url = '/api/platform/provisioning-queue';
    expect((await request(operator.app).get(url)).status).toBe(401);
    const response = await request(operator.app).get(url).set('Authorization', `Bearer ${operator.token}`);
    expect(response.status).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(operator.db.tenantApplication.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { status: 'APPROVED' } }));
    expect((await request(operator.app).get('/api/platform/tenant-applications').set('Authorization', `Bearer ${operator.token}`)).status).toBe(403);
    const admin = fixture();
    expect((await request(admin.app).get(url).set('Authorization', `Bearer ${admin.token}`)).status).toBe(403);
  });
  it('keeps provisioning execution separate from approval and rejects caller-selected school fields', async () => {
    const admin = fixture();
    const url = '/api/platform/tenant-applications/application/provision';
    expect((await request(admin.app).post(url).send({})).status).toBe(401);
    expect((await request(admin.app).post(url).set('Authorization', `Bearer ${admin.token}`).send({})).status).toBe(403);
    const operator = fixture('IT_SECURITY');
    expect((await request(operator.app).post(url).set('Authorization', `Bearer ${operator.token}`).send({ status: 'ACTIVE', organizationId: '1' })).status).toBe(422);
  });
  it.each(['SUPER_ADMIN', 'IT_SECURITY'])('allows %s to inspect only approved provisioning handoffs', async (role) => {
    const f = fixture(role);
    const url = '/api/platform/tenant-applications/application/provisioning-preflight';
    expect((await request(f.app).get(url)).status).toBe(401);
    expect((await request(f.app).get(url).set('Authorization', `Bearer ${f.token}`)).status).toBe(404);
    f.db.tenantApplication.findFirst.mockResolvedValue({ id: 'application', requestedCode: 'afaq-school', requestedById: 'requester', reviewedById: 'reviewer', reviewedAt: new Date() });
    const response = await request(f.app).get(url).set('Authorization', `Bearer ${f.token}`);
    expect(response.status).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.body.data).toMatchObject({ prerequisitesPassed: true, provisioningEnabled: false });
    expect(f.db.tenantApplication.findFirst).toHaveBeenLastCalledWith(expect.objectContaining({ where: { id: 'application', status: 'APPROVED' } }));
  });
  it('lists only pending requests created by other reviewers for reviewable scope', async () => {
    const f = fixture();
    expect((await request(f.app).get('/api/platform/tenant-applications?scope=reviewable').set('Authorization', `Bearer ${f.token}`)).status).toBe(200);
    expect(f.db.tenantApplication.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { status: 'REQUESTED', requestedById: { not: 'operator' } } }));
  });
  it('scopes own requests to the verified account rather than caller-supplied identity', async () => {
    const f = fixture();
    expect((await request(f.app).get('/api/platform/tenant-applications?scope=mine&status=APPROVED').set('Authorization', `Bearer ${f.token}`)).status).toBe(200);
    expect(f.db.tenantApplication.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { status: 'APPROVED', requestedById: 'operator' } }));
  });
  it.each(['scope=reviewable&status=APPROVED', 'scope=someone-else', 'requestedById=other'])('rejects invalid application filter %s', async (query) => {
    const f = fixture();
    expect((await request(f.app).get(`/api/platform/tenant-applications?${query}`).set('Authorization', `Bearer ${f.token}`)).status).toBe(422);
    expect(f.db.tenantApplication.findMany).not.toHaveBeenCalled();
  });
  it('denies overview access to IT and anonymous visitors', async () => {
    const f = fixture('IT_SECURITY');
    expect((await request(f.app).get('/api/platform/overview')).status).toBe(401);
    expect((await request(f.app).get('/api/platform/overview').set('Authorization', `Bearer ${f.token}`)).status).toBe(403);
  });
  it('restricts reason-bearing history to Super Admin over HTTP', async () => {
    const admin = fixture();
    expect((await request(admin.app).get('/api/platform/accounts/it/access-history').set('Authorization', `Bearer ${admin.token}`)).status).toBe(200);
    const it = fixture('IT_SECURITY');
    expect((await request(it.app).get('/api/platform/accounts/it/access-history').set('Authorization', `Bearer ${it.token}`)).status).toBe(403);
    expect(it.db.platformAuditEvent.findMany).not.toHaveBeenCalled();
  });
  it('denies IT restoration through HTTP', async () => {
    const f = fixture('IT_SECURITY');
    expect((await request(f.app).post('/api/platform/accounts/other/restore').set('Authorization', `Bearer ${f.token}`).send({ reason: 'Suspension has been reviewed', suspensionEventId: 'event' })).status).toBe(403);
    expect(f.db.platformSession.updateMany).not.toHaveBeenCalled();
  });
  it('denies IT account controls through HTTP', async () => {
    const f = fixture('IT_SECURITY');
    const res = await request(f.app).post('/api/platform/accounts/other/disable').set('Authorization', `Bearer ${f.token}`).send({ reason: 'Access no longer required' });
    expect(res.status).toBe(403);
    expect(f.db.platformSession.updateMany).not.toHaveBeenCalled();
    expect(f.db.platformAuditEvent.create).not.toHaveBeenCalled();
  });
  it('protects Super Admin from disable requests through HTTP', async () => {
    const f = fixture();
    expect((await request(f.app).post('/api/platform/accounts/other/disable').set('Authorization', `Bearer ${f.token}`).send({ reason: 'Access no longer required' })).status).toBe(403);
    expect(f.db.platformSession.updateMany).not.toHaveBeenCalled();
  });
  it("allows only Super Admin to read the minimal paginated company directory", async () => {
    const f = fixture();
    const res = await request(f.app).get('/api/platform/accounts?page=2&pageSize=10').set('Authorization', `Bearer ${f.token}`);
    expect(res.status).toBe(200);
    expect(res.headers['cache-control']).toBe('no-store');
    expect(f.db.platformAccount.findMany).toHaveBeenCalledWith({
      where: {},
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: 10, take: 10,
      select: { id: true, fullName: true, email: true, role: true, status: true, createdAt: true },
    });
  });
  it("denies the company directory to IT and unauthenticated visitors", async () => {
    const f = fixture('IT_SECURITY');
    expect((await request(f.app).get('/api/platform/accounts').set('Authorization', `Bearer ${f.token}`)).status).toBe(403);
    expect((await request(f.app).get('/api/platform/accounts')).status).toBe(401);
    expect(f.db.platformAccount.findMany).not.toHaveBeenCalled();
  });
  it.each(['pageSize=1000', 'include=passwordHash', 'role=ADMIN', 'status=DELETED'])("rejects unapproved directory query %s", async (query) => {
    const f = fixture();
    expect((await request(f.app).get(`/api/platform/accounts?${query}`).set('Authorization', `Bearer ${f.token}`)).status).toBe(422);
    expect(f.db.platformAccount.findMany).not.toHaveBeenCalled();
  });
  it('filters company accounts by role and status without broadening access', async () => {
    const f = fixture();
    const res = await request(f.app).get('/api/platform/accounts?role=IT_SECURITY&status=DISABLED').set('Authorization', `Bearer ${f.token}`);
    expect(res.status).toBe(200);
    expect(f.db.platformAccount.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { role: 'IT_SECURITY', status: 'DISABLED' }, skip: 0, take: 25 }));
    const it = fixture('IT_SECURITY');
    expect((await request(it.app).get('/api/platform/accounts?role=IT_SECURITY').set('Authorization', `Bearer ${it.token}`)).status).toBe(403);
    expect(it.db.platformAccount.findMany).not.toHaveBeenCalled();
  });
  it("lists only own sessions and revokes the current session via HTTP", async () => {
    const f = fixture("IT_SECURITY");
    const auth = `Bearer ${f.token}`;
    expect((await request(f.app).get("/api/platform/sessions").set("Authorization", auth)).status).toBe(200);
    expect(f.db.platformSession.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ accountId: "operator" }) }));
    const result = await request(f.app).post(`/api/platform/sessions/${sid}/revoke`).set("Authorization", auth).send({});
    expect(result.status).toBe(200);
    expect(result.body.data.current).toBe(true);
    expect((await request(f.app).get("/api/platform/me").set("Authorization", auth)).status).toBe(401);
  });
  it("does not reveal another operator's session existence", async () => {
    const f = fixture();
    f.db.platformSession.findFirst.mockResolvedValue(null);
    expect((await request(f.app).post(`/api/platform/sessions/${sid}/revoke`).set("Authorization", `Bearer ${f.token}`).send({})).status).toBe(404);
    expect(f.db.platformSession.updateMany).not.toHaveBeenCalled();
  });
  it.each(["SUPER_ADMIN", "IT_SECURITY"])("permits %s to inspect platform health", async (role) => {
    const f = fixture(role);
    const res = await request(f.app).get("/api/platform/health").set("Authorization", `Bearer ${f.token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("healthy");
    expect(f.health).toHaveBeenCalledTimes(1);
    expect(res.headers["cache-control"]).toBe("no-store");
  });
  it("does not run health probes without platform authentication", async () => {
    const f = fixture();
    expect((await request(f.app).get("/api/platform/health")).status).toBe(401);
    expect(f.health).not.toHaveBeenCalled();
  });
  it.each(["", "too-short", schoolKey])("fails closed with an absent, weak or reused secret", async (secret) => {
    const f = fixture("SUPER_ADMIN", secret);
    const res = await request(f.app).get("/api/platform/me").set("Authorization", `Bearer ${f.token}`);
    expect(res.status).toBe(503);
    expect(res.headers["cache-control"]).toBe("no-store");
    expect(f.db.platformAccount.findUnique).not.toHaveBeenCalled();
  });

  it.each(["", "Basic abc", "Bearer token extra"])("rejects malformed authorization %s", async (authorization) => {
    const f = fixture();
    const res = await request(f.app).get("/api/platform/me").set("Authorization", authorization);
    expect(res.status).toBe(401);
  });

  it("does not use cookie or query tokens", async () => {
    const f = fixture();
    const res = await request(f.app).get("/api/platform/me").query({ token: f.token }).set("Cookie", `access_token=${f.token}`);
    expect(res.status).toBe(401);
  });

  it("rejects a school token before looking up platform identities", async () => {
    const f = fixture();
    const token = jwt.sign({ sub: "1", orgId: "1", role: "ADMIN", type: "access" }, schoolKey);
    expect((await request(f.app).get("/api/platform/me").set("Authorization", `Bearer ${token}`)).status).toBe(401);
    expect(f.db.platformAccount.findUnique).not.toHaveBeenCalled();
  });

  it("school middleware rejects the platform token type even with a school signature", async () => {
    const f = fixture();
    const token = jwt.sign(f.claims, schoolKey);
    expect((await request(f.app).get("/school").set("Authorization", `Bearer ${token}`)).status).toBe(401);
  });

  it("returns a minimal profile, never password hashes", async () => {
    const f = fixture();
    const res = await request(f.app).get("/api/platform/me").set("Authorization", `Bearer ${f.token}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ id: "operator", fullName: "Platform Operator", role: "SUPER_ADMIN" });
    expect(f.db.platformAccount.findUniqueOrThrow).toHaveBeenCalledWith({
      where: { id: "operator" }, select: { id: true, fullName: true, role: true },
    });
  });

  it("lets IT read platform audit but not application contacts or create schools", async () => {
    const f = fixture("IT_SECURITY");
    const auth = `Bearer ${f.token}`;
    expect((await request(f.app).get("/api/platform/audit-events").set("Authorization", auth)).status).toBe(200);
    expect((await request(f.app).get("/api/platform/tenant-applications").set("Authorization", auth)).status).toBe(403);
    expect((await request(f.app).post("/api/platform/tenant-applications").set("Authorization", auth)
      .send({ schoolName: "Afaq School", requestedCode: "afaq-school", adminEmail: "admin@example.test" })).status).toBe(403);
    expect((await request(f.app).post("/api/platform/tenant-applications/application/review").set("Authorization", auth)
      .send({ decision: "APPROVED", reason: "School ownership verified" })).status).toBe(403);
    expect(f.db.tenantApplication.create).not.toHaveBeenCalled();
  });

  it("allows Super Admin intake without activating a school", async () => {
    const f = fixture();
    const res = await request(f.app).post("/api/platform/tenant-applications").set("Authorization", `Bearer ${f.token}`)
      .send({ schoolName: "Afaq School", requestedCode: "afaq-school", adminEmail: "admin@example.test" });
    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe("REQUESTED");
    expect(f.db.platformAuditEvent.create).toHaveBeenCalledTimes(1);
  });

  it("validates pagination", async () => {
    const f = fixture();
    expect((await request(f.app).get("/api/platform/audit-events?pageSize=9999").set("Authorization", `Bearer ${f.token}`)).status).toBe(422);
  });

  it.each(["logout", "logout-all"])("%s invalidates subsequent requests", async (path) => {
    const f = fixture();
    const auth = `Bearer ${f.token}`;
    expect((await request(f.app).post(`/api/platform/${path}`).set("Authorization", auth)).status).toBe(200);
    expect((await request(f.app).get("/api/platform/me").set("Authorization", auth)).status).toBe(401);
    expect(f.db.platformAuditEvent.create).toHaveBeenCalledTimes(1);
  });

  it("does not expose login or signup endpoints", async () => {
    const f = fixture();
    for (const path of ["login", "register"]) {
      expect((await request(f.app).post(`/api/platform/${path}`).set("Authorization", `Bearer ${f.token}`)).status).toBe(404);
    }
  });
});
