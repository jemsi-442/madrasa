import { test } from 'node:test';
import assert from 'node:assert/strict';
import { AutoReload, webOptions } from './dev-web.mjs';

test('release preview keeps the familiar origin and bypasses debug compilation', () => {
  const options = webOptions({ WEB_MODE: 'release' });
  assert.equal(options.mode, 'release');
  assert.equal(options.port, '8087');
  assert.ok(options.args.includes('--release'));
  assert.ok(options.args.includes('--no-web-resources-cdn'));
  assert.ok(options.args.includes('--dart-define=API_BASE_URL=http://127.0.0.1:4000'));
  assert.ok(!options.args.includes('--debug'));
});

test('debug remains opt-in capable and invalid preview settings fail early', () => {
  assert.equal(webOptions({}).mode, 'debug');
  assert.throws(() => webOptions({ WEB_MODE: 'invalid' }));
  assert.throws(() => webOptions({ WEB_PORT: '80' }));
  assert.throws(() => webOptions({ API_BASE_URL: 'http://user:password@localhost' }));
});

test('queues saves until ready and never requests a full restart', () => {
  const sent = [];
  const reload = new AutoReload(m => sent.push(m), () => {});
  reload.changed();
  reload.flush();
  assert.equal(sent.length, 0);
  reload.message({ event: 'app.start', params: { appId: 'app' } });
  reload.message({ event: 'app.started' });
  assert.equal(sent.length, 1);
  assert.equal(sent[0].params.fullRestart, false);
  reload.changed();
  reload.changed();
  reload.flush();
  assert.equal(sent.length, 1);
  reload.message({ id: 1, result: { code: 0 } });
  assert.equal(sent.length, 2);
  reload.close();
});

test('failed reload does not retry or reset the session automatically', () => {
  const sent = [];
  const logs = [];
  const reload = new AutoReload(m => sent.push(m), m => logs.push(m));
  reload.message({ event: 'app.start', params: { appId: 'app' } });
  reload.message({ event: 'app.started' });
  reload.changed();
  reload.flush();
  reload.message({ id: 1, result: { code: 1 } });
  assert.equal(sent.length, 1);
  assert.match(logs.at(-1), /no automatic restart/);
  reload.close();
});

test('rapid saves trigger only one debounced update', async () => {
  const sent = [];
  const reload = new AutoReload(m => sent.push(m), () => {}, 10);
  reload.message({ event: 'app.start', params: { appId: 'app' } });
  reload.message({ event: 'app.started' });
  reload.changed();
  reload.changed();
  await new Promise(resolve => setTimeout(resolve, 30));
  assert.equal(sent.length, 1);
  reload.close();
});
