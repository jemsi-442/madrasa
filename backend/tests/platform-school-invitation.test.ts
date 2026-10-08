import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import { issueSchoolAdminInvitation, acceptSchoolAdminInvitation } from '../src/modules/platform/platform.school-invitation';

function fixture(role = 'IT_SECURITY', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: 'it', role, status }) },
    tenantApplication: { findUnique: vi.fn().mockResolvedValue(null) },
    schoolAdminInvitation: { findUnique: vi.fn().mockResolvedValue(null) },
    user: { create: vi.fn() },
  };
  const transaction = vi.fn(async (run: (tx: unknown) => unknown) => run(tx));
  return { tx, transaction, db: { $transaction: transaction } as unknown as PrismaClient };
}
const actor = { scope: 'platform' as const, accountId: 'it', sessionId: 'verified-session' };
describe('internal school admin invitation lifecycle', () => {
  it.each(['ADMIN', 'SUPER_ADMIN', 'PARENT'])('denies issuing by %s', async (role) => {
    const f = fixture(role);
    await expect(issueSchoolAdminInvitation(f.db, actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.tenantApplication.findUnique).not.toHaveBeenCalled();
  });
  it('denies disabled IT', async () => {
    const f = fixture('IT_SECURITY', 'DISABLED');
    await expect(issueSchoolAdminInvitation(f.db, actor, 'application')).rejects.toMatchObject({ statusCode: 403 });
  });
  it('requires an approved inactive school', async () => {
    const f = fixture();
    await expect(issueSchoolAdminInvitation(f.db, actor, 'application')).rejects.toMatchObject({ statusCode: 409 });
  });
  it.each([
    { token: 'invalid', fullName: 'Admin', password: 'long-enough-password' },
    { token: 'a'.repeat(43), fullName: 'Admin', password: 'short' },
    { token: 'a'.repeat(43), fullName: 'Admin', password: 'a'.repeat(73) },
    { token: 'a'.repeat(43), fullName: 'Admin', password: '\u00e9'.repeat(37) },
    { token: 'a'.repeat(43), fullName: 'Admin', password: 'long-enough-password', role: 'SUPER_ADMIN' },
  ])('rejects malformed acceptance before database work', async (input) => {
    const f = fixture();
    await expect(acceptSchoolAdminInvitation(f.db, input)).rejects.toThrow();
    expect(f.transaction).not.toHaveBeenCalled();
  });
  it('hashes token lookup and returns a generic unavailable response', async () => {
    const f = fixture();
    await expect(acceptSchoolAdminInvitation(f.db, { token: 'a'.repeat(43), fullName: 'Admin', password: 'long-enough-password' })).rejects.toMatchObject({ statusCode: 410 });
    expect(f.tx.schoolAdminInvitation.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { tokenHash: expect.stringMatching(/^[a-f0-9]{64}$/) } }));
    expect(f.tx.user.create).not.toHaveBeenCalled();
  });
});
