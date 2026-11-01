import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';
import { superviseDemo } from './local-demo-lifecycle.mjs';

try {
  const args = process.argv.slice(2);
  if (args.length && !(args.length === 1 && args[0] === '--start')) throw new Error('Unsupported arguments.');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  console.log('Using the shared development database from backend/.env. No database creation, reset or seeding.');
  const child = spawn(process.execPath, ['--import', 'tsx', 'node_modules/tsx/dist/cli.mjs', 'watch', 'src/server.ts'], {
    cwd: fileURLToPath(new URL('../', import.meta.url)), env, stdio: 'inherit',
  });
  superviseDemo(child);
} catch {
  console.error('Development startup refused. Check local backend/.env, NODE_ENV=development and mock payments. No database changed.');
  process.exitCode = 2;
}
