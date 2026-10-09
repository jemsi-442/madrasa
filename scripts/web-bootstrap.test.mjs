import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const source = (await readFile(new URL('../frontend/web/flutter_bootstrap.js', import.meta.url), 'utf8'))
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
async function boot(serviceWorker) {
  const result = { loads: [], reloads: 0 };
  await runInNewContext(source, {
    URL, navigator: serviceWorker ? { serviceWorker } : {},
    document: { baseURI: 'http://127.0.0.1:8087/' },
    location: { reload: () => result.reloads++ },
    _flutter: { loader: { load: async config => result.loads.push(config) } },
  });
  return result;
}

test('renderer loads locally without service worker support', async () => {
  const result = await boot();
  assert.equal(result.loads[0].config.canvasKitBaseUrl, 'canvaskit/');
  assert.equal(result.reloads, 0);
});
test('storage restrictions do not prevent app startup', async () => {
  const result = await boot({ getRegistrations: async () => { throw Error('denied'); } });
  assert.equal(result.loads.length, 1);
});
test('retires only the matching legacy worker and reloads once', async () => {
  let removed = 0;
  const scriptURL = 'http://127.0.0.1:8087/flutter_service_worker.js?v=old';
  const result = await boot({ controller: { scriptURL }, getRegistrations: async () => [
    { scope: 'http://127.0.0.1:8087/other/', active: { scriptURL }, unregister: async () => assert.fail('unrelated worker') },
    { scope: 'http://127.0.0.1:8087/', active: { scriptURL }, unregister: async () => { removed++; return true; } },
  ] });
  assert.equal(removed, 1);
  assert.equal(result.reloads, 1);
  assert.equal(result.loads.length, 0);
});
