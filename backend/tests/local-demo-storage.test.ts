import { mkdtemp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, expect, test } from 'vitest';
import { loadDemoState, lockDemo, saveDemoState } from '../scripts/local-demo-storage';

const directories: string[] = [];
async function fixture() {
  const directory = await mkdtemp(join(tmpdir(), 'afaq-storage-test-'));
  directories.push(directory);
  return directory;
}
afterEach(async () => { await Promise.all(directories.splice(0).map(dir => rm(dir, { recursive: true, force: true }))); });

test('restart preserves database files, keys and ready state without reseeding', async () => {
  const directory = await fixture();
  const unlock = await lockDemo(directory);
  const initial = await loadDemoState(directory);
  expect(initial.fresh).toBe(true);
  await mkdir(join(directory, 'data', 'afaq_local_demo'), { recursive: true });
  await writeFile(join(directory, 'data', 'afaq_local_demo', 'synthetic-record'), 'framework-and-assignment');
  await saveDemoState(directory, { ...initial.state, initialized: true });
  await unlock();
  const release = await lockDemo(directory);
  const resumed = await loadDemoState(directory);
  expect(resumed).toEqual({ fresh: false, state: { ...initial.state, initialized: true } });
  expect(await readFile(join(directory, 'data', 'afaq_local_demo', 'synthetic-record'), 'utf8')).toBe('framework-and-assignment');
  expect((await stat(join(directory, 'state.json'))).mode & 0o777).toBe(0o600);
  await release();
});

test('second runner is rejected without removing the first lock', async () => {
  const directory = await fixture();
  const release = await lockDemo(directory);
  await expect(lockDemo(directory)).rejects.toThrow('locked');
  expect(await readFile(join(directory, 'running.lock', 'owner.pid'), 'utf8')).toBe(String(process.pid));
  await release();
});

test('interrupted initialization never automatically recreates a database', async () => {
  const directory = await fixture();
  await loadDemoState(directory);
  await expect(loadDemoState(directory)).rejects.toThrow('incomplete');
});

test('unrecognized data is left intact', async () => {
  const directory = await fixture();
  await writeFile(join(directory, 'old-backup'), 'preserve');
  await expect(loadDemoState(directory)).rejects.toThrow('no state');
  expect(await readFile(join(directory, 'old-backup'), 'utf8')).toBe('preserve');
});

test('missing database fails closed even with valid saved keys', async () => {
  const directory = await fixture();
  const { state } = await loadDemoState(directory);
  await saveDemoState(directory, { ...state, initialized: true });
  await expect(loadDemoState(directory)).rejects.toThrow();
  expect(JSON.parse(await readFile(join(directory, 'state.json'), 'utf8')).initialized).toBe(true);
});

test('corrupt state is not overwritten or exposed in errors', async () => {
  const directory = await fixture();
  await writeFile(join(directory, 'state.json'), 'private-invalid-value');
  await expect(loadDemoState(directory)).rejects.toThrow('state is invalid');
  expect(await readFile(join(directory, 'state.json'), 'utf8')).toBe('private-invalid-value');
});
