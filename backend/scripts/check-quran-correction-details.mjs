import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { developmentEnvironment } from './development-config.mjs';

export function localPreviewUrl(value = 'http://127.0.0.1:8087/') {
  const preview = new URL(value);
  if (preview.protocol !== 'http:' || preview.hostname !== '127.0.0.1' ||
      preview.username || preview.password || preview.pathname !== '/' ||
      preview.search || preview.hash) {
    throw new Error('WEB_PREVIEW_URL must be a local loopback HTTP origin.');
  }
  return preview;
}

// This check uses a synthetic, already-voided fixture; it does not test the void API.
async function main() {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') {
    throw new Error('Explicit local-development confirmation required.');
  }
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const preview = localPreviewUrl(process.env.WEB_PREVIEW_URL);
  const require = createRequire(import.meta.url);
  const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
  for (const url of ['http://127.0.0.1:4000/api/health', preview.href]) {
    const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new Error('Start the local API and web preview first.');
  }
  const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
  let org, browser, page;
  let stage = 'fixture setup';
  try {
    const password = `${randomUUID()}!Aa9`;
    const email = `browser-${randomUUID()}@afaq.test`;
    org = await db.organization.create({ data: { name: 'Synthetic correction check', code: randomUUID() } });
    const branch = await db.branch.create({ data: { orgId: org.id, name: 'Synthetic campus' } });
    const teacher = await db.user.create({ data: {
      orgId: org.id, branchId: branch.id, fullName: 'Synthetic Teacher', email,
      passwordHash: await bcrypt.hash(password, 12), role: 'TEACHER',
    } });
    const group = await db.class.create({ data: {
      orgId: org.id, branchId: branch.id, teacherId: teacher.id,
      name: 'Synthetic Class', level: 'One', academicYear: '2026',
    } });
    const learner = await db.student.create({ data: {
      orgId: org.id, branchId: branch.id, classId: group.id,
      fullName: 'Synthetic Learner', admissionNo: 'CORRECTION-TEST',
    } });
    const reason = 'Synthetic correction: the selected passage was incorrect.';
    const record = await db.quranSession.create({ data: {
      orgId: org.id, classId: group.id, studentId: learner.id, teacherId: teacher.id,
      clientId: randomUUID(), requestHash: '0'.repeat(64), surahId: 67, ayahFrom: 11, ayahTo: 15,
      activity: 'MEMORIZATION', observation: 'INDEPENDENT', learnedOn: new Date('2026-09-01'),
      voidedAt: new Date('2026-09-02T10:00:00Z'), voidReason: reason,
    } });
    browser = await chromium.launch({
      executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true,
      args: ['--no-sandbox', '--force-renderer-accessibility'],
    });
    page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    page.setDefaultTimeout(180000);
    const button = name => page.getByRole('button', { name, exact: true }).first();
    stage = 'web startup';
    await page.goto(preview.href, { waitUntil: 'domcontentloaded' });
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
    await page.locator('flt-semantics-placeholder').evaluateAll(nodes => nodes.forEach(node =>
      node.dispatchEvent(new MouseEvent('click', { bubbles: true }))));
    stage = 'teacher login';
    await button('Login').click();
    for (const [selector, value] of [['input[type=text]', email], ['input[type=password]', password]]) {
      await page.locator(selector).click();
      await page.waitForTimeout(300);
      await page.keyboard.type(value, { delay: 10 });
    }
    await button('Login').click();
    await button("Qur'an Tracking").click();
    console.log('PASS: synthetic teacher login.');
    page.setDefaultTimeout(20000);
    stage = 'learner selection';
    await page.getByRole('button', { name: /Choose a class/ }).click();
    await page.keyboard.press('Home');
    await page.keyboard.press('Enter');
    await button('Choose a student').click();
    await page.getByRole('button', { name: /Synthetic Learner/ }).click();
    stage = 'correction details';
    const details = button('View correction details');
    for (let n = 0; n < 12 && !(await details.count()); n++) {
      await page.mouse.move(700, 600);
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(300);
    }
    let writes = 0;
    page.on('request', request => {
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method())) writes++;
    });
    await details.click();
    stage = 'copying read-only details';
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: preview.origin });
    await button('Copy details').click();
    const labels = ['Learning record correction', 'Surah 67 | 11-15', 'Independent', reason];
    await page.waitForFunction(async expected => {
      const copied = await navigator.clipboard.readText();
      return expected.every(label => copied.includes(label));
    }, labels);
    assert.equal(await button('Void this entry').count(), 0);
    stage = 'closing read-only details';
    await button('Close').click();
    await details.waitFor();
    assert.equal(writes, 0, 'Opening/closing details must not send writes');
    assert.deepEqual(await db.quranSession.findUniqueOrThrow({ where: { id: record.id } }), record);
    console.log('PASS: read-only correction details show passage, original observation and reason; no writes.');
  } catch {
    if (page && process.env.CORRECTION_CHECK_SCREENSHOT) {
      await page.screenshot({ path: process.env.CORRECTION_CHECK_SCREENSHOT }).catch(() => {});
    }
    // Do not print browser/login payloads, credentials or database connection strings.
    console.error(`FAIL: correction details check at ${stage}.`);
    process.exitCode = 1;
  } finally {
    try { await browser?.close(); }
    finally {
      try {
        if (org) {
          const where = { orgId: org.id };
          await db.$transaction(async tx => {
            await tx.quranSession.deleteMany({ where });
            await tx.refreshToken.deleteMany({ where });
            await tx.auditLog.deleteMany({ where });
            await tx.student.deleteMany({ where });
            await tx.class.deleteMany({ where });
            await tx.user.deleteMany({ where });
            await tx.branch.deleteMany({ where });
            await tx.organization.delete({ where: { id: org.id } });
          });
          console.log('Synthetic fixture removed; existing demo records preserved.');
        }
      } finally { await db.$disconnect(); }
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main().catch(() => {
  console.error('Check could not start or clean up. Verify local services, browser dependencies and development configuration.');
  process.exitCode = 1;
});
