import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { prepareDemoEnvironment } from './local-demo-quran-env.mjs';
import { superviseDemo } from './local-demo-lifecycle.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);

try {
  const env = await prepareDemoEnvironment(args, process.env, new URL('../.env', import.meta.url));
  // The existing runner still owns all disposable infrastructure and cleanup.
  const child = spawn(process.execPath, ['--import', 'tsx', 'scripts/platform-local-demo.ts', ...args], {
    cwd: root, env, stdio: 'inherit',
  });
  superviseDemo(child);
} catch {
  console.error('Demo preflight failed. Use --start outside production and check local QF settings. Values redacted.');
  process.exitCode = 2;
}
