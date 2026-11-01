import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { developmentEnvironment } from './development-config.mjs';
import { localPreviewUrl } from './check-quran-correction-details.mjs';

async function main() {
  const args = process.argv.slice(2);
  assert.ok(args.join(' ') === '--confirm-local-development' || args.join(' ') === '--confirm-local-development --mobile');
  const mobile = args.includes('--mobile');
  const viewport = mobile ? { width: 390, height: 844 } : { width: 1600, height: 1100 };
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const preview = localPreviewUrl(process.env.WEB_PREVIEW_URL);
  for (const url of [preview.href, 'http://127.0.0.1:4000/api/health']) {
    assert.ok((await fetch(url, { signal: AbortSignal.timeout(5000) })).ok);
  }
  const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
  const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
  let org, browser, page, stage = 'setup';
  const renderErrors = [];
  try {
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam' }).format(new Date());
    const day = new Date(today);
    const email = `period-${randomUUID()}@afaq.test`, password = `${randomUUID()}!Aa9`;
    org = await db.organization.create({ data: { name: 'Synthetic period browser check', code: randomUUID() } });
    const branch = await db.branch.create({ data: { orgId: org.id, name: 'Synthetic campus' } });
    const teacher = await db.user.create({ data: { orgId: org.id, branchId: branch.id,
      fullName: 'Synthetic Period Teacher', email, passwordHash: await bcrypt.hash(password, 12), role: 'TEACHER' } });
    const group = await db.class.create({ data: { orgId: org.id, branchId: branch.id, teacherId: teacher.id,
      name: 'Synthetic Period Class', level: 'One', academicYear: String(day.getUTCFullYear()) } });
    const learners = [];
    for (const suffix of ['A', 'B']) learners.push(await db.student.create({ data: {
      orgId: org.id, branchId: branch.id, classId: group.id,
      fullName: `Synthetic Learner ${suffix}`, admissionNo: `PERIOD-${suffix}`, joinedOn: day,
    } }));
    const slot = await db.classTimetableSlot.create({ data: { orgId: org.id, classId: group.id,
      createdById: teacher.id, weekday: day.getUTCDay() || 7, startsAt: '08:00', endsAt: '08:45',
      validFrom: day, validUntil: day, subject: 'Synthetic Quran practice' } });
    browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium',
      args: ['--no-sandbox', '--force-renderer-accessibility'] });
    page = await browser.newPage({ viewport, isMobile: mobile, hasTouch: mobile });
    const touch = mobile ? await page.context().newCDPSession(page) : null;
    const activate = locator => mobile ? locator.tap() : locator.click();
    page.on('console', message => {
      if (stage !== 'login' && /TypeError|Exception|Error:/.test(message.text())) renderErrors.push(message.text());
    });
    page.setDefaultTimeout(20000);
    const button = name => page.getByRole('button', { name, exact: true }).first();
    async function reveal(locator, direction = 1) {
      for (let i = 0; i < 45; i++) {
        const box = await locator.count() ? await locator.boundingBox() : null;
        if (box && box.y >= 130 && box.y + box.height < viewport.height - 60) {
          if (box.x >= 0 && box.x + box.width <= viewport.width) return;
          if (touch) {
            await touch.send('Input.synthesizeScrollGesture', { x: viewport.width - 50,
              y: box.y + box.height / 2, xDistance: box.x < 0 ? 250 : -250, gestureSourceType: 'touch' });
          } else {
            await page.mouse.move(viewport.width - 80, box.y + box.height / 2);
            await page.mouse.wheel(box.x < 0 ? -350 : 350, 0);
          }
        } else {
          const move = box ? (box.y < 130 ? -1 : 1) : (i < 25 ? direction : -direction);
          if (touch) {
            await touch.send('Input.synthesizeScrollGesture', { x: viewport.width - 12,
              y: move > 0 ? 620 : 220, yDistance: -450 * move, gestureSourceType: 'touch' });
          } else {
            await page.mouse.move(1100, 650);
            await page.mouse.wheel(0, 450 * move);
          }
        }
        await page.waitForTimeout(150);
      }
      throw new Error('Cannot reveal control');
    }
    async function click(name, direction = 1) {
      await reveal(button(name), direction);
      await activate(button(name));
    }
    const waitApi = (path, method = 'GET') => {
      const waiting = page.waitForResponse(r => r.url().includes(path) && r.request().method() === method);
      waiting.catch(() => {});
      return waiting;
    };
    stage = 'login';
    await page.goto(preview.href);
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 90000 });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await button('Login').click();
    for (const [selector, value] of [['input[type=text]', email], ['input[type=password]', password]]) {
      await page.locator(selector).click();
      await page.waitForTimeout(300);
      await page.keyboard.type(value, { delay: 5 });
    }
    const login = waitApi('/api/auth/browser/login', 'POST');
    await button('Login').click();
    assert.ok((await login).ok());
    await button(mobile ? 'Open navigation' : 'Dashboard').waitFor();
    let writes = 0;
    page.on('request', r => { if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(r.method())) writes++; });
    stage = 'open timetable period';
    await click("Record Qur'an");
    await click('Choose a student');
    await activate(page.getByRole('button', { name: /Synthetic Learner A/ }));
    console.log('PASS: timetable opens the class without another class selection.');
    stage = 'select passage';
    for (const ayah of [11, 15]) {
      const target = button(String(ayah));
      await reveal(target);
      await activate(target);
    }
    stage = 'skip learner A';
    await reveal(button('Skip for now'));
    const skip = waitApi('/quran/roster?');
    await activate(button('Skip for now'));
    await activate(button('Leave session'));
    const skipped = await (await skip).json();
    assert.equal(skipped.data.remaining, 2);
    assert.equal(skipped.data.nextStudent.id, String(learners[1].id));
    assert.equal(writes, 0);
    assert.equal(await db.quranSession.count({ where: { orgId: org.id } }), 0);
    console.log('PASS: skip advances to learner B; no result or absence written.');
    async function observeAndSave(observation) {
      const dropdown = page.getByRole('button', { name: /Teacher observation/ }).first();
      await reveal(dropdown);
      await activate(dropdown);
      if (mobile) {
        await page.getByRole('menuitem', { name: observation === 'NEEDS_PRACTICE' ? 'Needs more practice' : 'Independent', exact: true }).tap();
      } else {
        await page.keyboard.press('Home');
        if (observation === 'NEEDS_PRACTICE') {
          await page.keyboard.press('ArrowDown');
          await page.keyboard.press('ArrowDown');
        }
        await page.keyboard.press('Enter');
      }
      await reveal(button('Save progress'));
      const save = waitApi('/quran/sessions', 'POST');
      await activate(button('Save progress'));
      const response = await save;
      assert.ok(response.ok());
      const payload = response.request().postDataJSON();
      assert.equal(payload.observation, observation);
      assert.equal(payload.timetableSlotId, String(slot.id));
      assert.equal(payload.learnedOn, today);
      assert.equal(payload.ayahFrom, 11);
      assert.equal(payload.ayahTo, 15);
    }
    stage = 'save learner B';
    await observeAndSave('NEEDS_PRACTICE');
    let records = await db.quranSession.findMany({ where: { orgId: org.id } });
    assert.equal(records.length, 1);
    assert.equal(records[0].studentId, learners[1].id);
    stage = 'review skipped learner A';
    await click('Review skipped students', -1);
    stage = 'save learner A';
    await observeAndSave('INDEPENDENT');
    assert.equal(writes, 2);
    records = await db.quranSession.findMany({ where: { orgId: org.id } });
    assert.equal(records.length, 2);
    assert.equal(new Set(records.map(r => String(r.studentId))).size, 2);
    console.log('PASS: both learners saved separately with individual observations and the timetable period.');
    stage = 'period summary';
    await reveal(button('Period summary'), -1);
    const summary = page.waitForResponse(r => r.url().includes('/quran/roster?') && new URL(r.url()).searchParams.get('summary') === 'true');
    summary.catch(() => {});
    await activate(button('Period summary'));
    const summaryData = (await (await summary).json()).data;
    assert.equal(summaryData.recorded, 2);
    assert.equal(summaryData.remaining, 0);
    assert.equal(summaryData.needsSupport, 1);
    await page.getByText('2 recorded / 2 students | 0 remaining', { exact: true }).first().waitFor();
    await page.getByText('1 student has at least one saved observation needing support in this period.', { exact: true }).waitFor();
    if (process.env.PERIOD_CHECK_SUCCESS_SCREENSHOT) await page.screenshot({ path: process.env.PERIOD_CHECK_SUCCESS_SCREENSHOT });
    stage = 'summary opens saved history';
    const history = waitApi('/teacher-workspace/quran?');
    await activate(page.getByRole('button', { name: /Synthetic Learner B/ }));
    const historyData = (await (await history).json()).data;
    assert.equal(historyData.student.id, String(learners[1].id));
    assert.ok(historyData.sessions.some(s => s.timetableSlotId === String(slot.id) && s.observation === 'NEEDS_PRACTICE'));
    const historyRecord = button('Correct this record').first();
    await historyRecord.waitFor();
    // Wait for Flutter's post-frame scroll animation, without scrolling in the test.
    let historyVisible = false;
    for (let attempt = 0; attempt < 40; attempt++) {
      const bounds = await historyRecord.boundingBox();
      if (bounds && bounds.height > 0 && bounds.y >= 0 &&
          bounds.y + bounds.height < page.viewportSize().height) {
        historyVisible = true;
        break;
      }
      await page.waitForTimeout(100);
    }
    assert.ok(historyVisible, 'Learning history is visible without manual scrolling');
    if (mobile) {
      const bounds = await historyRecord.boundingBox();
      assert.ok(bounds && bounds.x >= 0 &&
        bounds.x + bounds.width <= page.viewportSize().width,
      'Mobile correction action fits without horizontal scrolling');
    }
    if (process.env.PERIOD_CHECK_HISTORY_SCREENSHOT) {
      await page.screenshot({ path: process.env.PERIOD_CHECK_HISTORY_SCREENSHOT });
    }
    console.log('PASS: opening a learner from the summary reveals learning history without manual scrolling.');
    assert.equal(writes, 2);
    stage = 'reload and verify persistence';
    await page.reload();
    const placeholder = page.locator('flt-semantics-placeholder');
    await page.waitForTimeout(1500);
    if (await placeholder.count()) await placeholder.dispatchEvent('click');
    if (mobile) await activate(button('Open navigation'));
    await activate(button("Qur'an Tracking"));
    await activate(page.getByRole('button', { name: /Choose a class/ }));
    if (mobile) {
      await page.getByRole('menuitem', { name: 'Synthetic Period Class', exact: true }).tap();
    } else {
      await page.keyboard.press('Home');
      await page.keyboard.press('Enter');
    }
    await activate(button('Choose a student'));
    const restoredHistory = waitApi('/teacher-workspace/quran?');
    await activate(page.getByRole('button', { name: /Synthetic Learner B/ }));
    const restored = (await (await restoredHistory).json()).data;
    assert.equal(restored.student.id, String(learners[1].id));
    assert.ok(restored.sessions.some(s => s.timetableSlotId === String(slot.id) && s.observation === 'NEEDS_PRACTICE'));
    const persisted = await db.quranSession.findMany({ where: { orgId: org.id } });
    assert.equal(persisted.length, 2);
    assert.ok(persisted.every(r => r.timetableSlotId === slot.id && r.voidedAt === null));
    assert.equal(renderErrors.length, 0, 'No Flutter rendering exceptions during the journey');
    console.log(`PASS (${mobile ? 'mobile browser emulation' : 'desktop'}): summary reports 2 recorded, 0 remaining, 1 needing support; history and stored records verified.`);
  } catch (error) {
    if (error?.code === 'ERR_ASSERTION' && stage !== 'login') console.error(error.message);
    console.error('Rendering exceptions:', renderErrors);
    if (page && process.env.PERIOD_CHECK_SCREENSHOT) await page.screenshot({ path: process.env.PERIOD_CHECK_SCREENSHOT }).catch(() => {});
    if (page && stage !== 'login') {
      console.log('Visible controls:', await page.getByRole('button').allTextContents().catch(() => []));
    }
    console.error(`FAIL: teacher period browser check at ${stage}.`);
    process.exitCode = 1;
  } finally {
    await browser?.close();
    try {
      if (org) {
        const where = { orgId: org.id };
        await db.$transaction(async tx => {
          await tx.quranSession.deleteMany({ where });
          await tx.classTimetableSlot.deleteMany({ where });
          await tx.refreshToken.deleteMany({ where });
          await tx.auditLog.deleteMany({ where });
          await tx.student.deleteMany({ where });
          await tx.class.deleteMany({ where });
          await tx.user.deleteMany({ where });
          await tx.branch.deleteMany({ where });
          await tx.organization.delete({ where: { id: org.id } });
        });
        console.log('Synthetic fixture removed; existing demo data and credentials preserved.');
      }
    } finally { await db.$disconnect(); }
  }
}

main().catch(() => {
  console.error('Could not start or clean up the local browser check.');
  process.exitCode = 1;
});
