import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { developmentEnvironment } from './development-config.mjs';
import { DonorMessagesService } from '../src/modules/platform/platform.donor-messages.ts';

// All synthetic records and queue entries are rolled back. No SMS adapter is called.
assert.equal(process.argv.slice(2).join(' '), '--confirm-local-development');
const env = await developmentEnvironment(new URL('../.env', import.meta.url));
const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
const rollback = new Error('Synthetic check rollback');
Object.assign(process.env, { SMS_ENABLED: 'true', DONOR_MANUAL_SMS_ENABLED: 'true',
  SMS_PROVIDER: 'meseji', MESEJI_API_KEY: 'synthetic-not-used', MESEJI_SENDER_ID: 'AFAQ' });
try {
  await db.$transaction(async tx => {
    const tag = randomUUID().slice(0, 12);
    const account = await tx.platformAccount.create({ data: { fullName: 'Synthetic sender', email: `sms-${tag}@example.test`, passwordHash: 'not-a-login', role: 'SUPER_ADMIN', status: 'ACTIVE' } });
    const org = await tx.organization.create({ data: { code: `SMS-${tag}`, name: 'Synthetic messaging test' } });
    const donor = await tx.donor.create({ data: { orgId: org.id, fullName: 'Synthetic donor', phone: '255700000000' } });
    const actor = { scope: 'platform', accountId: account.id, sessionId: 'synthetic' };
    const service = new DonorMessagesService({ $transaction: fn => fn(tx) });
    await service.consent(actor, String(donor.id), { optedIn: true, note: 'Synthetic test consent only' });
    const draft = await service.save(actor, { body: 'Synthetic text - never sent', donorIds: [String(donor.id)] });
    assert.equal(draft.recipients.length, 1);
    await service.send(actor, draft.id, { revision: draft.revision });
    await service.send(actor, draft.id, { revision: draft.revision });
    assert.equal(await tx.donorMessageRecipient.count({ where: { messageId: draft.id, status: 'PENDING' } }), 1);
    const history = await service.list(actor, { tab: 'sent' });
    assert.equal(history.items[0].body, 'Synthetic text - never sent');
    assert.equal(history.items[0].recipients[0].phone, '255700000000');
    await assert.rejects(service.save(actor, { id: draft.id, revision: draft.revision, body: 'Overwrite', donorIds: [] }));
    throw rollback;
  }, { timeout: 15000 });
} catch (error) {
  if (error !== rollback) {
    console.error('FAIL: manual donor messaging database check. No credentials or donor records logged.');
    process.exitCode = 1;
  } else {
    console.log('PASS: consent, draft, queue idempotency, immutable history; synthetic changes rolled back. No SMS sent.');
  }
} finally { await db.$disconnect(); }
