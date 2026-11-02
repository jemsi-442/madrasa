import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { integrationSummary, readIntegrations, smtpConnectionCheck, quranConnectionCheck, smsConnectionCheck } from '../src/modules/platform/platform.integrations';

it.each([true, false])('reads RodSMS credits and sender approval without sending: %s', async approved => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const http = vi.fn().mockResolvedValueOnce(Response.json({ success: true, data: { sms_credits: 20, currency: 'credits' } }))
    .mockResolvedValueOnce(Response.json({ success: true, data: approved ? [{ sender_id: 'AFAQ', country: 'TZ' }] : [] }));
  const check = smsConnectionCheck(db, { SMS_ENABLED: 'true', SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: 'secret-sentinel', RODSMS_SENDER_ID: 'AFAQ' }, http);
  const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 'synthetic' };
  const result = await check(actor);
  expect(result).toMatchObject({ status: approved ? 'CONNECTED' : 'DEGRADED', smsCredits: 20, senderApproved: approved });
  expect(JSON.stringify(result)).not.toContain('secret-sentinel');
  expect(http.mock.calls.map(call => call[0])).toEqual(['https://www.rodsms.com/api/v1/balance', 'https://www.rodsms.com/api/v1/sender-ids']);
  expect(http.mock.calls.every(call => call[1].method === 'GET' && call[1].redirect === 'error')).toBe(true);
  await expect(check(actor)).rejects.toThrow('one minute');
});

it('denies SMS checks for non-IT accounts before any network request', async () => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'SUPER_ADMIN', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const http = vi.fn();
  await expect(smsConnectionCheck(db, {}, http)({ scope: 'platform', accountId: 'synthetic', sessionId: 'synthetic' })).rejects.toThrow('restricted');
  expect(http).not.toHaveBeenCalled();
});

it.each([403, 500, 200])('handles denied, unavailable or malformed RodSMS responses: %s', async status => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const http = vi.fn().mockResolvedValue(Response.json({ error: 'secret-sentinel' }, { status }));
  const check = smsConnectionCheck(db, { SMS_ENABLED: 'true', SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: 'synthetic', RODSMS_SENDER_ID: 'AFAQ' }, http);
  const result = await check({ scope: 'platform', accountId: 'synthetic', sessionId: 'synthetic' });
  expect(result.status).toBe(status === 403 ? 'ACCESS_DENIED' : 'FAILED');
  expect(JSON.stringify(result)).not.toContain('secret-sentinel');
  expect(http).toHaveBeenCalledOnce();
});
import type { QuranContentClient } from '../src/modules/teacher-workspace/quran-content';

it.each(['CONNECTED', 'FAILED', 'NOT_CONFIGURED'])('returns safe Quran check status %s', async expected => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const chapters = expected === 'FAILED' ? vi.fn().mockRejectedValue(new Error('secret-sentinel')) : vi.fn().mockResolvedValue({ environment: 'prelive', limitedContent: true, chapters: [{ id: 1 }] });
  const create = vi.fn(() => ({ chapters }) as unknown as QuranContentClient);
  const check = quranConnectionCheck(db, { QF_ENABLED: expected === 'NOT_CONFIGURED' ? 'false' : 'true', QF_ENV: 'prelive', QF_CLIENT_ID: 'synthetic', QF_CLIENT_SECRET: 'secret-sentinel' }, create);
  const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 'synthetic' };
  const result = await check(actor);
  expect(result.status).toBe(expected);
  expect(JSON.stringify(result)).not.toContain('secret-sentinel');
  if (expected === 'CONNECTED') expect(result).toMatchObject({ chapterCount: 1, limitedContent: true });
  if (expected === 'NOT_CONFIGURED') expect(create).not.toHaveBeenCalled();
  await expect(check(actor)).rejects.toThrow('one minute');
});

it('denies Quran checks before making provider requests', async () => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'DISABLED' }) } } as unknown as PrismaClient;
  const create = vi.fn();
  await expect(quranConnectionCheck(db, {}, create)({ scope: 'platform', accountId: 'synthetic', sessionId: 'synthetic' })).rejects.toThrow('restricted');
  expect(create).not.toHaveBeenCalled();
});
import type { createSmtpEmail } from '../src/shared/notifications/smtp-email';

