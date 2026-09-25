import crypto from "node:crypto";
import bcrypt from "bcryptjs";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { allowedBrowserOrigin } from "../src/modules/auth/browser-session";
import { api } from "./helpers/api-client";

const origin = "http://127.0.0.1:8080";
const credentials = { login: `browser-${crypto.randomUUID()}@example.test`, password: "Testing123!" };
const browser = (path: string) => api.post(`/api/auth/browser/${path}`)
  .set("Origin", origin).set("X-MIF-Browser", "1");
const cookie = (response: { headers: Record<string, any> }) => {
  const value = response.headers["set-cookie"] as string[];
  return value[0]!.split(";")[0]!;
};

describe("browser session restoration", () => {
  let orgId: bigint, userId: bigint;
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Browser auth test", code: crypto.randomUUID() } })).id;
    userId = (await prisma.user.create({ data: {
      orgId, role: "TEACHER", fullName: "Browser Teacher", email: credentials.login,
      passwordHash: await bcrypt.hash(credentials.password, 12),
    } })).id;
  });
  afterAll(async () => {
    await prisma.refreshToken.deleteMany({ where: { orgId } });
    await prisma.user.deleteMany({ where: { orgId } });
    await prisma.organization.delete({ where: { id: orgId } });
  });

  it("rejects untrusted origins, missing origins and missing CSRF headers", async () => {
    for (const path of ["login", "refresh", "logout", "register"]) {
      expect((await api.post(`/api/auth/browser/${path}`).send(credentials)).status).toBe(403);
      expect((await api.post(`/api/auth/browser/${path}`).set("Origin", origin).send(credentials)).status).toBe(403);
      expect((await api.post(`/api/auth/browser/${path}`).set("Origin", "https://untrusted.test")
        .set("X-MIF-Browser", "1").send(credentials)).status).toBe(403);
    }
    expect(allowedBrowserOrigin("null")).toBe(false);
    expect(allowedBrowserOrigin("http://localhost.evil.test")).toBe(false);
  });

  it("uses exact credentialed CORS origins rather than a wildcard", async () => {
    const response = await api.options("/api/auth/browser/refresh").set("Origin", origin)
      .set("Access-Control-Request-Method", "POST").set("Access-Control-Request-Headers", "x-mif-browser,content-type");
    expect(response.status).toBe(204);
    expect(response.headers["access-control-allow-origin"]).toBe(origin);
    expect(response.headers["access-control-allow-credentials"]).toBe("true");
    const denied = await browser("refresh").set("Origin", "https://evil.test").send({});
    expect(denied.headers["access-control-allow-origin"]).toBeUndefined();
    const mode = env.NODE_ENV;
    try {
      env.NODE_ENV = "production";
      expect(allowedBrowserOrigin("http://localhost:54321")).toBe(false);
    } finally { env.NODE_ENV = mode; }
  });

  it("keeps the refresh credential HttpOnly and restores the current account after rotation", async () => {
    const loggedIn = await browser("login").send(credentials);
    expect(loggedIn.status).toBe(200);
    expect(loggedIn.body.data.refreshToken).toBeUndefined();
    expect(loggedIn.body.data.refreshTokenHash).toBeUndefined();
    expect(loggedIn.headers["cache-control"]).toBe("no-store");
    const header = (loggedIn.headers["set-cookie"] as unknown as string[])[0]!;
    expect(header).toContain("HttpOnly");
    expect(header).toContain("SameSite=Lax");
    expect(header).toContain("Path=/api/auth/browser");
    let current = cookie(loggedIn);
    for (let i = 0; i < 3; i++) {
      const restored = await browser("refresh").set("Cookie", current).send({});
      expect(restored.status).toBe(200);
      expect(restored.body.data.user.id).toBe(userId.toString());
      expect(restored.body.data.user.role).toBe("TEACHER");
      expect(restored.body.data.refreshToken).toBeUndefined();
      expect(cookie(restored)).not.toBe(current);
      current = cookie(restored);
      expect((await api.get("/api/teacher-workspace/classes")
        .set("Authorization", `Bearer ${restored.body.data.accessToken}`)).status).toBe(200);
    }
    const signedOut = await browser("logout").set("Cookie", current).send({});
    expect(signedOut.status).toBe(200);
    expect(cookie(signedOut)).toBe("mif_browser_session=");
    expect((await browser("refresh").set("Cookie", current).send({})).status).toBe(401);
    expect((await browser("logout").send({})).status).toBe(200);
  });

  it("rejects invalid, expired and revoked browser sessions", async () => {
    for (const value of ["", "mif_browser_session=invalid", "mif_browser_session=%ZZ"]) {
      const response = await browser("refresh").set("Cookie", value).send({});
      expect(response.status).toBe(401);
      expect(cookie(response)).toBe("mif_browser_session=");
    }
    const loggedIn = await browser("login").send(credentials);
    await prisma.refreshToken.updateMany({ where: { userId }, data: { expiresAt: new Date(0) } });
    expect((await browser("refresh").set("Cookie", cookie(loggedIn)).send({})).status).toBe(401);
  });

  it("does not restore disabled users or inactive schools", async () => {
    let loggedIn = await browser("login").send(credentials);
    try {
      await prisma.user.update({ where: { id: userId }, data: { status: "DISABLED" } });
      expect((await browser("refresh").set("Cookie", cookie(loggedIn)).send({})).status).toBe(401);
    } finally { await prisma.user.update({ where: { id: userId }, data: { status: "ACTIVE" } }); }
    loggedIn = await browser("login").send(credentials);
    try {
      await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
      expect((await browser("refresh").set("Cookie", cookie(loggedIn)).send({})).status).toBe(401);
      expect((await browser("login").send(credentials)).status).toBe(401);
    } finally { await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } }); }
  });

  it("preserves token-based login for native clients", async () => {
    const response = await api.post("/api/auth/login").send(credentials);
    expect(response.status).toBe(200);
    expect(response.body.data.refreshToken).toBeTypeOf("string");
    expect(response.headers["set-cookie"]).toBeUndefined();
  });
});
