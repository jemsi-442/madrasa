import { test } from 'node:test';
import assert from 'node:assert/strict';
import { prepareErpDemo } from './prepare-erp-demo.mjs';

function fixture(name = 'Demo Madrasa', status = 'ACTIVE') {
  const org = { id: 1n, code: 'demo-madrasa', name, status };
  const writes = [];
  const tx = {
    organization: {
      findUnique: async ({ where }) => { assert.equal(where.code, org.code); return org; },
      update: async ({ where, data }) => {
        assert.equal(where.id, org.id);
        assert.deepEqual(Object.keys(data), ['name']);
        writes.push(data); Object.assign(org, data);
      },
    },
    user: { groupBy: async () => ['ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT', 'LEARNER']
      .map(role => ({ role, _count: 1 })) },
  };
  for (const model of ['class', 'student', 'course', 'classCurriculum', 'attendanceRecord',
    'assessment', 'invoice', 'payment', 'studentGuardian', 'curriculumAssignment']) {
    tx[model] = { count: async ({ where }) => {
      assert.equal(where[model === 'curriculumAssignment' ? 'organizationId' : 'orgId'], org.id);
      return 1;
    } };
  }
  return { db: { $transaction: fn => fn(tx) }, tx, writes };
}

test('renames only the demo display name and is idempotent', async () => {
  const { db, writes } = fixture();
  assert.equal((await prepareErpDemo(db)).renamed, true);
  assert.equal((await prepareErpDemo(db)).renamed, false);
  assert.deepEqual(writes, [{ name: 'Afaq Demo Madrasa' }]);
});

test('preserves customised names and inactive schools', async () => {
  for (const args of [['Custom name'], ['Demo Madrasa', 'SUSPENDED']]) {
    const { db, writes } = fixture(...args);
    await assert.rejects(prepareErpDemo(db));
    assert.equal(writes.length, 0);
  }
});

test('missing roles stop preparation before renaming', async () => {
  const { db, tx, writes } = fixture();
  tx.user.groupBy = async () => [{ role: 'ADMIN', _count: 1 }];
  await assert.rejects(prepareErpDemo(db));
  assert.equal(writes.length, 0);
});