it('checks SMTP without sending and throttles repeated checks', async () => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const client = { verify: vi.fn().mockResolvedValue({ status: 'SMTP_CONNECTION_VERIFIED' }), close: vi.fn(), send: vi.fn() };
  const check = smtpConnectionCheck(db, () => client as unknown as ReturnType<typeof createSmtpEmail>);
  const actor = { scope: 'platform' as const, accountId: 'synthetic', sessionId: 'synthetic' };
  expect(await check(actor)).toMatchObject({ status: 'CONNECTED' });
  expect(client.send).not.toHaveBeenCalled();
  expect(client.close).toHaveBeenCalledOnce();
  await expect(check(actor)).rejects.toThrow('one minute');
});

it('denies SMTP probes before creating a client', async () => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'SUPER_ADMIN', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const create = vi.fn();
  await expect(smtpConnectionCheck(db, create)({ scope: 'platform', accountId: 'synthetic', sessionId: 'synthetic' })).rejects.toThrow('restricted');
  expect(create).not.toHaveBeenCalled();
});

it('does not reveal configuration errors', async () => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role: 'IT_SECURITY', status: 'ACTIVE' }) } } as unknown as PrismaClient;
  const check = smtpConnectionCheck(db, () => { throw new Error('secret-sentinel'); });
  const result = await check({ scope: 'platform', accountId: 'synthetic', sessionId: 'synthetic' });
  expect(result.status).toBe('NOT_CONFIGURED');
  expect(JSON.stringify(result)).not.toContain('secret-sentinel');
});
it('returns allowlisted status without configuration secrets', () => {
  const data = integrationSummary({ SMS_ENABLED: 'true', SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: 'secret-sentinel', RODSMS_SENDER_ID: 'AFAQ',
    QF_ENABLED: 'true', QF_CLIENT_ID: 'private-client', QF_CLIENT_SECRET: 'secret-sentinel', SNIPPE_MOCK_MODE: 'true' }, true);
  expect(JSON.stringify(data)).not.toContain('secret-sentinel');
  expect(JSON.stringify(data)).not.toContain('private-client');
  expect(data.services['Email & SMS gateway']).toContain('SMS: configured');
  expect(data.services['Payment connection']).toContain('Mock mode');
  expect(data.mfaPolicy).toContain('Password-only');
  expect(data.connectionTested).toBe(false);
  expect(data.configurationChecks['Email & SMS gateway']).toEqual([
    { label: 'SMTP configuration complete', ready: false },
    { label: 'SMS enabled', ready: true },
    { label: 'SMS provider configuration complete', ready: true },
  ]);
  expect(data.configurationChecks['Payment connection']).toContainEqual({ label: 'Mock mode disabled', ready: false });
});
it('separates disabled providers from present credentials and rejects invalid SMS configuration', () => {
  const data = integrationSummary({ QF_CLIENT_ID: 'synthetic', QF_CLIENT_SECRET: 'synthetic',
    SMS_ENABLED: 'true', SMS_PROVIDER: 'rodsms', RODSMS_API_KEY: 'synthetic', RODSMS_SENDER_ID: 'invalid sender' }, false);
  expect(data.configurationChecks['Quran content']).toEqual([
    { label: 'Quran provider enabled', ready: false },
    { label: 'Client ID present', ready: true },
    { label: 'Client secret present', ready: true },
  ]);
  expect(data.configurationChecks['Email & SMS gateway']).toContainEqual({ label: 'SMS provider configuration complete', ready: false });
  expect(data.connectionTested).toBe(false);
});
it('does not mistake absent configuration for connection success', () => {
  const data = integrationSummary({}, undefined);
  expect(data.services.Authentication).toBe('Login not configured');
  expect(data.services['Quran content']).toBe('Disabled');
  expect(data.services['Email & SMS gateway']).toContain('incomplete');
});
it.each([['SUPER_ADMIN', 'ACTIVE'], ['TEACHER', 'ACTIVE'], ['IT_SECURITY', 'DISABLED']])('rejects %s %s', async (role, status) => {
  const db = { platformAccount: { findUnique: vi.fn().mockResolvedValue({ role, status }) } } as unknown as PrismaClient;
  await expect(readIntegrations(db, { scope: 'platform', accountId: 'synthetic-it', sessionId: 'synthetic-session' }, true)).rejects.toThrow('restricted');
});
