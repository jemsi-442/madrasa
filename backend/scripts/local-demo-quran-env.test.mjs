import { test } from 'node:test';
import assert from 'node:assert/strict';
import { withQuranSettings, prepareDemoEnvironment } from './local-demo-quran-env.mjs';

const original = {
  DATABASE_URL: 'isolated-demo', JWT_SECRET: 'synthetic-existing',
  DOTENV_CONFIG_PATH: '/dev/null', QF_ENABLED: 'false',
};
test('startup imports provider settings only from the chosen file', async () => {
  const env = await prepareDemoEnvironment(['--start'], original, '/synthetic/.env', async (file, encoding) => {
    assert.equal(file, '/synthetic/.env');
    assert.equal(encoding, 'utf8');
    return 'QF_ENABLED=false\nDATABASE_URL=unrelated\nJWT_SECRET=unrelated';
  });
  assert.equal(env.DATABASE_URL, original.DATABASE_URL);
  assert.equal(env.JWT_SECRET, original.JWT_SECRET);
  assert.equal(env.QF_ENABLED, 'false');
});
test('startup rejects production or missing start flag before reading files', async () => {
  const neverRead = async () => assert.fail('must not read settings');
  await assert.rejects(prepareDemoEnvironment([], original, '/unused', neverRead));
  await assert.rejects(prepareDemoEnvironment(['--start'], { ...original, NODE_ENV: 'production' }, '/unused', neverRead));
});
test('startup tolerates a missing env file but not a permissions error', async () => {
  assert.deepEqual(await prepareDemoEnvironment(['--start'], original, '/missing', async () => {
    throw Object.assign(new Error(), { code: 'ENOENT' });
  }), original);
  await assert.rejects(prepareDemoEnvironment(['--start'], original, '/denied', async () => {
    throw Object.assign(new Error(), { code: 'EACCES' });
  }));
});
test('startup rejects incomplete provider settings before starting infrastructure', async () => {
  await assert.rejects(prepareDemoEnvironment(['--start'], original, '/invalid', async () => 'QF_ENABLED=true'),
    { message: 'Invalid Quran configuration; values redacted.' });
});
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
