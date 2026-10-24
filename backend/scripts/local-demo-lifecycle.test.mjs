import { EventEmitter } from 'node:events';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { superviseDemo } from './local-demo-lifecycle.mjs';

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
