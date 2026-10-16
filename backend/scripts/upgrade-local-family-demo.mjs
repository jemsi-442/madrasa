import { readFileSync, realpathSync, mkdtempSync, writeFileSync, chmodSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

// This helper deliberately cannot target a normal development or production DB.
const pid = process.argv[2];
if (process.platform !== 'linux' || !/^\d+$/.test(pid ?? '') || !process.argv.includes('--confirm-isolated-demo')) {
  throw new Error('An isolated demo API PID and --confirm-isolated-demo are required');
}
const cwd = realpathSync(`/proc/${pid}/cwd`);
if (cwd !== resolve(import.meta.dirname, '..')) throw new Error('Unexpected API working directory');
const command = readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0');
if (!command.includes('scripts/local-demo-api.ts')) throw new Error('Not a local demo API');
const environment = Object.fromEntries(readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0').filter(Boolean).map(value => {
  const at = value.indexOf('='); return [value.slice(0, at), value.slice(at + 1)];
}));
const url = new URL(environment.DATABASE_URL);
if (url.protocol !== 'mysql:' || url.hostname !== '127.0.0.1' || !url.port || url.port === '3306'
  || url.pathname !== '/afaq_local_demo' || url.username !== 'root'
  || environment.NODE_ENV !== 'development' || environment.DOTENV_CONFIG_PATH !== '/dev/null') {
  throw new Error('Refusing anything other than a private local demo database');
}
const directory = mkdtempSync(join(tmpdir(), 'afaq-demo-backup-'));
chmodSync(directory, 0o700);
const backup = spawnSync('mariadb-dump', ['--no-defaults', '--protocol=tcp', '--host=127.0.0.1', `--port=${url.port}`, '--user=root',
  '--single-transaction', '--databases', 'afaq_local_demo'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024,
    env: { ...environment, MYSQL_PWD: decodeURIComponent(url.password) } });
if (backup.status !== 0) throw new Error('Demo backup failed; no migration was attempted');
const backupPath = join(directory, 'before-family-onboarding.sql');
writeFileSync(backupPath, backup.stdout, { mode: 0o600 });
const result = spawnSync(join(cwd, 'node_modules/.bin/prisma'), ['migrate', 'deploy'], { cwd, env: environment, encoding: 'utf8' });
if (result.status !== 0) throw new Error(`Demo migration failed. Private backup retained: ${backupPath}`);
console.log(`Isolated demo upgraded. Private backup: ${backupPath}`);
