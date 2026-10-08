import type { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import express from "express";
import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import { base32Secret, decryptMfaSecret, encryptMfaSecret, matchTotpStep, totpCode } from "../src/modules/platform/platform.mfa";
import { loginPlatform } from "../src/modules/platform/platform.login";
import { bootstrapPlatformReviewer } from "../src/modules/platform/platform.bootstrap";
import { createPlatformRouter } from "../src/modules/platform/platform.routes";
import { errorHandler } from "../src/shared/middleware/error-handler";

const secret = Buffer.from("12345678901234567890");
const encryptionKey = "ab".repeat(32);
const signingKey = "separate-platform-test-signing-key-123456";
const password = "Platform-test-password-123";
const passwordHash = bcrypt.hashSync(password, 4);

function fixture() {
  const account = {
    id: "operator", fullName: "Platform Operator", email: "operator@example.test", role: "SUPER_ADMIN", status: "ACTIVE",
    passwordHash, mfaSecretEncrypted: encryptMfaSecret(secret, "operator", encryptionKey), lastMfaStep: -1n,
  };
  const db = {
    platformAccount: {
      findUnique: vi.fn().mockResolvedValue(account), count: vi.fn().mockResolvedValue(0),
      create: vi.fn().mockResolvedValue({ id: "new-account", role: "SUPER_ADMIN" }),
      updateMany: vi.fn().mockImplementation(async (args) => {
        if (account.lastMfaStep >= args.data.lastMfaStep) return { count: 0 };
        account.lastMfaStep = args.data.lastMfaStep;
        return { count: 1 };
      }),
    },
    platformSession: { create: vi.fn().mockResolvedValue({}) },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}) },
    $transaction: vi.fn(),
  };
  db.$transaction.mockImplementation(async (run) => run(db));
  const client = db as unknown as PrismaClient;
  const options = { encryptionKey, consumeLimit: vi.fn().mockResolvedValue(undefined) };
  const input = { email: account.email, password, code: totpCode(secret, BigInt(Math.floor(Date.now() / 30_000))) };
  return { account, db, client, options, input };
}

describe("platform MFA cryptography", () => {
  // SHA-1 vectors from RFC 6238 Appendix B, including times beyond 2038.
  it.each([[59, "94287082"], [1111111109, "07081804"], [1111111111, "14050471"],
    [1234567890, "89005924"], [2000000000, "69279037"], [20000000000, "65353130"]] as const)("matches RFC vector at %s", (seconds, expected) => {
    expect(totpCode(secret, BigInt(Math.floor(seconds / 30)), 8)).toBe(expected);
  });
  it("encodes a secret for authenticator enrollment", () => {
    expect(base32Secret(secret)).toBe("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ");
  });
  it("accepts only current or adjacent time steps and six-digit codes", () => {
    const now = 1_700_000_000_000;
    const step = BigInt(Math.floor(now / 30_000));
    for (const offset of [-1n, 0n, 1n]) expect(matchTotpStep(secret, totpCode(secret, step + offset), now)).toBe(step + offset);
    expect(matchTotpStep(secret, totpCode(secret, step - 2n), now)).toBeNull();
    expect(matchTotpStep(secret, "12345", now)).toBeNull();
    expect(matchTotpStep(secret, "abcdef", now)).toBeNull();
  });
  it("encrypts uniquely and binds the ciphertext to its account", () => {
    const encrypted = encryptMfaSecret(secret, "account", encryptionKey);
    expect(decryptMfaSecret(encrypted, "account", encryptionKey)).toEqual(secret);
    expect(encryptMfaSecret(secret, "account", encryptionKey)).not.toBe(encrypted);
    expect(() => decryptMfaSecret(encrypted, "another-account", encryptionKey)).toThrow();
    expect(() => decryptMfaSecret(encrypted, "account", "cd".repeat(32))).toThrow();
    const parts = encrypted.split(":");
    parts[3] = "00".repeat(20);
    expect(() => decryptMfaSecret(parts.join(":"), "account", encryptionKey)).toThrow();
  });
});

