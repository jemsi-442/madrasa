import { test } from 'node:test';
import assert from 'node:assert/strict';
import { AutoReload } from './dev-web.mjs';

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
