import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { developmentEnvironment } from './development-config.mjs';
import { localPreviewUrl } from './check-quran-correction-details.mjs';
import { teacherDemoSlug } from './teacher-course-demo.mjs';

// Long text is substituted only in browser responses, never persisted to demo data.
async function main() {
  const args = process.argv.slice(2);
  assert.ok(args.length === 0 || (args.length === 1 && args[0] === '--mobile'), 'Use --mobile or no arguments');
  const mobile = args[0] === '--mobile';
  const viewport = mobile ? { width: 390, height: 844 } : { width: 1440, height: 1000 };
  await developmentEnvironment(new URL('../.env', import.meta.url));
  const preview = localPreviewUrl(process.env.WEB_PREVIEW_URL || 'http://127.0.0.1:8088/');
  const account = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/teacher-credentials.json'), 'utf8'));
  assert.equal(account.email, 'quran.teacher@afaq.test');
  const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
  let browser, page;
  let stage = 'startup';
  try {
    browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium',
      args: ['--no-sandbox', '--force-renderer-accessibility'] });
    page = await browser.newPage({ viewport, isMobile: mobile, hasTouch: mobile });
    const touch = mobile ? await page.context().newCDPSession(page) : null;
    const activate = async locator => mobile ? locator.tap() : locator.click();
    page.setDefaultTimeout(60000);
    let courseId, substitutions = 0;
    await page.route('**/api/teaching/courses', async route => {
      const response = await route.fetch();
      const body = await response.json();
      courseId = body.data.find(course => course.slug === teacherDemoSlug)?.id;
      await route.fulfill({ response });
    });
    await page.route('**/api/courses/modules/*/lessons', async route => {
      const response = await route.fetch();
      const body = await response.json();
      if (courseId && Array.isArray(body.data) && body.data.length >= 2 &&
          body.data.every(lesson => String(lesson.courseId) === String(courseId))) {
        body.data = body.data.map(lesson => ({ ...lesson,
          contentText: Array(80).fill('Synthetic navigation practice only.').join('\n') }));
        substitutions++;
      }
      await route.fulfill({ response, json: body });
    });
    const button = name => page.getByRole('button', { name, exact: true }).first();
    async function reveal(locator, direction = 1) {
      for (let step = 0; step < 40; step++) {
        const box = await locator.count() ? await locator.boundingBox() : null;
        if (box && box.y >= 125 && box.y + box.height < viewport.height - 48) return step;
        if (touch) {
          // Swipe in the content gutter, away from Flutter's selectable lesson text.
          await touch.send('Input.synthesizeScrollGesture', {
            x: viewport.width - 12, y: direction > 0 ? 620 : 220, yDistance: -450 * direction, gestureSourceType: 'touch',
          });
        } else {
          await page.mouse.move(900, 600);
          await page.mouse.wheel(0, 500 * direction);
        }
        await page.waitForTimeout(150);
      }
      throw new Error('Navigation control could not be revealed');
    }
    await page.goto(preview.href);
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    stage = 'login';
    await button('Login').click();
    for (const [selector, value] of [['input[type=text]', account.email], ['input[type=password]', account.password]]) {
      await page.locator(selector).click();
      await page.waitForTimeout(300);
      await page.keyboard.type(value, { delay: 10 });
    }
    const login = page.waitForResponse(r => r.url().endsWith('/api/auth/browser/login') && r.request().method() === 'POST');
    login.catch(() => {});
    await button('Login').click();
    assert.ok((await login).ok(), 'Browser login must succeed');
    stage = 'opening My courses';
    if (mobile) await activate(button('Open navigation'));
    await activate(button('My courses'));
    console.log('PASS: demo teacher login and My courses.');
    page.setDefaultTimeout(20000);
    stage = 'course and module';
    await activate(page.getByRole('button', { name: /Teacher media practice \(Demo\)/ }));
    stage = 'module';
    await activate(page.getByRole('button', { name: /Practice the lesson player/ }));
    stage = 'lesson';
    await activate(page.getByRole('button', { name: /Video and audio practice/ }));
    assert.equal(substitutions, 1, 'Expected scoped synthetic long-lesson response');
    let writes = 0;
    page.on('request', r => { if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(r.method())) writes++; });
    for (const [action, title] of [['Next lesson', 'Document practice'], ['Previous lesson', 'Video and audio practice']]) {
      stage = action;
      let scrolled = 0;
      for (; scrolled < 40; scrolled++) {
        const box = await button(action).count() ? await button(action).boundingBox() : null;
        if (box && box.y >= 0 && box.y + box.height < viewport.height - 48) break;
        if (touch) {
          await touch.send('Input.synthesizeScrollGesture', {
            x: 230, y: 620, yDistance: -450, gestureSourceType: 'touch',
          });
        } else {
          await page.mouse.move(900, 600);
          await page.mouse.wheel(0, 500);
        }
        await page.waitForTimeout(150);
      }
      assert.ok(scrolled > 0 && scrolled < 40, 'Long lesson must require scrolling');
      await activate(button(action));
      const heading = page.getByRole('heading', { name: new RegExp(title) });
      await heading.waitFor();
      await page.waitForTimeout(500);
      const box = await heading.boundingBox();
      assert.ok(box && box.y >= 0 && box.y + box.height < viewport.height - 48 &&
        box.x >= 0 && box.x + box.width <= viewport.width, 'New lesson heading must be on screen');
    }
    for (const [choice, endpoint] of [
      ['Cancel', null],
      ["Qur'an practice", '/api/teacher-workspace/quran/catalog'],
      ['Other subject results', '/api/assessments/options'],
    ]) {
      stage = `results chooser: ${choice}`;
      await reveal(button('Record lesson results'));
      await activate(button('Record lesson results'));
      await button('Cancel').waitFor();
      const target = page.getByRole('button', { name: new RegExp(choice) });
      const response = endpoint ? page.waitForResponse(r => new URL(r.url()).pathname === endpoint && r.request().method() === 'GET') : null;
      response?.catch(() => {});
      await activate(target);
      await button('Cancel').waitFor({ state: 'detached' });
      if (response) {
        assert.ok((await response).ok(), 'Destination must load authorized data');
        stage = `return from ${choice}`;
        const lessonsLoaded = page.waitForResponse(r => /\/api\/courses\/modules\/[^/]+\/lessons$/.test(new URL(r.url()).pathname));
        lessonsLoaded.catch(() => {});
        await activate(button('Back'));
        assert.ok((await lessonsLoaded).ok(), 'Return must recheck lesson access');
        console.log('PASS: returned lesson access rechecked.');
      }
      const heading = page.getByRole('heading', { name: /Video and audio practice/ });
      if (response) {
        await heading.waitFor();
        await page.waitForTimeout(500);
        const box = await heading.boundingBox();
        assert.ok(box && box.y >= 100 && box.y + box.height < viewport.height - 48,
          'Returning from records must reveal the lesson heading without manual scrolling');
      } else {
        await reveal(heading, -1);
      }
      assert.equal(writes, 0, 'Chooser, cancel and return must not save results');
    }
    stage = 'returning to courses';
    await activate(button('Module lessons'));
    await page.getByRole('button', { name: /Video and audio practice/ }).waitFor();
    await activate(button('Course modules'));
    await page.getByRole('button', { name: /Practice the lesson player/ }).waitFor();
    await activate(button('All my courses'));
    await page.getByRole('button', { name: /Teacher media practice \(Demo\)/ }).waitFor();
    assert.equal(writes, 0, 'Lesson navigation must not record progress');
    console.log(`PASS: ${mobile ? 'mobile Chromium emulation (390 x 844)' : 'desktop'} course navigation, results chooser/cancel, both record destinations and lesson return; no writes.`);
  } catch {
    console.error(`FAIL: teacher course navigation at ${stage}.`);
    if (page && process.env.NAVIGATION_CHECK_SCREENSHOT) await page.screenshot({ path: process.env.NAVIGATION_CHECK_SCREENSHOT }).catch(() => {});
    process.exitCode = 1;
  } finally {
    try {
      if (page) {
        const result = await page.context().request.post('http://127.0.0.1:4000/api/auth/browser/logout', {
          headers: { Origin: preview.origin, 'X-MIF-Browser': '1' }, data: {}, timeout: 10000,
        });
        assert.ok(result.ok(), 'Test browser session logout must succeed');
      }
    } finally { await browser?.close(); }
  }
}

main().catch(() => {
  console.error('Navigation check could not start or clean up; verify local services and browser dependencies.');
  process.exitCode = 1;
});
