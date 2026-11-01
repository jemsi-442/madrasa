import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import { assertPlatformPermission } from './platform.permissions';
import type { PlatformContext } from './platform.service';
import { fundsPdf } from './platform.funds-pdf';

export class PlatformFundsService {
  constructor(private readonly db: PrismaClient) {}
  async pdf(actor: PlatformContext, input: unknown) {
    const snapshot = await this.overview(actor, input);
    return { fileName: `afaq-financial-summary-${snapshot.month}-${snapshot.currency}-page-${snapshot.page}.pdf`,
      base64: (await fundsPdf(snapshot)).toString('base64') };
  }
  async messages(actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const account = await this.db.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!account || account.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
    assertPlatformPermission(account.role, 'fundraising.oversight.read');
    const enabled = process.env.SMS_ENABLED === 'true' && process.env.DONATION_SMS_ENABLED === 'true';
    if (!enabled) return { enabled, remindersEnabled: false, items: [] };
    const rows = await this.db.donationSms.findMany({ take: 20, orderBy: { id: 'desc' },
      select: { donationId: true, status: true, reason: true, updatedAt: true } });
    return { enabled, remindersEnabled: false, items: rows.map(row => ({
      reference: `DON-${String(row.donationId).padStart(8, '0')}`, status: row.status,
      reason: row.reason, updatedAt: row.updatedAt.toISOString(),
    })) };
  }
  async overview(actor: PlatformContext, input: unknown) {
    const query = z.object({
      month: z.string().regex(/^(20\d{2})-(0[1-9]|1[0-2])$/),
      currency: z.string().regex(/^[A-Z]{3}$/).default('TZS'),
      page: z.coerce.number().int().min(1).max(10000).default(1),
    }).strict().parse(input);
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    return this.db.$transaction(async tx => {
      const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
      if (!account || account.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
      assertPlatformPermission(account.role, 'fundraising.oversight.read');
      const start = new Date(`${query.month}-01T00:00:00Z`);
      const end = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
      const where = { currency: query.currency, dueOn: { gte: start, lt: end } };
      const pledges = await tx.donationPledge.findMany({ where,
        select: { id: true, orgId: true, donorId: true, amount: true },
      });
      const payments = await tx.donation.groupBy({ by: ['pledgeId'],
        where: { currency: query.currency, status: 'RECEIVED', receivedAt: { lt: end }, pledge: where },
        _sum: { amount: true },
      });
      const paid = new Map(payments.map(p => [String(p.pledgeId), new Prisma.Decimal(p._sum.amount ?? 0)]));
      let pledged = new Prisma.Decimal(0), outstanding = new Prisma.Decimal(0);
      for (const pledge of pledges) {
        pledged = pledged.plus(pledge.amount);
        outstanding = outstanding.plus(Prisma.Decimal.max(0, pledge.amount.minus(paid.get(String(pledge.id)) ?? 0)));
      }
      const receipts = await tx.donation.aggregate({ where: { currency: query.currency, status: 'RECEIVED', receivedAt: { gte: start, lt: end } }, _sum: { amount: true } });
      const rows = await tx.donationPledge.findMany({ where, orderBy: [{ dueOn: 'desc' }, { id: 'desc' }], skip: (query.page - 1) * 10, take: 10,
        select: { id: true, donorId: true, amount: true, campaign: { select: { title: true } }, organization: { select: { name: true } } },
      });
      return { month: query.month, currency: query.currency, page: query.page, pageSize: 10, total: pledges.length,
        generatedAt: new Date().toISOString(),
        summary: { donors: new Set(pledges.map(p => `${p.orgId}:${p.donorId}`)).size,
          pledged: pledged.toFixed(2), received: new Prisma.Decimal(receipts._sum.amount ?? 0).toFixed(2), outstanding: outstanding.toFixed(2) },
        items: rows.map(row => {
          const received = paid.get(String(row.id)) ?? new Prisma.Decimal(0);
          return { id: String(row.id), donorReference: `DON-${row.donorId}`, fund: row.campaign.title,
            madrasa: row.organization.name, pledged: row.amount.toFixed(2), received: received.toFixed(2),
            status: received.gte(row.amount) ? 'Received' : received.gt(0) ? 'Partial' : 'Pending' };
        }),
      };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }
}
