import type { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import express from "express";
import request from "supertest";
import { describe, it, expect, vi } from "vitest";
import { unifiedLogin } from "../src/modules/auth/unified-login";
import { verifyPlatformAccess } from "../src/modules/platform/platform.authentication";
import { errorHandler } from "../src/shared/middleware/error-handler";
import { HttpError } from "../src/shared/errors/http-error";
import { bootstrapPasswordReviewer } from "../src/modules/platform/platform.bootstrap";

const key = "unified-platform-test-signing-key-123456";
const password = "Demo-password-only-123";
function fixture() {
  const account = { id: "company", email: "company@afaq.test", fullName: "Company User", role: "SUPER_ADMIN", status: "ACTIVE", passwordHash: bcrypt.hashSync(password, 4), mfaSecretEncrypted: null };
  const db = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue(account), findFirst: vi.fn().mockResolvedValue(account) },
    user: { count: vi.fn().mockResolvedValue(0) },
    platformSession: { create: vi.fn().mockResolvedValue({}), findUnique: vi.fn() },
    platformAuditEvent: { create: vi.fn().mockResolvedValue({}) },
    $transaction: vi.fn(),
  };
  db.$transaction.mockImplementation((fn) => fn(db));
  const client = db as unknown as PrismaClient;
  const limit = vi.fn().mockResolvedValue(undefined);
  const school = vi.fn((_req, res) => res.json({ school: true }));
  const clear = vi.fn();
  const app = express(); app.use(express.json());
  app.post('/login', unifiedLogin(client, key, limit, clear), school); app.use(errorHandler);
  return { app, db, account, client, limit, school, clear };
}
describe('unified login', () => {
  it('resolves family registration through the same login and rate-limit identity', async () => {
    const f = fixture();
    f.db.platformAccount.findUnique.mockResolvedValue(null);
    f.db.user.count.mockResolvedValue(1);
    await request(f.app).post('/login').send({ login: ' dsm/fam/26/001 ', password }).expect(200);
    expect(f.limit).toHaveBeenCalledWith('DSM/FAM/26/001', expect.any(String));
    expect(f.db.user.count).toHaveBeenCalledWith({ where: { OR: [
      { email: 'DSM/FAM/26/001' }, { phone: 'DSM/FAM/26/001' },
      { familyLoginId: 'DSM/FAM/26/001', role: 'PARENT' },
    ] } });
    expect(f.school.mock.calls[0]![0].body).toEqual({ login: 'DSM/FAM/26/001', password });
  });
  for (const count of [0, 2]) it(`password bootstrap preserves reviewer limit: ${count}`, async () => {
    const f = fixture();
    const create = vi.fn().mockResolvedValue({ id: 'new', role: 'SUPER_ADMIN' });
    Object.assign(f.db.platformAccount, { count: vi.fn().mockResolvedValue(count), create });
    const work = bootstrapPasswordReviewer(f.client, { fullName: 'New Reviewer', email: 'new@afaq.test', password });
    if (count === 2) {
      await expect(work).rejects.toMatchObject({ statusCode: 409 });
      expect(create).not.toHaveBeenCalled();
    } else {
      await expect(work).resolves.toMatchObject({ role: 'SUPER_ADMIN' });
      expect(create.mock.calls[0]![0].data).not.toHaveProperty('mfaSecretEncrypted');
      expect(f.db.platformAuditEvent.create).toHaveBeenCalledOnce();
    }
  });
  for (const role of ['SUPER_ADMIN', 'IT_SECURITY']) it(`password-only company session: ${role}`, async () => {
    const f = fixture(); f.account.role = role;
    const response = await request(f.app).post('/login').send({ login: ' Company@afaq.test ', password }).expect(200);
    expect(response.body.data).toMatchObject({ scope: 'platform', user: { role } });
    expect(f.school).not.toHaveBeenCalled(); expect(f.clear).toHaveBeenCalledOnce();
    expect(f.limit).toHaveBeenCalledWith('company@afaq.test', expect.any(String));
    const session = f.db.platformSession.create.mock.calls[0]![0].data;
    expect(session.mfaVerifiedAt).toBeNull();
    f.db.platformSession.findUnique.mockResolvedValue(session);
    await expect(verifyPlatformAccess(f.client, response.body.data.accessToken, key)).resolves.toMatchObject({ scope: 'platform', accountId: 'company' });
    session.revokedAt = new Date();
    await expect(verifyPlatformAccess(f.client, response.body.data.accessToken, key)).rejects.toMatchObject({ statusCode: 401 });
  });
  it('delegates only a non-company identity to school login', async () => {
    const f = fixture(); f.db.platformAccount.findUnique.mockResolvedValue(null); f.db.user.count.mockResolvedValue(1);
    await request(f.app).post('/login').send({ login: 'school@afaq.test', password }).expect(200);
    expect(f.school).toHaveBeenCalledOnce(); expect(f.db.platformSession.create).not.toHaveBeenCalled();
  });
  for (const failure of ['password', 'disabled', 'collision', 'duplicate-school', 'changed', 'rate-limit']) it(`fails closed: ${failure}`, async () => {
    const f = fixture();
    if (failure === 'disabled') f.account.status = 'DISABLED';
    if (failure === 'collision') f.db.user.count.mockResolvedValue(1);
    if (failure === 'duplicate-school') { f.db.platformAccount.findUnique.mockResolvedValue(null); f.db.user.count.mockResolvedValue(2); }
    if (failure === 'changed') f.db.platformAccount.findFirst.mockResolvedValue(null);
    if (failure === 'rate-limit') f.limit.mockRejectedValue(new HttpError(429, 'Try later'));
    await request(f.app).post('/login').send({ login: 'company@afaq.test', password: failure === 'password' ? 'wrong-password' : password }).expect(failure === 'rate-limit' ? 429 : 401);
    expect(f.school).not.toHaveBeenCalled(); expect(f.db.platformSession.create).not.toHaveBeenCalled(); expect(f.clear).not.toHaveBeenCalled();
  });
  it('does not accept role selection or verification codes from login input', async () => {
    const f = fixture();
    for (const extra of [{ role: 'SUPER_ADMIN' }, { code: '123456' }]) {
      await request(f.app).post('/login').send({ login: 'company@afaq.test', password, ...extra }).expect(422);
    }
    expect(f.limit).not.toHaveBeenCalled();
  });
});
