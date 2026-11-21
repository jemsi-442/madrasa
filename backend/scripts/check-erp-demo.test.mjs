import test from 'node:test';
import assert from 'node:assert/strict';
import { checkErpDemo } from './check-erp-demo.mjs';

function fixture(counts = [2, 1, 1, 1, 1], users = [1, 1]) {
  const queries = [];
  return { queries, db: {
    organization: { findUnique: async () => ({ id: 7n, status: 'ACTIVE' }) },
    student: { count: async query => { queries.push(query); return counts.shift(); } },
    user: { count: async query => { queries.push(query); return users.shift(); } },
  } };
}

test('checks same-student links and tenant scope without exposing records', async () => {
  const { db, queries } = fixture();
  const result = await checkErpDemo(db);
  assert.equal(result.relationshipReady, true);
  assert.equal(result.sharedLearners, 1);
  assert.equal(queries.length, 7);
  for (const query of queries) assert.equal(query.where.orgId, 7n);
  const shared = queries[3].where;
  assert.equal(shared.learnerUser.is.role, 'LEARNER');
  assert.equal(shared.currentClass.is.teacher.is.role, 'TEACHER');
  assert.equal(shared.currentClass.is.orgId, 7n);
  assert.equal(shared.guardians.some.guardian.is.user.is.role, 'PARENT');
  assert.equal(shared.guardians.some.guardian.is.orgId, 7n);
  assert.equal(queries[4].where.invoices.some.orgId, 7n);
  assert.equal(JSON.stringify(result).includes('password'), false);
});

test('separate teacher and parent links do not prove a shared learner exists', async () => {
  assert.equal((await checkErpDemo(fixture([2, 1, 1, 0, 0]).db)).relationshipReady, false);
});

test('requires admin and accountant accounts', async () => {
  assert.equal((await checkErpDemo(fixture(undefined, [1, 0]).db)).relationshipReady, false);
});

test('stops before querying records for missing or inactive madrasa', async () => {
  for (const org of [null, { id: 7n, status: 'SUSPENDED' }]) {
    const { db, queries } = fixture();
    db.organization.findUnique = async () => org;
    await assert.rejects(checkErpDemo(db), /Active demo madrasa required/);
    assert.equal(queries.length, 0);
  }
});