describe("platform password and MFA login", () => {
  it("issues a 15-minute token only after code consumption, session and audit writes", async () => {
    const f = fixture();
    const response = await loginPlatform(f.client, signingKey, f.options, f.input, "127.0.0.1");
    const claims = jwt.verify(response.accessToken, signingKey) as jwt.JwtPayload;
    expect(claims.type).toBe("platform_access");
    expect(claims.exp! - claims.iat!).toBe(900);
    expect(claims.aud).toBe("afaq-platform-console");
    expect(f.options.consumeLimit).toHaveBeenCalledWith(f.input.email, "127.0.0.1");
    expect(f.db.platformSession.create).toHaveBeenCalledWith({ data: expect.objectContaining({ id: claims.sid, accountId: f.account.id }) });
    expect(response.user).toEqual({ id: f.account.id, fullName: f.account.fullName, role: f.account.role });
    expect(f.db.platformAuditEvent.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: "platform.login.succeeded" }) });
  });
  it("rejects OTP reuse", async () => {
    const f = fixture();
    await loginPlatform(f.client, signingKey, f.options, f.input, "ip");
    await expect(loginPlatform(f.client, signingKey, f.options, f.input, "ip")).rejects.toMatchObject({ statusCode: 401 });
    expect(f.db.platformSession.create).toHaveBeenCalledTimes(1);
  });
  it("conditional consumption blocks concurrent replay and account changes", async () => {
    const f = fixture();
    f.db.platformAccount.updateMany.mockResolvedValue({ count: 0 });
    await expect(loginPlatform(f.client, signingKey, f.options, f.input, "ip")).rejects.toMatchObject({ statusCode: 401 });
    expect(f.db.platformSession.create).not.toHaveBeenCalled();
    expect(f.db.platformAccount.updateMany).toHaveBeenCalledWith({ where: expect.objectContaining({
      status: "ACTIVE", passwordHash: f.account.passwordHash, mfaSecretEncrypted: f.account.mfaSecretEncrypted,
    }), data: expect.any(Object) });
  });
  it.each(["password", "code", "disabled", "unknown", "unenrolled"])("rejects %s without creating a session", async (scenario) => {
    const f = fixture();
    if (scenario === "password") f.input.password = "wrong-password";
    if (scenario === "code") f.input.code = totpCode(secret, BigInt(Math.floor(Date.now() / 30_000)) - 10n);
    if (scenario === "disabled") f.account.status = "DISABLED";
    if (scenario === "unknown") f.db.platformAccount.findUnique.mockResolvedValue(null);
    if (scenario === "unenrolled") f.db.platformAccount.findUnique.mockResolvedValue({ ...f.account, mfaSecretEncrypted: null });
    await expect(loginPlatform(f.client, signingKey, f.options, f.input, "ip")).rejects.toMatchObject({ statusCode: 401 });
    expect(f.db.platformSession.create).not.toHaveBeenCalled();
  });
  it("fails closed when rate limiting fails, before a database lookup", async () => {
    const f = fixture();
    f.options.consumeLimit.mockRejectedValue(new Error("limiter unavailable"));
    await expect(loginPlatform(f.client, signingKey, f.options, f.input, "ip")).rejects.toThrow("limiter unavailable");
    expect(f.db.platformAccount.findUnique).not.toHaveBeenCalled();
  });
  it("never returns a token if its audit cannot be persisted", async () => {
    const f = fixture();
    f.db.platformAuditEvent.create.mockRejectedValue(new Error("audit failure"));
    await expect(loginPlatform(f.client, signingKey, f.options, f.input, "ip")).rejects.toThrow("audit failure");
  });
  it("requires valid independent MFA configuration", async () => {
    const f = fixture();
    await expect(loginPlatform(f.client, signingKey, { ...f.options, encryptionKey: "" }, f.input, "ip")).rejects.toMatchObject({ statusCode: 503 });
    await expect(loginPlatform(f.client, encryptionKey, f.options, f.input, "ip")).rejects.toMatchObject({ statusCode: 503 });
  });
  it("provides login without requiring an existing Bearer token", async () => {
    const f = fixture();
    const app = express();
    app.use(express.json());
    app.use("/platform", createPlatformRouter(f.client, signingKey, ["school-secret"], f.options));
    app.use(errorHandler);
    const res = await request(app).post("/platform/login").send(f.input);
    expect(res.status).toBe(200);
    expect(res.headers["cache-control"]).toBe("no-store");
    expect(res.body.data.accessToken).toBeTruthy();
    expect(res.body.data.user.passwordHash).toBeUndefined();
  });
});

describe("controlled reviewer bootstrap", () => {
  it("requires authenticator confirmation and writes an encrypted secret", async () => {
    const f = fixture();
    await bootstrapPlatformReviewer(f.client, { ...f.input, fullName: "First Reviewer" }, secret, encryptionKey);
    expect(f.db.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: "Serializable" });
    expect(f.db.platformAccount.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      role: "SUPER_ADMIN", status: "ACTIVE", mfaSecretEncrypted: expect.stringMatching(/^v1:/),
    }), select: { id: true, fullName: true, role: true } });
    expect(f.db.platformAuditEvent.create).toHaveBeenCalledTimes(1);
  });
  it("will not create a third reviewer or overwrite existing accounts", async () => {
    const f = fixture();
    f.db.platformAccount.count.mockResolvedValue(2);
    await expect(bootstrapPlatformReviewer(f.client, { ...f.input, fullName: "Third Reviewer" }, secret, encryptionKey)).rejects.toMatchObject({ statusCode: 409 });
    expect(f.db.platformAccount.create).not.toHaveBeenCalled();
  });
  it("rejects role injection and short passwords", async () => {
    const f = fixture();
    await expect(bootstrapPlatformReviewer(f.client, { ...f.input, fullName: "Reviewer", role: "IT_SECURITY" }, secret, encryptionKey)).rejects.toThrow();
    await expect(bootstrapPlatformReviewer(f.client, { ...f.input, fullName: "Reviewer", password: "short" }, secret, encryptionKey)).rejects.toThrow();
  });
});
