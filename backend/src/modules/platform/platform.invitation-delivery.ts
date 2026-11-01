import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { createSmtpTransport, smtpEmailConfig } from '../../shared/notifications/smtp-email';

export type InvitationDelivery = {
  send(input: { token: string; email: string; expiresAt: Date }): Promise<'SMTP_ACCEPTED' | 'REJECTED' | 'UNKNOWN'>;
  consumeLimit(key: string, ip: string): Promise<void>;
};

export function invitationMessage(input: { token: string; email: string; expiresAt: Date }, url: string) {
  z.string().regex(/^[A-Za-z0-9_-]{43}$/).parse(input.token);
  z.string().email().parse(input.email);
  const link = new URL(url);
  if (link.protocol !== 'https:' || link.username || link.password || link.search || link.hash !== '#/school-invitation') {
    throw new Error('Invalid invitation page URL');
  }
  return {
    to: input.email, subject: 'Your Afaq madrasa administrator invitation',
    text: `You have been invited to set up your madrasa administrator account.\n\nOpen: ${link.href}\n\nEnter this private one-use invitation code:\n${input.token}\n\nChoose your own password. This invitation expires at ${input.expiresAt.toISOString()}. Your account will remain pending until activation.\n\nDo not forward this email or share the code. If you did not expect this invitation, ignore it and contact the Afaq team.`,
  };
}

export function createInvitationDelivery(environment: Record<string, string | undefined>, consumeLimit: InvitationDelivery['consumeLimit']): InvitationDelivery | undefined {
  if (environment.SCHOOL_INVITATIONS_ENABLED !== 'true') return undefined;
  const config = smtpEmailConfig(environment);
  const url = environment.SCHOOL_INVITATION_URL ?? '';
  invitationMessage({ token: 'a'.repeat(43), email: 'check@example.test', expiresAt: new Date() }, url);
  const transport = createSmtpTransport(config);
  return { consumeLimit, async send(input) {
    const draft = invitationMessage(input, url);
    try {
      const result = await transport.sendMail({ ...draft,
        from: { name: 'Afaq', address: config.EMAIL_FROM },
        messageId: `<${randomUUID()}@${config.EMAIL_FROM.split('@')[1]}>`,
        disableFileAccess: true, disableUrlAccess: true,
      });
      const matches = (value: unknown) => typeof value === 'string' && value.toLowerCase() === input.email.toLowerCase();
      if (result.accepted.some(matches)) return 'SMTP_ACCEPTED';
      if (result.rejected.some(matches)) return 'REJECTED';
      return 'UNKNOWN';
    } catch {
      // Delivery can succeed before a timeout: never automatically resend.
      return 'UNKNOWN';
    }
  } };
}
