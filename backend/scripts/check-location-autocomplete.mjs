import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { createRequire } from 'node:module';

assert.equal(process.argv[2], '--confirm-local-development');
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const accounts = JSON.parse(await readFile(`${homedir()}/.afaq/platform-demo/credentials.json`, 'utf8'));
const account = accounts.find(row => row.role === 'SUPER_ADMIN');
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', args: ['--no-sandbox', '--force-renderer-accessibility'] });
let stage = 'login';
let page;
try {
  page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
  page.setDefaultTimeout(15000);
  page.on('response', async response => {
    if (response.url().includes('/location-suggestions')) {
      const field = new URL(response.url()).searchParams.get('field');
      const data = await response.json();
      console.log('suggestions', field, response.status(), data.data?.items?.length ?? 0);
    }
  });
  await page.goto('http://127.0.0.1:8087/');
  await page.locator('flt-semantics-placeholder').dispatchEvent('click', { timeout: 90000 });
  const button = name => page.getByRole('button', { name, exact: true }).first();
  await button('Login').click();
  for (const [selector, value] of [['input[type=text]', account.login || account.email], ['input[type=password]', account.password]]) {
    await page.locator(selector).click();
    await page.keyboard.type(value);
  }
  await button('Login').click();
  stage = 'open form';
  await button('Madrasas').click();
  await button('Add Madrasa').click();
  async function choose(label, prefix, option) {
    stage = label;
    const field = page.getByRole('textbox', { name: label, exact: true }).first();
    await field.scrollIntoViewIfNeeded();
    await field.click();
    await page.keyboard.type(prefix, { delay: 60 });
    await page.getByRole('button', { name: option, exact: true }).last().click();
    console.log('PASS selected', label);
  }
  await choose('Country *', 'Tan', 'Tanzania');
  await choose('Region *', 'Dar', 'Dar es Salaam');
  await choose('District *', 'Kin', 'Kinondoni');
  await choose('Ward *', 'Msa', 'Msasani');
  await choose('Street / Neighbourhood (optional)', 'Mas', 'Masaki');
  console.log('PASS browser location cascade; no madrasa created');
} catch (error) {
  if (stage !== 'login') await page?.screenshot({ path: '/tmp/afaq-location-form.png' });
  console.error('FAILED stage:', stage, stage === 'login' ? 'Login failed' : error.message);
  process.exitCode = 1;
} finally {
  await browser.close();
}
