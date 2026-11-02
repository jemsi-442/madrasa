import type { PrismaClient } from '@prisma/client';
import { smsConfig } from '../../shared/notifications/sms-provider';
import { smtpEmailConfig } from '../../shared/notifications/smtp-email';
import { HttpError } from '../../shared/errors/http-error';
import type { PlatformContext } from './platform.service';

export function integrationSummary(environment: NodeJS.ProcessEnv, passwordOnly: boolean | undefined) {
  let emailReady = false;
  try { smtpEmailConfig(environment); emailReady = true; } catch { /* No configuration details leave this endpoint. */ }
  const smsReady = !!smsConfig(environment);
  let timezone = 'Africa/Dar_es_Salaam';
  try { new Intl.DateTimeFormat('en', { timeZone: environment.TZ ?? timezone }); timezone = environment.TZ ?? timezone; } catch { timezone = 'Invalid configuration'; }
  const present = (key: string) => !!environment[key]?.trim();
  return {
    checkedAt: new Date().toISOString(),
    services: {
      Authentication: passwordOnly === undefined ? 'Login not configured' : passwordOnly ? 'Password sign-in mode' : 'MFA sign-in mode',
      'Email & SMS gateway': `Email: ${emailReady ? 'configured' : 'incomplete'} / SMS: ${environment.SMS_ENABLED !== 'true' ? 'disabled' : smsReady ? 'configured' : 'incomplete'}`,
      'Payment connection': environment.SNIPPE_MOCK_MODE === 'true' ? 'Mock mode - no live transfers' : present('SNIPPE_API_KEY') && present('SNIPPE_WEBHOOK_SECRET') ? 'Credentials present - not tested' : 'Configuration incomplete',
      'Backup storage': 'Provider not connected',
      'Quran content': environment.QF_ENABLED !== 'true' ? 'Disabled' : present('QF_CLIENT_ID') && present('QF_CLIENT_SECRET') ? 'Credentials present - not tested' : 'Configuration incomplete',
    },
    timezone,
    mfaPolicy: passwordOnly === undefined ? 'Login configuration unavailable' : passwordOnly ? 'Password-only sign-in is enabled. MFA is not required by this login mode.' : 'MFA login mode is configured. This does not confirm enrollment for every account.',
    connectionTested: false,
    configurationChecks: {
      Authentication: [
        { label: 'Login configured', ready: passwordOnly !== undefined },
      ],
      'Email & SMS gateway': [
        { label: 'SMTP configuration complete', ready: emailReady },
        { label: 'SMS enabled', ready: environment.SMS_ENABLED === 'true' },
        { label: 'SMS provider configuration complete', ready: smsReady },
      ],
      'Payment connection': [
        { label: 'Live API credential present', ready: present('SNIPPE_API_KEY') },
        { label: 'Webhook credential present', ready: present('SNIPPE_WEBHOOK_SECRET') },
        { label: 'Mock mode disabled', ready: environment.SNIPPE_MOCK_MODE !== 'true' },
      ],
      'Backup storage': [
        { label: 'Backup provider connected', ready: false },
      ],
      'Quran content': [
        { label: 'Quran provider enabled', ready: environment.QF_ENABLED === 'true' },
        { label: 'Client ID present', ready: present('QF_CLIENT_ID') },
        { label: 'Client secret present', ready: present('QF_CLIENT_SECRET') },
      ],
    },
  };
}

export async function readIntegrations(db: PrismaClient, actor: PlatformContext, passwordOnly: boolean | undefined) {
  if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
  const account = await db.platformAccount.findUnique({ where: { id: actor.accountId }, select: { role: true, status: true } });
  if (!account || account.role !== 'IT_SECURITY' || account.status !== 'ACTIVE') throw new HttpError(403, 'Integrations are restricted to active IT accounts');
  return integrationSummary(process.env, passwordOnly);
}
