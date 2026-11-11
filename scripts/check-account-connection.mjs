import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

// Synthetic session responses in a fresh context: never use a saved account.
const target = new URL(process.env.WEB_PREVIEW_URL ?? 'http://127.0.0.1:8087/');
if (target.protocol !== 'http:' || target.hostname !== '127.0.0.1' || target.username || target.password) {
  throw new Error('Use a loopback HTTP preview without credentials');
}
target.hash = '/login';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN ?? '/usr/bin/chromium',
  headless: true, args: ['--no-sandbox'] });
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  let requests = 0;
  let release;
  const pending = new Promise(resolve => { release = resolve; });
  await page.route('**/api/auth/browser/refresh', async route => {
    const headers = {
      'access-control-allow-origin': target.origin,
      'access-control-allow-credentials': 'true',
      'access-control-allow-headers': 'content-type,x-mif-browser',
      'access-control-allow-methods': 'POST,OPTIONS',
    };
    if (route.request().method() === 'OPTIONS') {
      await route.fulfill({ status: 204, headers });
      return;
    }
    requests++;
    if (requests === 1) await pending;
    await route.fulfill({ status: requests === 1 ? 503 : 401, headers,
      contentType: 'application/json', body: '{"message":"Synthetic test response"}' });
  });
  await page.goto(target.href);
  await page.waitForFunction(() => !document.getElementById('app-loading') && document.querySelector('flutter-view'));
  // Enable Flutter's accessibility tree so assertions inspect real UI labels.
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');
  const status = page.locator('flt-semantics span');
  await status.filter({ hasText: 'Checking your saved session securely.' }).waitFor();
  await status.filter({ hasText: 'This is taking longer than usual' }).waitFor({ timeout: 15000 });
  assert.equal(requests, 1, 'Slow UI must not send duplicate refresh requests');
  release();
  await page.getByRole('button', { name: 'Try again', exact: true }).waitFor();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  if (process.env.CONNECTION_SCREENSHOT) await page.screenshot({ path: process.env.CONNECTION_SCREENSHOT });
  await page.getByRole('button', { name: 'Try again', exact: true }).click();
  await page.getByRole('button', { name: 'Login', exact: true }).waitFor();
  assert.equal(requests, 2, 'Only the explicit retry should recheck the session');
  console.log('Account connection: slow guidance, error actions and expired-session recovery passed');
} finally {
  await browser.close();
}
