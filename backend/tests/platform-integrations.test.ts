import { expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { integrationSummary, readIntegrations } from '../src/modules/platform/platform.integrations';
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
