// Opt-in real MariaDB/Redis test; never uses the developer's HOME or database.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { once } from 'node:events';

test('framework and assignment survive a real demo stop/start', {
  skip: process.env.AFAQ_TEST_PERSISTENCE !== '1', timeout: 300_000,
}, async () => {
  const home = await mkdtemp(join(tmpdir(), 'afaq-persist-'));
  const runtime = join(home, '.afaq/platform-demo/runtime');
  const root = fileURLToPath(new URL('../', import.meta.url));
  let child;
  const start = async () => {
    child = spawn(process.execPath, ['--import', 'tsx', 'scripts/platform-local-demo.ts', '--start'], {
      cwd: root, env: { ...process.env, HOME: home, NODE_ENV: 'development', QF_ENABLED: 'false' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    child.stderr.resume();
    let ready = false;
    child.stdout.on('data', chunk => { if (String(chunk).includes('Demo API:')) ready = true; });
    for (let i = 0; i < 1100; i++) {
      if (ready) return;
      if (child.exitCode !== null || child.signalCode !== null) throw new Error('Isolated test demo failed to start; output redacted.');
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    throw new Error('Isolated test demo startup timed out.');
  };
  const stop = async () => {
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
    const exited = once(child, 'exit');
    child.kill('SIGTERM');
    const [code] = await exited;
    assert.equal(code, 0);
  };
  const sql = async query => {
    const state = JSON.parse(await readFile(join(runtime, 'state.json'), 'utf8'));
    try {
      return execFileSync('mariadb', ['--no-defaults', '--skip-ssl', `--socket=${join(runtime, 'mysql.sock')}`, '-uroot',
        '--batch', '--skip-column-names', 'afaq_local_demo', '-e', query], {
        env: { ...process.env, HOME: home, MYSQL_PWD: state.password }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
      }).trim();
    } catch (error) {
      const code = String(error.stderr ?? '').match(/ERROR (\d+)/)?.[1] ?? 'unknown';
      throw new Error(`Synthetic persistence query failed (MariaDB ${code}); details redacted.`);
    }
  };
  const digest = async () => createHash('sha256').update(await readFile(join(runtime, 'state.json'))).digest('hex');
  try {
    await start();
    await sql(`INSERT INTO curriculum_versions
      (id, subject, level, version, description, objectives, status, createdBy, updatedAt)
      VALUES ('persist-test', 'Synthetic persistence subject', 'Test', '1.0', 'Synthetic test only', '[]', 'PUBLISHED', 'test-actor', NOW());
      INSERT INTO curriculum_assignments (id, versionId, organizationId, assignedBy)
      SELECT 'persist-assignment', 'persist-test', id, 'test-actor' FROM organizations LIMIT 1;`);
    const before = await digest();
    const counts = await sql('SELECT COUNT(*) FROM platform_accounts; SELECT COUNT(*) FROM users;');
    await stop();
    await start();
    assert.equal(await sql("SELECT COUNT(*) FROM curriculum_versions WHERE id='persist-test'"), '1');
    assert.equal(await sql("SELECT COUNT(*) FROM curriculum_assignments WHERE id='persist-assignment' AND versionId='persist-test'"), '1');
    assert.equal(await sql('SELECT COUNT(*) FROM platform_accounts; SELECT COUNT(*) FROM users;'), counts);
    assert.equal(await digest(), before, 'Private authentication keys must survive restart');
  } finally {
    await stop();
    // Only this test's synthetic HOME is removed, after all demo services exit.
    await rm(home, { recursive: true, force: true });
  }
});
