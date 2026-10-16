// Linux-only handover of a disposable API; secrets remain in process memory.
import { readFile, readlink } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url)).replace(/\/$/, '');
const apiPid = Number(process.argv[2]);
const supervisorPid = Number(process.argv[3]);
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch { return false; } };
const pause = (ms) => new Promise(ok => setTimeout(ok, ms));

async function main() {
  if (process.platform !== 'linux' || !Number.isSafeInteger(apiPid) || !Number.isSafeInteger(supervisorPid)
    || apiPid <= 1 || supervisorPid <= 1 || apiPid === supervisorPid) throw new Error('Specify the demo API PID and its supervisor PID.');
  const apiCommand = (await readFile(`/proc/${apiPid}/cmdline`, 'utf8')).split('\0');
  const supervisorCommand = (await readFile(`/proc/${supervisorPid}/cmdline`, 'utf8')).split('\0');
  if (!apiCommand.includes('scripts/local-demo-api.ts') || !supervisorCommand.includes('scripts/platform-local-demo.ts')
    || await readlink(`/proc/${apiPid}/cwd`) !== root || await readlink(`/proc/${supervisorPid}/cwd`) !== root) {
    throw new Error('Only this workspace disposable demo can be reloaded.');
  }
  let ancestor = apiPid;
  for (let depth = 0; depth < 8 && ancestor !== supervisorPid; depth++) {
    const status = await readFile(`/proc/${ancestor}/status`, 'utf8');
    ancestor = Number(status.match(/^PPid:\s+(\d+)/m)?.[1]);
    if (!ancestor) break;
  }
  if (ancestor !== supervisorPid) throw new Error('API does not belong to the specified demo supervisor.');
  const entries = (await readFile(`/proc/${apiPid}/environ`, 'utf8')).split('\0').filter(Boolean);
  const env = Object.fromEntries(entries.map(entry => { const split = entry.indexOf('='); return [entry.slice(0, split), entry.slice(split + 1)]; }));
  const db = new URL(env.DATABASE_URL);
  const redis = new URL(env.REDIS_URL);
  if (env.NODE_ENV !== 'development' || env.DOTENV_CONFIG_PATH !== '/dev/null'
    || db.hostname !== '127.0.0.1' || db.pathname !== '/afaq_local_demo' || !db.port || db.port === '3306'
    || redis.hostname !== '127.0.0.1' || !redis.port || redis.port === '6379'
    || env.SNIPPE_MOCK_MODE !== 'true') throw new Error('Refusing non-disposable configuration.');

  process.kill(apiPid, 'SIGTERM');
  for (let attempt = 0; attempt < 100 && alive(apiPid); attempt++) await pause(100);
  if (alive(apiPid) || !alive(supervisorPid)) throw new Error('Demo API did not stop safely. Database was not changed.');
  const child = spawn(resolve(root, 'node_modules/.bin/tsx'), ['watch', '--clear-screen=false', '--include', 'src/**/*.ts', 'scripts/local-demo-api.ts'], {
    cwd: root, env, stdio: 'ignore', detached: true,
  });
  const stop = () => {
    if (child.pid) { try { process.kill(-child.pid, 'SIGTERM'); } catch { /* Already stopped. */ } }
  };
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
  const timer = setInterval(() => { if (!alive(supervisorPid)) stop(); }, 1000);
  child.once('error', () => { clearInterval(timer); console.error('Could not restart demo API. Database was not changed.'); process.exitCode = 1; });
  child.once('exit', code => { clearInterval(timer); process.exitCode = code ?? 0; });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (child.exitCode !== null) throw new Error('Demo API exited before readiness.');
    try {
      const response = await fetch('http://127.0.0.1:4087/api/health', { signal: AbortSignal.timeout(1000) });
      if (response.ok) {
        console.log('Demo API refreshed on 127.0.0.1:4087. Existing database, passwords and sessions retained. Backend source changes now reload automatically.');
        return;
      }
    } catch { /* Startup in progress. */ }
    await pause(200);
  }
  stop();
  throw new Error('Demo API readiness timed out. Database was not changed.');
}

main().catch(() => {
  console.error('Demo API reload failed. No database migrations, reseeding or secret files were written.');
  process.exitCode = 1;
});
