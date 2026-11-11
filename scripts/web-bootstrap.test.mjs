import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const source = (await readFile(new URL('../frontend/web/flutter_bootstrap.js', import.meta.url), 'utf8'))
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
test('web shell opts out of automatic translation to preserve Quran text', async () => {
  const html = await readFile(new URL('../frontend/web/index.html', import.meta.url), 'utf8');
  assert.match(html, /<html\b[^>]*\btranslate="no"/);
  assert.match(html, /<meta\s+name="google"\s+content="notranslate"\s*\/?>/);
  assert.match(html, /<body\b[^>]*\btranslate="no"[^>]*\bclass="notranslate"/);
});
async function boot(serviceWorker, load) {
  const result = { loads: [], reloads: 0, failures: 0, stages: [] };
  await runInNewContext(source, {
    URL, setTimeout, clearTimeout, navigator: serviceWorker ? { serviceWorker } : {},
    window: { AfaqStartup: { fail: () => result.failures++, stage: index => result.stages.push(index) } },
    document: { baseURI: 'http://127.0.0.1:8087/' },
    location: { reload: () => result.reloads++ },
    _flutter: { loader: { load: async config => { result.loads.push(config); await load?.(config); } } },
  });
  return result;
}

test('renderer loads locally without service worker support', async () => {
  const result = await boot();
  assert.equal(result.loads[0].config.canvasKitBaseUrl, 'canvaskit/');
  assert.equal(result.reloads, 0);
});

test('startup still proceeds when worker enumeration never resolves', async () => {
  const result = await boot({ getRegistrations: () => new Promise(() => {}) });
  assert.equal(result.loads.length, 1);
  assert.equal(result.reloads, 0);
});

test('late worker retirement never reloads an already opened workspace', async () => {
  let finishRetirement;
  const scriptURL = 'http://127.0.0.1:8087/flutter_service_worker.js';
  const result = await boot({
    controller: { scriptURL },
    getRegistrations: async () => [{
      scope: 'http://127.0.0.1:8087/', active: { scriptURL },
      unregister: () => new Promise(resolve => { finishRetirement = resolve; }),
    }],
  });
  assert.equal(result.loads.length, 1);
  finishRetirement(true);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(result.reloads, 0);
});

test('engine initialization and app start report actual stages', async () => {
  let runs = 0;
  const result = await boot(null, config => config.onEntrypointLoaded({
    initializeEngine: async () => ({ runApp: async () => { runs++; } }),
  }));
  assert.deepEqual(result.stages, [1, 2]);
  assert.equal(runs, 1);
  assert.equal(result.failures, 0);
});

test('loader and engine failures surface a retry state instead of an endless spinner', async () => {
  const loader = await boot(null, async () => { throw Error('Unavailable'); });
  assert.equal(loader.failures, 1);
  const engine = await boot(null, config => config.onEntrypointLoaded({
    initializeEngine: async () => { throw Error('Unavailable'); },
  }));
  assert.equal(engine.failures, 1);
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
