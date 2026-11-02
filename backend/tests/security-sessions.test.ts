import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformGovernanceService } from '../src/modules/platform/platform.service';
import { sessionIp } from '../src/shared/utils/session-ip';

const actor = { scope: 'platform' as const, accountId: 'it-synthetic', sessionId: 'current' };
function setup(role = 'IT_SECURITY', status = 'ACTIVE') {
  const tx = {
    platformAccount: { findUnique: vi.fn().mockResolvedValue({ id: actor.accountId, role, status }) },
    platformSession: { findMany: vi.fn().mockResolvedValue([]) },
    refreshToken: { findMany: vi.fn().mockResolvedValue([]) },
  };
  const db = { $transaction: (work: (value: typeof tx) => unknown) => work(tx) } as unknown as PrismaClient;
  return { tx, service: new PlatformGovernanceService(db) };
}

it.each(['SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT', 'LEARNER'])('denies cross-account inspection to %s', async role => {
  const { tx, service } = setup(role);
  await expect(service.listSecuritySessions(actor)).rejects.toThrow('permission denied');
  expect(tx.platformSession.findMany).not.toHaveBeenCalled();
  expect(tx.refreshToken.findMany).not.toHaveBeenCalled();
});

it('rechecks disabled IT and rejects school context', async () => {
  await expect(setup('IT_SECURITY', 'DISABLED').service.listSecuritySessions(actor)).rejects.toThrow('not active');
  await expect(setup().service.listSecuritySessions({ ...actor, scope: 'school' } as never)).rejects.toThrow('authentication required');
});

it('lists other platform accounts with explicit safe selection and pagination', async () => {
  const { tx, service } = setup();
  tx.platformSession.findMany.mockResolvedValue([{
    id: 'other', accountId: 'another-account', role: 'SUPER_ADMIN', ipAddress: '192.0.2.12',
    account: { fullName: 'Synthetic administrator' },
  }] as never);
  expect(await service.listSecuritySessions(actor, { page: 2, pageSize: 20 })).toEqual([
    expect.objectContaining({ accountName: 'Synthetic administrator', ipAddress: '192.0.2.12', current: false, canRevoke: false }),
  ]);
  const args = tx.platformSession.findMany.mock.calls[0]![0] as any;
  expect(args).toMatchObject({ skip: 20, take: 20, where: { revokedAt: null } });
  expect(args.where.accountId).toBeUndefined();
  expect(args.select.account).toEqual({ select: { fullName: true } });
});

it('lists madrasa renewable access without selecting token hashes or learner records', async () => {
  const { tx, service } = setup();
  tx.refreshToken.findMany.mockResolvedValue([{
    id: 12n, userId: 45n, ipAddress: null, user: { fullName: 'Synthetic teacher', role: 'TEACHER' },
    organization: { name: 'Synthetic madrasa' },
  }] as never);
  expect(await service.listSecuritySessions(actor, { source: 'madrasa' })).toEqual([
    expect.objectContaining({ id: 'madrasa:12', scope: 'Synthetic madrasa', ipAddress: null, canRevoke: false }),
  ]);
  const args = tx.refreshToken.findMany.mock.calls[0]![0] as any;
  expect(args.select.tokenHash).toBeUndefined();
  expect(args.select.user).toEqual({ select: { fullName: true, role: true } });
  expect(args.where).toMatchObject({ revokedAt: null, user: { status: 'ACTIVE' } });
});

it('validates IP observations and rejects forwarded lists or arbitrary values', () => {
  expect(sessionIp('192.0.2.1')).toBe('192.0.2.1');
  expect(sessionIp('2001:db8::1')).toBe('2001:db8::1');
  for (const value of [undefined, 'unknown', '192.0.2.1, 198.51.100.1', '<script>']) expect(sessionIp(value)).toBeNull();
});

it('searches platform account names and IP before pagination', async () => {
  const { tx, service } = setup();
  await service.listSecuritySessions(actor, { q: ' 192.0.2.12 ', page: 2 });
  const args = tx.platformSession.findMany.mock.calls[0]![0] as any;
  expect(args.where.OR).toContainEqual({ ipAddress: { contains: '192.0.2.12' } });
  expect(args.where.OR).toContainEqual({ account: { fullName: { contains: '192.0.2.12' } } });
  expect(args.where.revokedAt).toBeNull();
  expect(args.skip).toBeGreaterThan(0);
});

it('searches madrasa roles without weakening active account restrictions', async () => {
  const { tx, service } = setup();
  await service.listSecuritySessions(actor, { source: 'madrasa', q: 'teacher' });
  const args = tx.refreshToken.findMany.mock.calls[0]![0] as any;
  expect(args.where.OR).toContainEqual({ user: { role: { in: ['TEACHER'] } } });
  expect(args.where.user.status).toBe('ACTIVE');
  expect(args.where.organization.status.in).toEqual(['ACTIVE', 'TRIAL']);
});

it('rejects oversized search before querying sessions', async () => {
  const { tx, service } = setup();
  await expect(service.listSecuritySessions(actor, { q: 'x'.repeat(101) })).rejects.toThrow();
  expect(tx.platformSession.findMany).not.toHaveBeenCalled();
});

it.each(['current', 'other'])('filters %s platform sessions before pagination', async filter => {
  const { tx, service } = setup();
  await service.listSecuritySessions(actor, { filter });
  const args = tx.platformSession.findMany.mock.calls[0]![0] as any;
  expect(args.where.id).toEqual(filter === 'current' ? actor.sessionId : { not: actor.sessionId });
  expect(args.where.revokedAt).toBeNull();
});

it('has no current platform session in the madrasa group', async () => {
  const { tx, service } = setup();
  expect(await service.listSecuritySessions(actor, { source: 'madrasa', filter: 'current' })).toEqual([]);
  expect(tx.refreshToken.findMany).not.toHaveBeenCalled();
});
