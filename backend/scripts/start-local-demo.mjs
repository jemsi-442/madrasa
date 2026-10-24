import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { prepareDemoEnvironment } from './local-demo-quran-env.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);

try {
  const env = await prepareDemoEnvironment(args, process.env, new URL('../.env', import.meta.url));
  // The existing runner still owns all disposable infrastructure and cleanup.
  const child = spawn(process.execPath, ['--import', 'tsx', 'scripts/platform-local-demo.ts', ...args], {
    cwd: root, env, stdio: 'inherit',
  });
  const interrupt = () => child.kill('SIGINT');
  const terminate = () => child.kill('SIGTERM');
  process.on('SIGINT', interrupt);
  process.on('SIGTERM', terminate);
  const detach = () => {
    process.off('SIGINT', interrupt);
    process.off('SIGTERM', terminate);
  };
  child.once('error', () => {
    detach();
    console.error('Could not start the disposable demo. Details redacted.');
    process.exitCode = 1;
  });
  child.once('exit', (code, signal) => {
    detach();
    process.exitCode = code ?? (signal === 'SIGINT' ? 130 : 143);
  });
} catch {
  console.error('Demo preflight failed. Use --start outside production and check local QF settings. Values redacted.');
  process.exitCode = 2;
}
