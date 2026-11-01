import test from 'node:test';
import assert from 'node:assert/strict';
import { validateDevelopment } from './development-config.mjs';

const valid = { NODE_ENV: 'development', DATABASE_URL: 'mysql://test:test@127.0.0.1:3306/mms', REDIS_URL: 'redis://127.0.0.1:6379', SNIPPE_MOCK_MODE: 'true' };
test('uses the existing shared database without changing connection settings', () => {
  assert.equal(validateDevelopment(valid).database.pathname, '/mms');
});
for (const [label, change] of [
  ['production', { NODE_ENV: 'production' }],
  ['remote database', { DATABASE_URL: 'mysql://test:test@db.example/mms' }],
  ['system database', { DATABASE_URL: 'mysql://test:test@localhost/mysql' }],
  ['isolated demo database', { DATABASE_URL: 'mysql://test:test@localhost/afaq_local_demo' }],
  ['remote Redis', { REDIS_URL: 'redis://redis.example' }],
  ['real payments', { SNIPPE_MOCK_MODE: 'false' }],
  ['missing database', { DATABASE_URL: '' }],
]) test(`rejects ${label}`, () => assert.throws(() => validateDevelopment({ ...valid, ...change })));
