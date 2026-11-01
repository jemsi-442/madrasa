import { describe, expect, it, vi } from 'vitest';
const mock = vi.hoisted(() => ({ sendMail: vi.fn() }));
vi.mock('nodemailer', () => ({ default: { createTransport: () => mock } }));
import { createInvitationDelivery, invitationMessage } from '../src/modules/platform/platform.invitation-delivery';

const input = { token: 'x'.repeat(43), email: 'synthetic@example.test', expiresAt: new Date('2030-01-01') };
const settings = {
  SCHOOL_INVITATIONS_ENABLED: 'true', EMAIL_MODE: 'smtp', EMAIL_FROM: 'sender@example.test',
  EMAIL_SENDER_VERIFIED: 'true', EMAIL_LOGIN_URL: 'https://example.test/#/login',
  SMTP_HOST: 'smtp.example.test', SMTP_PORT: '587', SMTP_USER: 'synthetic', SMTP_PASSWORD: 'synthetic',
  SCHOOL_INVITATION_URL: 'https://example.test/#/school-invitation',
};
describe('invitation delivery', () => {
  it('is disabled by default and fails closed on incomplete SMTP configuration', () => {
    expect(createInvitationDelivery({}, async () => {})).toBeUndefined();
    expect(() => createInvitationDelivery({ SCHOOL_INVITATIONS_ENABLED: 'true' }, async () => {})).toThrow();
  });
  it('keeps the one-use code out of the link and never creates a password', () => {
    const message = invitationMessage(input, settings.SCHOOL_INVITATION_URL);
    expect(message.text.split('\n').find(line => line.startsWith('Open:'))).toBe(`Open: ${settings.SCHOOL_INVITATION_URL}`);
    expect(message.text.includes(input.token)).toBe(true);
    expect(message.text).toContain('Choose your own password');
  });
  for (const url of ['http://example.test/#/school-invitation', 'https://user:pass@example.test/#/school-invitation', 'https://example.test/?token=bad#/school-invitation', 'https://example.test/#/login']) {
    it('rejects unsafe or incorrect invitation URL', () => {
      expect(() => invitationMessage(input, url)).toThrow();
    });
  }
  it('reports SMTP acceptance without claiming inbox delivery', async () => {
    mock.sendMail.mockResolvedValueOnce({ accepted: [input.email], rejected: [] });
    const sender = createInvitationDelivery(settings, async () => {})!;
    expect(await sender.send(input)).toBe('SMTP_ACCEPTED');
  });
  it('sanitizes failure and never automatically retries', async () => {
    mock.sendMail.mockReset().mockRejectedValue(new Error('private provider payload'));
    const sender = createInvitationDelivery(settings, async () => {})!;
    expect(await sender.send(input)).toBe('UNKNOWN');
    expect(mock.sendMail).toHaveBeenCalledTimes(1);
  });
});
