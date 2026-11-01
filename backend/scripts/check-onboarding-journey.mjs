import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { developmentEnvironment } from './development-config.mjs';

if (process.argv.slice(2).join(' ') !== '--confirm-local-development') {
  throw new Error('Use --confirm-local-development. No production target is allowed.');
}
const env = await developmentEnvironment(new URL('../.env', import.meta.url));
const result = spawnSync('node_modules/.bin/vitest', ['run', 'tests/onboarding-journey.local.test.ts'], {
  cwd: new URL('../', import.meta.url), stdio: 'inherit',
  env: {
    ...env, AFAQ_LOCAL_ONBOARDING: 'rollback-only',
    JWT_SECRET: randomBytes(32).toString('hex'),
    JWT_REFRESH_SECRET: randomBytes(32).toString('hex'),
    PLATFORM_JWT_SECRET: randomBytes(32).toString('hex'),
  },
});
process.exitCode = result.status ?? 1;
