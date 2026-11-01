import type { PrismaClient } from '@prisma/client';
import { smsPhone, type SmsResult } from '../shared/notifications/meseji-sms';
import { sendSms, smsConfig, type SmsConfig } from '../shared/notifications/sms-provider';

type Sender = (config: SmsConfig, phone: string, message: string) => Promise<SmsResult>;
export function donationThanks(amount: string, currency: string, id: bigint): string {
  return `Afaq: Asante kwa mchango wako wa ${currency} ${amount}. Kumbukumbu: DON-${String(id).padStart(8, '0')}.`;
}

export async function processDonationSms(db: PrismaClient, config: SmsConfig, send: Sender = sendSms) {
  // A crash after sending may leave SENDING; never blindly resend it.
  await db.donationSms.updateMany({ where: { status: 'SENDING', updatedAt: { lt: new Date(Date.now() - 300000) } },
    data: { status: 'UNKNOWN', reason: 'WORKER_INTERRUPTED' } });
  const jobs = await db.donationSms.findMany({ where: { status: 'PENDING' }, orderBy: { id: 'asc' }, take: 20 });
  for (const job of jobs) {
    const claim = await db.donationSms.updateMany({ where: { id: job.id, status: 'PENDING' }, data: { status: 'SENDING' } });
    if (!claim.count) continue;
    const donation = await db.donation.findUnique({ where: { id: job.donationId },
      include: { donor: true, organization: { select: { status: true } } } });
    const phone = smsPhone(donation?.donor.phone ?? null);
    const reason = !donation || donation.status !== 'RECEIVED' ? 'DONATION_VOIDED'
      : donation.organization.status !== 'ACTIVE' ? 'MADRASA_INACTIVE'
      : !phone ? 'PHONE_UNAVAILABLE'
      : job.createdAt.getTime() < Date.now() - 86400000 ? 'STALE_NOTIFICATION' : null;
    if (reason) {
      await db.donationSms.update({ where: { id: job.id }, data: { status: 'SKIPPED', reason } });
      continue;
    }
    const result = await send({ ...config, idempotencyKey: `afaq-receipt-${job.id}-${job.createdAt.getTime()}` }, phone!, donationThanks(donation!.amount.toFixed(2), donation!.currency, donation!.id));
    await db.donationSms.update({ where: { id: job.id }, data: {
      status: result.status, batchId: result.batchId ?? null, reason: result.reason ?? null,
    } });
  }
}

export function startDonationSmsWorker(db: PrismaClient): () => void {
  if (process.env.SMS_ENABLED !== 'true' || process.env.DONATION_SMS_ENABLED !== 'true') return () => {};
  const config = smsConfig();
  if (!config) {
    console.error('[donation-sms] Worker disabled: incomplete SMS configuration.');
    return () => {};
  }
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await processDonationSms(db, config); }
    catch { console.error('[donation-sms] Queue processing failed; inspect database availability.'); }
    finally { running = false; }
  };
  const timer = setInterval(() => { void tick(); }, 30000);
  timer.unref();
  void tick();
  return () => clearInterval(timer);
}
