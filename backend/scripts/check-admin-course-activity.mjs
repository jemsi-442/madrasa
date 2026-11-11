import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { developmentEnvironment } from './development-config.mjs';
import { localPreviewUrl } from './check-quran-correction-details.mjs';

// Uses only synthetic records in the existing local development database.
// Does not migrate, seed, reset, or stop either running server.
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
    org = await db.organization.create({ data: { name: 'Synthetic activity check', code: randomUUID() } });
    const orgId = org.id;
    const branch = await db.branch.create({ data: { orgId, name: 'Synthetic campus' } });
    const admin = await db.user.create({ data: {
      orgId, branchId: branch.id, fullName: 'Synthetic Admin', email,
      passwordHash: await bcrypt.hash(password, 12), role: 'ADMIN',
    } });
    const account = await db.user.create({ data: {
      orgId, branchId: branch.id, fullName: 'Synthetic learner account',
      passwordHash: 'not-a-login', role: 'LEARNER',
    } });
    const student = await db.student.create({ data: {
      orgId, branchId: branch.id, fullName: 'Synthetic Activity Learner',
      admissionNo: 'ACTIVITY-CHECK', learnerUserId: account.id,
    } });
    const subject = await db.subject.create({ data: { orgId, name: 'Synthetic subject', code: 'CHECK' } });
    const course = await db.course.create({ data: {
      orgId, subjectId: subject.id, slug: 'activity-check', title: 'Synthetic course', summary: 'Browser test only',
      createdByUserId: admin.id, publicationStatus: 'PUBLISHED', programCategory: 'MADRASA_CHILD',
    } });
    const module = await db.courseModule.create({ data: { orgId, courseId: course.id, title: 'Synthetic module', position: 1 } });
    const progress = [];
    for (let i = 0; i < 3; i++) {
      const lesson = await db.courseLesson.create({ data: {
        orgId, courseId: course.id, moduleId: module.id, title: `Synthetic lesson ${i + 1}`,
        slug: `lesson-${i}`, position: i + 1, publicationStatus: i === 2 ? 'DRAFT' : 'PUBLISHED',
      } });
      progress.push(await db.courseLessonProgress.create({ data: {
        orgId, courseId: course.id, lessonId: lesson.id, studentId: student.id, learnerUserId: account.id,
        progressPercent: i === 0 ? 35 : 100,
      } }));
    }
    browser = await chromium.launch({
      executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true,
      args: ['--no-sandbox', '--force-renderer-accessibility'],
    });
    page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    page.setDefaultTimeout(300000);
    const button = name => page.getByRole('button', { name, exact: true }).first();
    stage = 'web startup';
    console.log('CHECK: waiting for the local Flutter preview.');
    await page.goto(preview.href, { waitUntil: 'domcontentloaded' });
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
    await page.locator('flt-semantics-placeholder').evaluateAll(nodes => nodes.forEach(node =>
      node.dispatchEvent(new MouseEvent('click', { bubbles: true }))));
    stage = 'admin login';
    console.log('CHECK: signing in with the synthetic admin.');
    await button('Login').click();
    for (const [selector, value] of [['input[type=text]', email], ['input[type=password]', password]]) {
      await page.locator(selector).click();
      await page.waitForTimeout(300);
      await page.keyboard.type(value, { delay: 10 });
    }
    await button('Login').click();
    await button('Students').click();
    page.setDefaultTimeout(25000);
    console.log('PASS: synthetic admin login and student directory.');
    let writes = 0;
    await page.route('**/api/**', async route => {
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(route.request().method())) {
        writes++;
        await route.abort();
      } else await route.continue();
    });
    const openActivity = async completed => {
      await button('Manage Synthetic Activity Learner').click();
      const [result] = await Promise.all([
        page.waitForResponse(r => r.url().endsWith(`/api/admin/students/${student.id}/course-progress`)),
        page.getByRole('menuitem', { name: 'Course activity', exact: true }).click(),
      ]);
      assert.equal(result.status(), 200);
      assert.match(result.headers()['cache-control'], /no-store/);
      const { data } = await result.json();
      assert.equal(data.student.id, String(student.id));
      assert.equal(data.courseProgress.trackedLessons, 2);
      assert.equal(data.courseProgress.completedLessons, completed);
      assert.equal(data.courseProgress.recent.length, 2);
      await page.getByText('Latest 2 of 2 recorded lessons', { exact: true }).waitFor();
      await page.getByText('Synthetic lesson 1', { exact: true }).waitFor();
      assert.equal(await page.getByText('Synthetic lesson 3', { exact: true }).count(), 0);
    };
    stage = 'opening read-only activity';
    await openActivity(1);
    await page.getByText('35% reported', { exact: true }).waitFor();
    if (process.env.ACTIVITY_CHECK_SCREENSHOT) {
      await page.screenshot({ path: process.env.ACTIVITY_CHECK_SCREENSHOT });
    }
    await button('Close').click();
    assert.deepEqual(await db.courseLessonProgress.findMany({ where: { orgId }, orderBy: { id: 'asc' } }), progress);
    console.log('PASS: published lesson counts match API; draft lesson hidden; reading preserves progress.');
    stage = 'reopening after a synthetic progress update';
    await db.courseLessonProgress.update({ where: { id: progress[0].id }, data: { progressPercent: 100, completedAt: new Date() } });
    await openActivity(2);
    assert.equal(await page.getByText('35% reported', { exact: true }).count(), 0);
    stage = 'narrow-screen dialog';
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(500);
    const closeBounds = await button('Close').boundingBox();
    assert.ok(closeBounds && closeBounds.x >= 0 && closeBounds.x + closeBounds.width <= 390);
    await button('Close').click();
    assert.equal(writes, 0, 'Reading activity must not submit writes');
    console.log('PASS: reopening reads fresh progress; narrow-screen Close remains accessible; no UI writes.');
  } catch {
    if (page && process.env.ACTIVITY_CHECK_SCREENSHOT) {
      await page.screenshot({ path: process.env.ACTIVITY_CHECK_SCREENSHOT }).catch(() => {});
    }
    // Never dump authentication payloads or database connection strings.
    console.error(`FAIL: admin course activity check at ${stage}.`);
    process.exitCode = 1;
  } finally {
    try { await browser?.close(); }
    finally {
      try {
        if (org) {
          const where = { orgId: org.id };
          await db.$transaction(async tx => {
            await tx.courseLessonProgress.deleteMany({ where });
            await tx.courseLesson.deleteMany({ where });
            await tx.courseModule.deleteMany({ where });
            await tx.course.deleteMany({ where });
            await tx.subject.deleteMany({ where });
            await tx.refreshToken.deleteMany({ where });
            await tx.auditLog.deleteMany({ where });
            await tx.student.deleteMany({ where });
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
