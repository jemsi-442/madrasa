// Recover an orphaned local demo using its surviving MariaDB process.
// Never reseed, migrate, print secrets or stop the existing database.
import { readFile, readlink } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pid = Number(process.argv[2]);
const children = [];
const pause = ms => new Promise(ok => setTimeout(ok, ms));
function stop() { for (const child of children) child.kill('SIGTERM'); }
async function unused(port) {
  const server = createServer();
  await new Promise((ok, fail) => {
    server.once('error', fail);
    server.listen(port, '127.0.0.1', ok);
  });
  await new Promise(ok => server.close(ok));
}
async function main() {
  if (!Number.isSafeInteger(pid) || pid <= 1) throw Error('Invalid PID');
  const args = (await readFile(`/proc/${pid}/cmdline`, 'utf8')).split('\0');
  if (!args[0].endsWith('mariadbd')) throw Error('Not a database process');
  const data = args.find(arg => arg.startsWith('--datadir='))?.slice(10);
  if (!/^\/tmp\/afaq-local-demo-[A-Za-z0-9]+\/data$/.test(data ?? '')) throw Error('Not a disposable database');
  if (await readlink(`/proc/${pid}/cwd`) !== data) throw Error('Unexpected data directory');
  const directory = dirname(data);
  const env = Object.fromEntries((await readFile(`/proc/${pid}/environ`, 'utf8')).split('\0').filter(Boolean).map(entry => {
    const index = entry.indexOf('=');
    return [entry.slice(0, index), entry.slice(index + 1)];
  }));
  const db = new URL(env.DATABASE_URL);
  const redis = new URL(env.REDIS_URL);
  if (env.NODE_ENV !== 'development' || env.DOTENV_CONFIG_PATH !== '/dev/null'
    || db.hostname !== '127.0.0.1' || db.pathname !== '/afaq_local_demo'
    || !db.port || db.port === '3306' || !args.includes(`--port=${db.port}`)
    || redis.hostname !== '127.0.0.1' || !redis.port || redis.port === '6379'
    || env.SNIPPE_MOCK_MODE !== 'true'
    || !env.PLATFORM_JWT_SECRET || !env.JWT_SECRET) throw Error('Unsafe configuration');
  await unused(4087);
  await unused(Number(redis.port));
  function start(command, args) {
    const child = spawn(command, args, { cwd: root, env, stdio: 'ignore' });
    child.once('error', stop);
    children.push(child);
    return child;
  }
  start('redis-server', ['--bind', '127.0.0.1', '--port', redis.port,
    '--save', '', '--appendonly', 'no', '--dir', directory]);
  await pause(500);
  start(resolve(root, 'node_modules/.bin/tsx'), ['scripts/local-demo-api.ts']);
  for (let attempt = 0; attempt < 100; attempt++) {
    if (children.some(child => child.exitCode !== null)) throw Error('Service exited');
    try {
      const response = await fetch('http://127.0.0.1:4087/api/health', { signal: AbortSignal.timeout(1000) });
      if (response.ok) {
        console.log('Demo API restored on 127.0.0.1:4087. Database, passwords and signing keys preserved. Redis ephemeral state restarted.');
        process.once('SIGTERM', stop);
        process.once('SIGINT', stop);
        return;
      }
    } catch { /* Services are starting. */ }
    await pause(200);
  }
  throw Error('Readiness timeout');
}
main().catch(() => {
  stop();
  console.error('Demo recovery stopped. No database or credentials were modified. Check the surviving demo PID and free ports.');
  process.exitCode = 1;
});
