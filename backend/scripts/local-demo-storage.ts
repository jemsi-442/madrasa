import { randomBytes } from 'node:crypto';
import { chmod, mkdir, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export type DemoState = {
  version: 1;
  initialized: boolean;
  password: string;
  encryptionKey: string;
  signingKey: string;
  jwtSecret: string;
  refreshSecret: string;
};

export async function lockDemo(directory: string) {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await chmod(directory, 0o700);
  const lock = join(directory, 'running.lock');
  try { await mkdir(lock, { mode: 0o700 }); }
  catch { throw new Error('Demo is locked. Stop the existing runner first. After a crash, verify no demo services are running before removing running.lock.'); }
  await writeFile(join(lock, 'owner.pid'), String(process.pid), { mode: 0o600 });
  return () => rm(lock, { recursive: true, force: true });
}

export async function saveDemoState(directory: string, state: DemoState) {
  const temporary = join(directory, 'state.json.tmp');
  await writeFile(temporary, JSON.stringify(state), { mode: 0o600 });
  await chmod(temporary, 0o600);
  await rename(temporary, join(directory, 'state.json'));
}

export async function loadDemoState(directory: string): Promise<{ state: DemoState; fresh: boolean }> {
  let raw: string;
  try { raw = await readFile(join(directory, 'state.json'), 'utf8'); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    // Never initialize over unrecognized or partially initialized data.
    const entries = await readdir(directory);
    if (entries.some(entry => entry !== 'running.lock')) {
      throw new Error('Existing demo files have no state file. Preserve this directory and recover it; no database was initialized.');
    }
    const key = () => randomBytes(32).toString('hex');
    const state: DemoState = { version: 1, initialized: false, password: key(), encryptionKey: key(), signingKey: key(), jwtSecret: key(), refreshSecret: key() };
    await saveDemoState(directory, state);
    return { state, fresh: true };
  }
  let state: DemoState;
  try { state = JSON.parse(raw) as DemoState; }
  catch { throw new Error('Demo state is invalid; restore the private backup.'); }
  if (!state || state.version !== 1 || state.initialized !== true ||
      ['password', 'encryptionKey', 'signingKey', 'jwtSecret', 'refreshSecret'].some(key =>
        !/^[a-f0-9]{64}$/.test(String(state[key as keyof DemoState])))) {
    throw new Error('Demo initialization is incomplete or state is invalid. Preserve the directory for recovery; automatic reset is disabled.');
  }
  const data = await readdir(join(directory, 'data'));
  if (!data.includes('afaq_local_demo')) throw new Error('Saved demo database is missing; restore a backup instead of creating an empty replacement.');
  return { state, fresh: false };
}
