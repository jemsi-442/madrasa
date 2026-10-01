import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { runInNewContext } from 'node:vm';
import { createPreviewServer } from './serve_web.mjs';

async function fixture(t) {
  const temporary = await mkdtemp(join(tmpdir(), 'mif-preview-test-'));
  const directory = join(temporary, 'web');
  await mkdir(directory);
  await writeFile(join(directory, 'index.html'), '<script src="flutter_bootstrap.js" async></script>');
  await writeFile(join(directory, 'main.dart.js'), 'console.log("eight pages");');
  await writeFile(join(directory, 'flutter_bootstrap.js'), '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};');
  await writeFile(join(directory, 'engine.wasm'), Buffer.from([0, 97, 115, 109]));
  await writeFile(join(temporary, 'private.txt'), 'not public');
  await symlink(join(temporary, 'private.txt'), join(directory, 'escape.txt'));
  const server = await createPreviewServer(directory);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await rm(temporary, { recursive: true, force: true });
  });
  return { directory, base: `http://127.0.0.1:${server.address().port}` };
}

test('serves current build with versioned entry scripts and no cache', async t => {
  const { base } = await fixture(t);
  const version = await (await fetch(base + '/__preview__/version')).json();
  assert.match(version.build, /^[a-f0-9]{12}$/);
  const page = await fetch(base + '/');
  assert.equal(page.headers.get('cache-control'), 'no-store, max-age=0');
  assert.equal(page.headers.get('x-preview-build'), version.build);
  assert.match(await page.text(), new RegExp(`flutter_bootstrap.js\\?v=${version.build}`));
  const bootstrap = await fetch(base + '/flutter_bootstrap.js?v=' + version.build);
  assert.match(await bootstrap.text(), new RegExp(`main.dart.js\\?v=${version.build}`));
  const main = await fetch(base + '/main.dart.js?v=' + version.build, {
    headers: { 'If-Modified-Since': 'Fri, 01 Jan 2100 00:00:00 GMT', 'If-None-Match': '*' },
  });
  assert.equal(main.status, 200);
  assert.match(await main.text(), /eight pages/);
});

test('picks up rebuilt app without restarting server', async t => {
  const { base, directory } = await fixture(t);
  const before = await (await fetch(base + '/__preview__/version')).json();
  await writeFile(join(directory, 'main.dart.js'), 'console.log("new release with all finance pages");');
  const after = await (await fetch(base + '/__preview__/version')).json();
  assert.notEqual(after.build, before.build);
  assert.match(await (await fetch(base + '/')).text(), new RegExp(after.build));
});

test('HEAD and renderer MIME types work', async t => {
  const { base } = await fixture(t);
  const response = await fetch(base + '/engine.wasm', { method: 'HEAD' });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'application/wasm');
  assert.equal(response.headers.get('content-length'), '4');
  assert.equal(await response.text(), '');
});

test('does not expose directories, dotfiles, parent files or symlinks outside the build', async t => {
  const { base } = await fixture(t);
  for (const path of ['/escape.txt', '/.env', '/%2e%2e%2fprivate.txt', '/missing', '/%00']) {
    assert.equal((await fetch(base + path)).status, 404, path);
  }
  assert.equal((await fetch(base + '/%ZZ')).status, 400);
  const rejected = await fetch(base + '/', { method: 'POST', body: 'no mutations' });
  assert.equal(rejected.status, 405);
  assert.equal(rejected.headers.get('allow'), 'GET, HEAD');
});

async function recoveryScript(t) {
  const { base } = await fixture(t);
  const response = await fetch(base + '/__preview__/refresh');
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store, max-age=0');
  const html = await response.text();
  return html.match(/<script>([\s\S]*?)<\/script>/)[1];
}

test('refresh unregisters only this root Flutter worker and preserves user data', async t => {
  const script = await recoveryScript(t);
  const origin = 'http://127.0.0.1:8080';
  const removed = [];
  const registration = (scope, scriptURL, state = 'active') => ({
    scope, [state]: { scriptURL }, unregister: async () => removed.push(scriptURL),
  });
  const registrations = [
    registration(origin + '/', origin + '/flutter_service_worker.js?v=old'),
    registration(origin + '/other/', origin + '/other/flutter_service_worker.js'),
    registration(origin + '/', origin + '/unrelated-worker.js'),
    registration('https://other.invalid/', 'https://other.invalid/flutter_service_worker.js'),
  ];
  let redirect;
  await runInNewContext(script, {
    URL, navigator: { serviceWorker: { getRegistrations: async () => registrations } },
    location: { origin, replace: target => { redirect = target; } },
    localStorage: { clear: () => assert.fail('Must preserve local storage') },
    caches: { delete: () => assert.fail('Must preserve caches for unrelated applications') },
    document: { get cookie() { assert.fail('Must not access cookies'); } },
  });
  assert.deepEqual(removed, [origin + '/flutter_service_worker.js?v=old']);
  assert.match(redirect, /^\/\?preview=[a-f0-9]{12}#\/$/);
});

test('refresh also removes a waiting Flutter worker', async t => {
  const script = await recoveryScript(t);
  const origin = 'http://127.0.0.1:8080';
  let removed = false;
  await runInNewContext(script, {
    URL, location: { origin, replace() {} },
    navigator: { serviceWorker: { getRegistrations: async () => [{
      scope: origin + '/', waiting: { scriptURL: origin + '/flutter_service_worker.js' },
      unregister: async () => { removed = true; },
    }] } },
  });
  assert.equal(removed, true);
});

test('refresh works without service worker support and shows failures without a reload loop', async t => {
  const script = await recoveryScript(t);
  let redirects = 0;
  const location = { origin: 'http://127.0.0.1:8080', replace: () => redirects++ };
  await runInNewContext(script, { navigator: {}, location });
  assert.equal(redirects, 1);
  const status = {};
  await runInNewContext(script, {
    navigator: { serviceWorker: { getRegistrations: async () => { throw new Error('Blocked'); } } },
    location, document: { getElementById: () => status },
  });
  assert.equal(redirects, 1);
  assert.match(status.textContent, /private window/);
});
