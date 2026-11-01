import { openSync, closeSync } from 'node:fs';
import { copyFile, mkdir, chmod, readFile, readdir, stat } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PrismaClient } from '@prisma/client';
import { developmentEnvironment, validateDevelopment } from './development-config.mjs';
import { ensureDevelopmentAccounts, coreDemoAccounts } from './development-accounts.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
let db;
let backup;
try {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Explicit confirmation is required.');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const { database } = validateDevelopment(env);
  // Never silently switch away from a surviving demo containing user work.
  const candidates = [join(homedir(), '.afaq/platform-demo/runtime/data'),
    ...(await readdir(tmpdir())).filter(name => name.startsWith('afaq-local-demo-')).map(name => join(tmpdir(), name, 'data'))];
  for (const path of candidates) {
    try { if ((await stat(path)).isDirectory()) throw new Error('Existing isolated demo needs a deliberate data merge before switching.'); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  const privateDir = join(homedir(), '.afaq/platform-demo');
  const accounts = coreDemoAccounts(
    JSON.parse(await readFile(join(privateDir, 'credentials.json'), 'utf8')),
    JSON.parse(await readFile(join(privateDir, 'teacher-credentials.json'), 'utf8')),
  );
  db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
  const tables = await db.$queryRaw`SELECT table_name AS name FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE'`;
  if (!tables.length) throw new Error('Expected the existing development database, not an empty replacement.');
  const counts = new Map();
  for (const { name } of tables) {
    if (name === '_prisma_migrations') continue;
    if (!/^[a-zA-Z0-9_]+$/.test(name)) throw new Error('Unexpected table name.');
    const rows = await db.$queryRawUnsafe(`SELECT COUNT(*) AS n FROM \`${name}\``);
    counts.set(name, Number(rows[0].n));
  }
  backup = join(homedir(), '.afaq/backups', `shared-development-${Date.now()}`);
  await mkdir(backup, { recursive: true, mode: 0o700 });
  await chmod(backup, 0o700);
  await copyFile(join(root, '.env'), join(backup, 'backend.env'));
  await chmod(join(backup, 'backend.env'), 0o600);
  const fd = openSync(join(backup, 'database.sql'), 'wx', 0o600);
  let dumped;
  try {
    dumped = spawnSync('mariadb-dump', ['--no-defaults', '--skip-ssl', '--single-transaction', '--routines', '--triggers', '--events', '--hex-blob',
      `--host=${database.hostname}`, `--port=${database.port || 3306}`, `--user=${decodeURIComponent(database.username)}`, database.pathname.slice(1)], {
      env: { ...env, MYSQL_PWD: decodeURIComponent(database.password) }, stdio: ['ignore', fd, 'pipe'], timeout: 120_000,
    });
  } finally { closeSync(fd); }
  if (dumped.status !== 0) throw new Error('Backup failed; database was not migrated.');
  console.log(`Private database/config backup: ${backup}`);
  const migration = spawnSync(join(root, 'node_modules/.bin/prisma'), ['migrate', 'deploy'], { cwd: root, env, encoding: 'utf8', timeout: 180_000 });
  if (migration.status !== 0) throw new Error('Development migration failed; inspect saved backup and migration status. No reset attempted.');
  for (const [name, before] of counts) {
    const rows = await db.$queryRawUnsafe(`SELECT COUNT(*) AS n FROM \`${name}\``);
    if (Number(rows[0].n) < before) throw new Error('An existing table lost rows; stop and inspect the backup.');
  }
  const result = await ensureDevelopmentAccounts(db, accounts);
  console.log(JSON.stringify({ migrated: true, existingTablesPreserved: counts.size, demoAccounts: result }));
  console.log('Ready for npm run dev. Existing records were retained; no frameworks or assignments were deleted or reseeded.');
} catch {
  console.error('Shared development preparation stopped. Check local configuration, saved account files and migration status. No automatic reset or overwrite is performed.');
  if (backup) console.error(`Preserved private backup: ${backup}`);
  process.exitCode = 1;
} finally { await db?.$disconnect(); }
