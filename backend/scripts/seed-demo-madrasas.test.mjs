import { test } from 'node:test';
import assert from 'node:assert/strict';
import { demoMadrasaLocations, seedDemoMadrasas } from './seed-demo-madrasas.mjs';

test('demo locations are complete, distinct and visibly synthetic institutions', async () => {
  const rows = await demoMadrasaLocations();
  assert.equal(rows.length, 5);
  assert.equal(new Set(rows.map(row => row.code)).size, 5);
  for (const row of rows) {
    assert.match(row.name, /\(Demo\)$/);
    for (const key of ['country', 'region', 'district', 'ward', 'village']) assert.ok(row.location[key]);
    assert.equal(row.location.street, undefined);
    assert.equal(row.location.hamlet, undefined);
  }
});

test('reruns preserve existing demo edits and do not duplicate schools', async () => {
  const records = new Map();
  const tx = { organization: {
    findUnique: async ({ where }) => records.get(where.code) ?? null,
    create: async ({ data }) => { records.set(data.code, { ...data }); },
    updateMany: async ({ where }) => {
      assert.equal(where.code, 'demo-madrasa');
      assert.ok(where.location.equals);
      return { count: 0 };
    },
  } };
  const db = { $transaction: fn => fn(tx) };
  assert.equal((await seedDemoMadrasas(db)).created, 5);
  const first = records.values().next().value;
  first.location = { country: 'User edited location' };
  first.status = 'SUSPENDED';
  assert.equal((await seedDemoMadrasas(db)).created, 0);
  assert.equal(records.size, 5);
  assert.deepEqual(first.location, { country: 'User edited location' });
  assert.equal(first.status, 'SUSPENDED');
});
