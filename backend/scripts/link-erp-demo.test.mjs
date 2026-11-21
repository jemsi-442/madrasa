import test from 'node:test';
import assert from 'node:assert/strict';
import { linkErpDemo } from './link-erp-demo.mjs';

function fixture() {
  const student = { id: 2n, branchId: 3n, classId: null };
  const links = new Set();
  let updates = 0;
  const tx = {
    organization: { findUnique: async () => ({ id: 1n, status: 'ACTIVE' }) },
    student: {
      findMany: async query => {
        assert.equal(query.where.orgId, 1n);
        assert.equal(query.where.learnerUser.is.email.endsWith, '.test');
        return [{ ...student }];
      },
      updateMany: async query => {
        assert.equal(query.where.classId, null);
        assert.equal(query.where.branchId, 3n);
        assert.deepEqual(query.data, { classId: 4n });
        updates++; student.classId = 4n;
        return { count: 1 };
      },
    },
    class: { findFirst: async query => {
      assert.equal(query.where.orgId, 1n);
      assert.equal(query.where.branchId, 3n);
      assert.equal(query.where.teacher.is.orgId, 1n);
      if (query.where.id) assert.equal(query.where.id, student.classId);
      return { id: 4n };
    } },
    guardian: { findFirst: async query => {
      assert.equal(query.where.orgId, 1n);
      assert.equal(query.where.user.is.email, 'parent@afaq.test');
      return { id: 5n };
    } },
    studentGuardian: { upsert: async query => {
      assert.deepEqual(query.update, {});
      assert.equal(query.create.isPrimary, false);
      assert.equal(query.create.orgId, 1n);
      links.add(`${query.create.studentId}:${query.create.guardianId}`);
    } },
  };
  return { tx, student, links, updates: () => updates, db: { $transaction: fn => fn(tx) } };
}

test('reuses class and parent; reruns do not replace class or duplicate links', async () => {
  const f = fixture();
  await linkErpDemo(f.db);
  await linkErpDemo(f.db);
  assert.equal(f.updates(), 1);
  assert.equal(f.links.size, 1);
});

test('ambiguous test learners stop before any writes', async () => {
  const f = fixture();
  f.tx.student.findMany = async () => [f.student, f.student];
  await assert.rejects(linkErpDemo(f.db), /Exactly one/);
  assert.equal(f.updates(), 0);
  assert.equal(f.links.size, 0);
});

test('incompatible existing class is not replaced', async () => {
  const f = fixture();
  f.student.classId = 99n;
  f.tx.class.findFirst = async query => {
    assert.equal(query.where.id, 99n);
    return null;
  };
  await assert.rejects(linkErpDemo(f.db), /Compatible/);
  assert.equal(f.updates(), 0);
  assert.equal(f.links.size, 0);
});

test('concurrent assignment prevents guardian write', async () => {
  const f = fixture();
  f.tx.student.updateMany = async () => ({ count: 0 });
  await assert.rejects(linkErpDemo(f.db), /concurrently/);
  assert.equal(f.links.size, 0);
});
