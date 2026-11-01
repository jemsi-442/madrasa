import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { developmentEnvironment } from './development-config.mjs';

let browser;
let page;
let stage = 'setup';
let loginStatus;
try {
  assert.equal(process.argv.slice(2).join(' '), '--confirm-local-development');
  await developmentEnvironment(new URL('../.env', import.meta.url));
  const accounts = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/credentials.json'), 'utf8'));
  const account = accounts.find(row => row.role === 'SUPER_ADMIN');
  assert.ok(account);
  const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
  browser = await chromium.launch({ executablePath: '/usr/bin/chromium', args: ['--no-sandbox', '--force-renderer-accessibility'] });
  page = await browser.newPage({ viewport: { width: 1920, height: 1100 } });
  page.setDefaultTimeout(25000);
  const button = name => page.getByRole('button', { name, exact: true }).first();
  const errors = [];
  let writes = 0;
  page.on('pageerror', () => errors.push('page error'));
  page.on('console', message => {
    if (stage !== 'login' && /TypeError|Exception|Error:/.test(message.text())) errors.push('rendering error');
  });
  page.on('request', request => {
    if (request.url().includes('/api/platform/') && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method())) writes++;
  });
  async function reveal(locator, direction = 1) {
    for (let i = 0; i < 35; i++) {
      const box = await locator.count() ? await locator.boundingBox() : null;
      if (box && box.y >= 100 && box.y + box.height < 920) return;
      await page.mouse.move(1200, 650);
      await page.mouse.wheel(0, box ? (box.y < 100 ? -500 : 500) : 500 * direction);
      await page.waitForTimeout(150);
    }
    throw new Error('Control not visible');
  }
  const reportResponse = (directory = false) => {
    const waiting = page.waitForResponse(response => {
      const path = new URL(response.url()).pathname;
      return path.endsWith(directory ? '/curriculum/oversight/madrasas' : '/curriculum/oversight') && response.request().method() === 'GET';
    });
    waiting.catch(() => {});
    return waiting;
  };
  async function report(promise) {
    const response = await promise;
    assert.equal(response.status(), 200);
    const data = (await response.json()).data;
    for (const row of data.items ?? []) {
      if (row.eligible !== undefined) {
        assert.equal(row.recorded + row.unrecorded, row.eligible);
        assert.ok(row.needingSupport <= row.recorded);
      }
    }
    return data;
  }
  stage = 'login';
  await page.goto('http://127.0.0.1:8087/');
  const semantics = page.locator('flt-semantics-placeholder');
  await semantics.waitFor({ state: 'attached', timeout: 90000 });
  await semantics.dispatchEvent('click');
  stage = 'open login form';
  await button('Login').click();
  stage = 'fill login form';
  for (const [selector, value] of [['input[type=text]', account.login || account.email], ['input[type=password]', account.password]]) {
    await page.locator(selector).click();
    await page.keyboard.type(value, { delay: 5 });
  }
  stage = 'submit login form';
  const loginResponse = page.waitForResponse(response =>
    new URL(response.url()).pathname.endsWith('/login') &&
    response.request().method() === 'POST');
  loginResponse.catch(() => {});
  await button('Login').click();
  loginStatus = (await loginResponse).status();
  assert.equal(loginStatus, 200, 'Login must succeed before checking navigation');
  stage = 'open oversight';
  await button('Learning Oversight').waitFor();
  const initial = reportResponse();
  const directory = reportResponse(true);
  await button('Learning Oversight').click();
  const initialData = await report(initial);
  const directoryData = await report(directory);
  assert.ok(initialData.institution);
  assert.ok(directoryData.items.length, 'Demo madrasa required');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: '/tmp/afaq-learning-oversight-desktop.png' });
  stage = 'choose reporting month';
  await button('All time').click();
  await button('Oct').waitFor();
  await page.screenshot({ path: '/tmp/afaq-month-picker.png' });
  const calendarReport = reportResponse();
  const calendarDirectory = reportResponse(true);
  await button('Oct').click();
  assert.equal((await report(calendarReport)).institution.month, `${new Date().getFullYear()}-10`);
  await report(calendarDirectory);
  stage = 'review follow-ups';
  await button('Review follow-ups').click();
  await button('Show all madrasas').waitFor();
  await reveal(button('Show all madrasas'), -1);
  await button('Show all madrasas').click();
  stage = 'open madrasa';
  const madrasa = button('View →');
  await reveal(madrasa);
  await madrasa.click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/afaq-learning-oversight-detail.png' });
  await button('Close').click();
  stage = 'refresh madrasas';
  await reveal(button('Refresh madrasas'));
  const refreshed = reportResponse(true);
  await button('Refresh madrasas').click();
  assert.ok((await report(refreshed)).generatedAt);
  stage = 'apply month';
  await reveal(button('Filters & details'), -1);
  await button('Filters & details').click();
  await reveal(button('More filters'));
  await button('More filters').click();
  const month = page.getByRole('textbox', { name: "Qur'an month", exact: true }).first();
  await reveal(month, -1);
  await month.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.type('2026-10');
  await reveal(button('Apply filters'));
  const filtered = reportResponse();
  const filteredDirectory = reportResponse(true);
  await button('Apply filters').click();
  assert.equal((await report(filtered)).institution.month, '2026-10');
  assert.equal((await report(filteredDirectory)).month, '2026-10');
  stage = 'refresh report';
  await reveal(button('Refresh'));
  const refreshedReport = reportResponse();
  const refreshedDirectory = reportResponse(true);
  await button('Refresh').click();
  assert.equal((await report(refreshedReport)).institution.month, '2026-10');
  await report(refreshedDirectory);
  assert.equal(writes, 0);
  assert.equal(errors.length, 0);
  console.log('PASS: superadmin login, oversight, madrasa details, month filters and refresh; no platform writes.');
} catch {
  console.error(`FAIL: superadmin oversight browser check at ${stage}; login HTTP ${loginStatus ?? 'not received'}. No credentials or learner records logged.`);
  process.exitCode = 1;
} finally { await browser?.close(); }
