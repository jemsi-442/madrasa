import { test } from 'node:test';
import assert from 'node:assert/strict';
import { withQuranSettings } from './local-demo-quran-env.mjs';

const original = {
  DATABASE_URL: 'isolated-demo', JWT_SECRET: 'synthetic-existing',
  DOTENV_CONFIG_PATH: '/dev/null', QF_ENABLED: 'false',
};
test('imports only Quran settings and does not mutate inherited configuration', () => {
  const result = withQuranSettings(original, [
    'QF_ENABLED=true', 'QF_ENV=production',
    'QF_CLIENT_ID=synthetic-id', 'QF_CLIENT_SECRET=synthetic-provider-secret',
    'DATABASE_URL=not-the-demo', 'JWT_SECRET=wrong', 'DOTENV_CONFIG_PATH=.env',
  ].join('\n'));
  assert.equal(result.DATABASE_URL, original.DATABASE_URL);
  assert.equal(result.JWT_SECRET, original.JWT_SECRET);
  assert.equal(result.DOTENV_CONFIG_PATH, '/dev/null');
  assert.equal(result.QF_ENV, 'production');
  assert.equal(result.QF_ENABLED, 'true');
  assert.equal(original.QF_ENABLED, 'false');
});
test('missing provider configuration retains inherited settings', () => {
  assert.deepEqual(withQuranSettings(original, ''), original);
});
test('explicit disable clears inherited provider credentials', () => {
  const result = withQuranSettings({ ...original, QF_CLIENT_SECRET: 'old' }, 'QF_ENABLED=false');
  assert.equal(result.QF_ENABLED, 'false');
  assert.equal(result.QF_CLIENT_SECRET, '');
});
for (const source of [
  'QF_ENABLED=yes',
  'QF_ENABLED=true\nQF_CLIENT_ID=synthetic-id',
  'QF_ENABLED=false\nQF_ENV=unknown',
]) {
  test('invalid configuration fails safely before restart', () => {
    assert.throws(() => withQuranSettings(original, source),
      { message: 'Invalid Quran configuration; values redacted.' });
  });
}
