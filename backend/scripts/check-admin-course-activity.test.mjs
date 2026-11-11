import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const script = fileURLToPath(new URL('./check-admin-course-activity.mjs', import.meta.url));

test('admin activity browser check refuses missing or ambiguous confirmation', () => {
  for (const args of [[], ['--confirm-local-development', '--reset']]) {
    const result = spawnSync(process.execPath, [script, ...args], { encoding: 'utf8', timeout: 10000 });
    assert.equal(result.status, 1);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /Check could not start or clean up/);
  }
});

test('admin activity browser check refuses production before opening services', () => {
  const result = spawnSync(process.execPath, [script, '--confirm-local-development'], {
    env: { ...process.env, NODE_ENV: 'production' }, encoding: 'utf8', timeout: 10000,
  });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /Check could not start or clean up/);
});
