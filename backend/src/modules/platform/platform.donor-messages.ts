import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import { smsPhone } from '../../shared/notifications/meseji-sms';
import { smsConfig } from '../../shared/notifications/sms-provider';
import { assertPlatformPermission } from './platform.permissions';
import type { PlatformContext } from './platform.service';

export function manualSmsReady() {
  return process.env.SMS_ENABLED === 'true' && process.env.DONOR_MANUAL_SMS_ENABLED === 'true'
    && smsConfig() !== null;
}
const idSchema = z.string().min(1).max(30);
const draftSchema = z.object({
  id: idSchema.optional(), revision: z.number().int().positive().optional(),
  body: z.string().trim().min(1).max(1000),
  donorIds: z.array(z.string().regex(/^[1-9]\d{0,18}$/)).max(100),
}).strict();

export class DonorMessagesService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const user = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!user || user.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
    assertPlatformPermission(user.role, 'fundraising.messages.manage');
    return user;
  }
  async recipients(actor: PlatformContext, input: unknown) {
    const query = z.object({ q: z.string().trim().max(100).default(''), page: z.coerce.number().int().min(1).max(10000).default(1), consent: z.enum(['all', 'granted', 'missing']).default('all') }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const rows = await tx.donor.findMany({ where: { organization: { status: 'ACTIVE' },
        ...(query.consent === 'all' ? {} : { smsOptIn: query.consent === 'granted' }),
        OR: [{ fullName: { contains: query.q } }, { organization: { name: { contains: query.q } } }] },
        orderBy: { id: 'asc' }, skip: (query.page - 1) * 20, take: 21,
        select: { id: true, fullName: true, phone: true, smsOptIn: true, organization: { select: { name: true } } },
      });
      return { hasMore: rows.length > 20, items: rows.slice(0, 20).map(row => ({ id: String(row.id),
        name: row.fullName, phone: smsPhone(row.phone), consent: row.smsOptIn, madrasa: row.organization.name })) };
    });
  }
  async consent(actor: PlatformContext, rawId: unknown, input: unknown) {
    const id = BigInt(z.string().regex(/^[1-9]\d{0,18}$/).parse(rawId));
    const body = z.object({ optedIn: z.boolean(), note: z.string().trim().min(5).max(500) }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const donor = await tx.donor.findUnique({ where: { id }, select: { id: true } });
      if (!donor) throw new HttpError(404, 'Donor not found');
      await tx.donor.update({ where: { id }, data: { smsOptIn: body.optedIn, smsConsentNote: body.note,
        smsConsentBy: actor.accountId, smsConsentAt: new Date() } });
      await tx.platformAuditEvent.create({ data: { actorId: actor.accountId, actorRole: 'SUPER_ADMIN',
        action: body.optedIn ? 'donor.sms.opted-in' : 'donor.sms.opted-out', entityType: 'Donor', entityId: String(id), metadata: { note: body.note } } });
      return { saved: true };
    });
  }
  async save(actor: PlatformContext, input: unknown) {
    const body = draftSchema.parse(input);
    const ids = [...new Set(body.donorIds)].map(BigInt);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const donors = await tx.donor.findMany({ where: { id: { in: ids }, organization: { status: 'ACTIVE' } }, include: { organization: { select: { name: true } } } });
      if (donors.length !== ids.length || donors.some(d => !smsPhone(d.phone) || !d.smsOptIn)) throw new HttpError(409, 'Select donors with valid numbers and recorded consent');
      const phones = donors.map(d => smsPhone(d.phone)!);
      if (new Set(phones).size !== phones.length) throw new HttpError(409, 'Two selected donors share a phone number; select one to avoid duplicate SMS');
      let id = body.id;
      if (id) {
        const changed = await tx.donorMessage.updateMany({ where: { id, creatorId: actor.accountId, status: 'DRAFT', revision: body.revision ?? -1 },
          data: { body: body.body, revision: { increment: 1 } } });
        if (!changed.count) throw new HttpError(409, 'Draft changed or was already queued. Reload it.');
        await tx.donorMessageRecipient.deleteMany({ where: { messageId: id } });
      } else {
        id = (await tx.donorMessage.create({ data: { creatorId: user.id, senderName: user.fullName, body: body.body } })).id;
      }
      if (donors.length) await tx.donorMessageRecipient.createMany({ data: donors.map(d => ({
        messageId: id!, donorId: d.id, donorName: d.fullName, madrasaName: d.organization.name, phone: smsPhone(d.phone)!,
      })) });
      return tx.donorMessage.findUniqueOrThrow({ where: { id }, include: { recipients: true } });
    });
  }
  async list(actor: PlatformContext, input: unknown) {
    const query = z.object({ tab: z.enum(['drafts', 'sent']), page: z.coerce.number().int().min(1).max(10000).default(1) }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const rows = await tx.donorMessage.findMany({ where: { creatorId: actor.accountId, status: query.tab === 'drafts' ? 'DRAFT' : 'QUEUED' },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (query.page - 1) * 10, take: 11, include: { recipients: true } });
      return { ready: manualSmsReady(), hasMore: rows.length > 10, items: rows.slice(0, 10) };
    });
  }
  async send(actor: PlatformContext, rawId: unknown, input: unknown) {
    const id = idSchema.parse(rawId);
    const { revision } = z.object({ revision: z.number().int().positive() }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const draft = await tx.donorMessage.findFirst({ where: { id, creatorId: actor.accountId }, include: { recipients: { include: { donor: { include: { organization: { select: { status: true } } } } } } } });
      if (!draft) throw new HttpError(404, 'Draft not found');
      if (draft.status === 'QUEUED') return { id, queued: true };
      if (!manualSmsReady()) throw new HttpError(503, 'Meseji sending is not configured. Your draft is saved.');
      if (draft.revision !== revision || !draft.recipients.length) throw new HttpError(409, 'Review the latest draft and recipients before sending');
      if (draft.recipients.some(r => !r.donor.smsOptIn || r.donor.organization.status !== 'ACTIVE' || smsPhone(r.donor.phone) !== r.phone)) {
        throw new HttpError(409, 'Recipient details or consent changed. Save and review the draft again.');
      }
      const changed = await tx.donorMessage.updateMany({ where: { id, status: 'DRAFT', revision }, data: { status: 'QUEUED', queuedAt: new Date() } });
      if (!changed.count) throw new HttpError(409, 'Message already changed. Refresh before proceeding.');
      await tx.donorMessageRecipient.updateMany({ where: { messageId: id, status: 'DRAFT' }, data: { status: 'PENDING' } });
      await tx.platformAuditEvent.create({ data: { actorId: actor.accountId, actorRole: 'SUPER_ADMIN', action: 'donor.message.queued',
        entityType: 'DonorMessage', entityId: id, metadata: { recipients: draft.recipients.length } } });
      return { id, queued: true };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
}
