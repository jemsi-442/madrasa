import type { PrismaClient } from '@prisma/client';
import { manualSmsReady } from '../modules/platform/platform.donor-messages';
import { smsPhone, type SmsResult } from '../shared/notifications/meseji-sms';
import { sendSms, smsConfig, type SmsConfig } from '../shared/notifications/sms-provider';
type Sender = (config: SmsConfig, phone: string, body: string) => Promise<SmsResult>;
export async function processManualDonorSms(db: PrismaClient, config: SmsConfig, send: Sender = sendSms) {
  await db.donorMessageRecipient.updateMany({ where: { status: 'SENDING', updatedAt: { lt: new Date(Date.now() - 300000) } }, data: { status: 'UNKNOWN', reason: 'WORKER_INTERRUPTED' } });
  const jobs = await db.donorMessageRecipient.findMany({ where: { status: 'PENDING' }, orderBy: { id: 'asc' }, take: 20 });
  for (const job of jobs) {
    const claim = await db.donorMessageRecipient.updateMany({ where: { id: job.id, status: 'PENDING' }, data: { status: 'SENDING' } });
    if (!claim.count) continue;
    const current = await db.donorMessageRecipient.findUniqueOrThrow({ where: { id: job.id }, include: { message: true, donor: { include: { organization: { select: { status: true } } } } } });
    const author = await db.platformAccount.findUnique({ where: { id: current.message.creatorId }, select: { role: true, status: true } });
    const reason = author?.role !== 'SUPER_ADMIN' || author.status !== 'ACTIVE' ? 'SENDER_ACCESS_REVOKED'
      : !current.donor.smsOptIn ? 'CONSENT_WITHDRAWN'
      : current.donor.organization.status !== 'ACTIVE' ? 'MADRASA_INACTIVE'
      : smsPhone(current.donor.phone) !== job.phone ? 'PHONE_CHANGED'
      : current.message.status !== 'QUEUED' ? 'MESSAGE_NOT_QUEUED'
      : !current.message.queuedAt || current.message.queuedAt.getTime() < Date.now() - 86400000 ? 'STALE_NOTIFICATION' : null;
    if (reason) {
      await db.donorMessageRecipient.update({ where: { id: job.id }, data: { status: 'SKIPPED', reason } });
      continue;
    }
    const result = await send({ ...config, idempotencyKey: `afaq-manual-${current.message.id}-${job.id}` }, job.phone, current.message.body);
    await db.donorMessageRecipient.update({ where: { id: job.id }, data: { status: result.status, batchId: result.batchId ?? null, reason: result.reason ?? null } });
  }
}
export function startManualDonorSmsWorker(db: PrismaClient) {
  if (!manualSmsReady()) return;
  const config = smsConfig();
  if (!config) return;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await processManualDonorSms(db, config); }
    catch { console.error('[manual-donor-sms] Queue processing failed.'); }
    finally { running = false; }
  };
  setInterval(() => { void tick(); }, 30000).unref();
  void tick();
}
