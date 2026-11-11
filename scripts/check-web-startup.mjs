import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

// Fresh browser contexts only: no saved login, demo credentials or account edits.
const target = new URL(process.env.WEB_PREVIEW_URL ?? 'http://127.0.0.1:8087/');
if (target.protocol !== 'http:' || target.hostname !== '127.0.0.1' || target.username || target.password) {
  throw new Error('Use a loopback HTTP preview without credentials');
}
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN ?? '/usr/bin/chromium',
  headless: true, args: ['--no-sandbox'] });
async function opened(page) {
  await page.waitForFunction(() => !document.getElementById('app-loading') && !!document.querySelector('flutter-view'),
    { }, { timeout: 45000 });
}
try {
  for (const width of [1440, 390]) {
    const context = await browser.newContext({ viewport: { width, height: 900 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const start = Date.now();
    await page.goto(target.href, { waitUntil: 'domcontentloaded' });
    await opened(page);
    assert.deepEqual(errors, [], 'Startup must not raise JavaScript errors');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    console.log(`${width}px: first Flutter frame in ${Date.now() - start}ms`);
    await context.close();
  }
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
  const page = await context.newPage();
  const pattern = '**/flutter_bootstrap.js*';
  await page.route(pattern, route => route.abort());
  let navigations = 0;
  page.on('request', request => {
    // Flutter's hash routing changes the URL without reloading the document.
    if (request.isNavigationRequest() && request.frame() === page.mainFrame()) navigations++;
  });
  await page.goto(target.href, { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: 'Try again' }).waitFor();
  assert.equal(await page.locator('#app-loading').getAttribute('aria-busy'), 'false');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  await page.waitForTimeout(1500);
  assert.equal(navigations, 1, 'A failed start must not enter an automatic reload loop');
  await page.unroute(pattern);
  await page.getByRole('button', { name: 'Try again' }).click();
  await opened(page);
  assert.equal(navigations, 2);
  console.log('Blocked startup: accessible retry, no auto-reload, successful recovery');
  await context.close();
} finally {
  await browser.close();
}
