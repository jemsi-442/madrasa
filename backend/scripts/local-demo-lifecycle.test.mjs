import { EventEmitter } from 'node:events';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { superviseDemo } from './local-demo-lifecycle.mjs';
import { fork } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

function fixture() {
  const child = new EventEmitter(), parent = new EventEmitter();
  const signals = [], messages = [];
  child.kill = signal => { signals.push(signal); return true; };
  superviseDemo(child, parent, message => messages.push(message));
  return { child, parent, signals, messages };
}
for (const signal of ['SIGINT', 'SIGTERM']) {
  test(`forwards ${signal} only once while runner cleans up`, () => {
    const f = fixture();
    f.parent.emit(signal);
    f.parent.emit(signal);
    f.parent.emit(signal === 'SIGINT' ? 'SIGTERM' : 'SIGINT');
    assert.deepEqual(f.signals, [signal]);
    assert.equal(f.parent.exitCode, undefined);
    f.child.emit('exit', 0, null);
    assert.equal(f.parent.exitCode, 0);
    assert.equal(f.parent.listenerCount('SIGINT'), 0);
    assert.equal(f.parent.listenerCount('SIGTERM'), 0);
  });
}
test('runner failure preserves exit status', () => {
  const f = fixture();
  f.child.emit('exit', 2, null);
  assert.equal(f.parent.exitCode, 2);
  assert.equal(f.parent.listenerCount('SIGINT'), 0);
});
for (const [signal, code] of [['SIGINT', 130], ['SIGTERM', 143], ['SIGKILL', 137]]) {
  test(`reports runner termination by ${signal}`, () => {
    const f = fixture();
    f.child.emit('exit', null, signal);
    assert.equal(f.parent.exitCode, code);
  });
}
test('spawn failure cleans up listeners without exposing error details', () => {
  const f = fixture();
  f.child.emit('error', new Error('synthetic-private-detail'));
  assert.equal(f.parent.exitCode, 1);
  assert.equal(f.parent.listenerCount('SIGINT'), 0);
  assert.equal(f.parent.listenerCount('SIGTERM'), 0);
  assert.equal(f.messages.length, 1);
  assert.doesNotMatch(f.messages[0], /synthetic-private-detail/);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  test(`real subprocess completes cleanup after repeated ${signal}`, {
    skip: process.platform === 'win32', timeout: 10000,
  }, async () => {
    const launcher = fork(fileURLToPath(new URL('./fixtures/demo-lifecycle-process.mjs', import.meta.url)), [], {
      env: { NODE_ENV: 'test' }, detached: true,
      stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
    });
    const events = [];
    const exit = once(launcher, 'exit');
    const watchdog = setTimeout(() => {
      try { process.kill(-launcher.pid, 'SIGKILL'); } catch { /* Already exited. */ }
    }, 8000);
    launcher.on('message', message => events.push(message));
    try {
      const ready = await once(launcher, 'message', { signal: AbortSignal.timeout(5000) });
      assert.equal(ready[0].event, 'ready');
      const stopping = once(launcher, 'message', { signal: AbortSignal.timeout(5000) });
      launcher.kill(signal);
      assert.equal((await stopping)[0].event, 'stopping');
      launcher.kill(signal);
      launcher.kill(signal === 'SIGINT' ? 'SIGTERM' : 'SIGINT');
      assert.deepEqual(await exit, [0, null]);
      assert.deepEqual(events.map(message => message.event), ['ready', 'stopping', 'cleaned']);
      assert.throws(() => process.kill(ready[0].pid, 0), { code: 'ESRCH' });
    } finally {
      clearTimeout(watchdog);
      // Only this test's isolated process group; never the running demo.
      try { process.kill(-launcher.pid, 'SIGKILL'); } catch (error) {
        if (error.code !== 'ESRCH') throw error;
      }
      await exit;
    }
  });
}
