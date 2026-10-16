import { describe, it, expect, vi } from 'vitest';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { companyCookieOptions, restoreCompanySession } from '../src/modules/auth/company-browser-session';

const secret = 'company-browser-test-secret-at-least-32-characters';
function fixture(role = 'SUPER_ADMIN') {
  const now = Math.floor(Date.now() / 1000);
  const token = jwt.sign({ sub: 'company', sid: 'fa95b712-f719-4321-9c84-6fe32b29a885',
    type: 'platform_access', role, iat: now - 60, exp: now + 840 }, secret,
  { issuer: 'afaq-platform', audience: 'afaq-platform-console' });
  const account = { id: 'company', fullName: 'Company User', role, status: 'ACTIVE' };
  const session = { id: 'fa95b712-f719-4321-9c84-6fe32b29a885', accountId: 'company', role,
    revokedAt: null as Date | null, createdAt: new Date((now - 60) * 1000), expiresAt: new Date((now + 840) * 1000) };
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue(account),
    findUniqueOrThrow: vi.fn().mockResolvedValue({ id: account.id, fullName: account.fullName, role }) },
    platformSession: { findUnique: vi.fn().mockResolvedValue(session) } };
  return { db: db as unknown as PrismaClient, token, account, session };
}
describe('company browser restoration', () => {
  for (const role of ['SUPER_ADMIN', 'IT_SECURITY']) {
    it(`restores ${role} without extending the original session`, async () => {
      const { db, token } = fixture(role);
      const result = await restoreCompanySession(db, secret, token);
      expect(result.scope).toBe('platform');
      expect(result.user.role).toBe(role);
      expect(result.accessToken).toBe(token);
      expect(result.expiresIn).toBeLessThanOrEqual(840);
      expect(result.expiresIn).toBeGreaterThan(830);
    });
  }
  it('rejects revoked sessions', async () => {
    const f = fixture(); f.session.revokedAt = new Date();
    await expect(restoreCompanySession(f.db, secret, f.token)).rejects.toMatchObject({ statusCode: 401 });
  });
  it('rejects disabled accounts', async () => {
    const f = fixture(); f.account.status = 'DISABLED';
    await expect(restoreCompanySession(f.db, secret, f.token)).rejects.toMatchObject({ statusCode: 401 });
  });
  it('rejects expired sessions', async () => {
    const f = fixture(); f.session.expiresAt = new Date(0);
    await expect(restoreCompanySession(f.db, secret, f.token)).rejects.toMatchObject({ statusCode: 401 });
  });
  it('limits cookies to guarded browser routes and HTTPS in production', () => {
    expect(companyCookieOptions(true)).toEqual({ httpOnly: true, secure: true, sameSite: 'lax', path: '/api/auth/browser' });
    expect(companyCookieOptions(false).httpOnly).toBe(true);
  });
});
