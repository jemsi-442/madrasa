import assert from 'node:assert/strict';
import { readFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { developmentEnvironment } from './development-config.mjs';

// Local, read-only browser inspection. Never log account data or response bodies.
let browser;
let page;
let stage = 'setup';
try {
  assert.equal(process.argv.slice(2).join(' '), '--confirm-local-development');
  await developmentEnvironment(new URL('../.env', import.meta.url));
  const accounts = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/credentials.json'), 'utf8'));
  const account = accounts.find(row => row.role === 'IT_SECURITY');
  assert.ok(account);
  const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
  browser = await chromium.launch({ executablePath: '/usr/bin/chromium', args: ['--no-sandbox', '--force-renderer-accessibility'] });
  page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
  page.setDefaultTimeout(20000);
  const failedReads = [];
  const errors = [];
  const blockedWrites = [];
  await page.route('**/api/**', async route => {
    const req = route.request();
    const authRequest = req.method() === 'POST' && /\/(login|refresh)$/.test(new URL(req.url()).pathname);
    if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method()) && !authRequest) {
      blockedWrites.push(stage);
      await route.abort();
    } else await route.continue();
  });
  page.on('pageerror', () => errors.push(stage));
  page.on('response', response => {
    if (response.url().includes('/api/') && response.request().method() === 'GET' && response.status() >= 400) {
      failedReads.push({ stage, status: response.status() });
    }
  });
  const button = name => page.getByRole('button', { name, exact: true }).first();
  stage = 'login';
  await page.goto('http://127.0.0.1:8087/');
  const semantics = page.locator('flt-semantics-placeholder');
  await semantics.waitFor({ state: 'attached', timeout: 90000 });
  await semantics.dispatchEvent('click');
  stage = 'open login';
  await button('Login').click();
  stage = 'fill login';
  for (const [selector, value] of [['input[type=text]', account.login || account.email], ['input[type=password]', account.password]]) {
    await page.locator(selector).click();
    await page.keyboard.type(value, { delay: 2 });
  }
  const login = page.waitForResponse(r => new URL(r.url()).pathname.endsWith('/login') && r.request().method() === 'POST');
  stage = 'submit login';
  await button('Login').click();
  assert.equal((await login).status(), 200);
  stage = 'wait IT navigation';
  await button('System health').waitFor();
  await mkdir('/tmp/afaq-it-inspection', { recursive: true });
  const pages = [
    ['Overview', 'IT & Security Overview'],
    ['System health', 'System Health'],
    ['Company accounts', 'Access & Roles'],
    ['Sessions', 'Sessions'],
    ['Audit trail', 'Audit Logs'],
    ['Security Incidents', 'Security Incidents'],
    ['Vulnerabilities & Updates', 'Vulnerabilities & Updates'],
    ['Backups & Recovery', 'Backups & Recovery'],
    ['Offline Sync', 'Offline Sync'],
    ['Integrations & Settings', 'Integrations & Security Settings'],
  ];
  for (const [index, [navigation, heading]] of pages.entries()) {
    stage = navigation;
    await button(navigation).click();
    await page.getByText(heading, { exact: true }).last().waitFor();
    await page.waitForTimeout(900);
    await page.screenshot({ path: `/tmp/afaq-it-inspection/${index + 1}.png` });
    console.log(JSON.stringify({ page: navigation, headingVisible: true }));
  }
  assert.deepEqual(blockedWrites, [], 'Unexpected write attempted');
  assert.deepEqual(failedReads, [], 'Read requests failed');
  assert.deepEqual(errors, [], 'Browser errors occurred');
  console.log(JSON.stringify({ result: 'passed', pages: pages.length, failedReads, blockedWrites, browserErrors: errors.length }));
} catch (error) {
  await page?.screenshot({ path: '/tmp/afaq-it-inspection-failure.png' }).catch(() => {});
  console.error(JSON.stringify({ result: 'failed', stage, error: error.name }));
  process.exitCode = 1;
} finally {
  await browser?.close();
}
