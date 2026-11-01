import test from 'node:test';
import assert from 'node:assert/strict';
import bcrypt from 'bcryptjs';
import { resetDevelopmentPasswords } from './reset-development-passwords.mjs';

const env = { NODE_ENV: 'development', DATABASE_URL: 'mysql://local@127.0.0.1/afaq_dev', REDIS_URL: 'redis://127.0.0.1:6379', SNIPPE_MOCK_MODE: 'true' };
test('rejects non-local and production resets before database access', async () => {
  for (const invalid of [{ ...env, NODE_ENV: 'production' }, { ...env, DATABASE_URL: 'mysql://local@remote/afaq' }]) {
    await assert.rejects(resetDevelopmentPasswords({}, invalid, 'Synthetic123!'));
  }
});
test('updates login hashes and invalidates sessions without changing roles or learning data', async () => {
  const calls = {};
  const tx = Object.fromEntries(['platformAccount', 'user', 'familyApplication', 'platformSession', 'refreshToken'].map(name => [name, {
    updateMany: async args => { calls[name] = args; return { count: 2 }; },
  }]));
  const result = await resetDevelopmentPasswords({ $transaction: fn => fn(tx) }, env, 'Synthetic123!');
  assert.equal(result.users, 2);
  assert.ok(await bcrypt.compare('Synthetic123!', calls.user.data.passwordHash));
  assert.deepEqual(Object.keys(calls.user.data).sort(), ['authVersion', 'passwordHash']);
  assert.deepEqual(calls.user.data.authVersion, { increment: 1 });
  assert.deepEqual(calls.familyApplication.where, { passwordHash: { not: null } });
  assert.ok(calls.platformSession.data.revokedAt instanceof Date);
  assert.ok(calls.refreshToken.data.revokedAt instanceof Date);
});
