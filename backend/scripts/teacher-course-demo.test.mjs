import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ensureTeacherCourseDemo } from './teacher-course-demo.mjs';

function fixture() {
  let saved = null;
  const rows = { modules: [], lessons: [], assets: [] };
  const tx = {
    organization: { findUnique: async () => ({ id: 1n, status: 'ACTIVE' }) },
    user: { findFirst: async () => ({ id: 2n }) },
    subject: { findFirst: async () => ({ id: 3n }) },
    course: { findUnique: async () => saved, create: async ({ data }) => (saved = { id: 4n, ...data }) },
    courseModule: { create: async ({ data }) => { rows.modules.push(data); return { id: 5n }; } },
    courseLesson: { create: async ({ data }) => { rows.lessons.push(data); return { id: BigInt(rows.lessons.length + 5) }; } },
    mediaAsset: { create: async ({ data }) => { rows.assets.push(data); return data; } },
  };
  return { tx, rows, db: { $transaction: async callback => callback(tx) } };
}

test('creates one draft course and reruns without duplicate or overwritten content', async () => {
  const f = fixture();
  assert.equal((await ensureTeacherCourseDemo(f.db)).created, true);
  assert.equal((await ensureTeacherCourseDemo(f.db)).created, false);
  assert.equal(f.rows.modules.length, 1);
  assert.equal(f.rows.lessons.length, 2);
  assert.equal(f.rows.assets.length, 4);
  assert.ok(f.rows.lessons.every(row => row.publicationStatus === 'DRAFT'));
});

test('does not take a course from another teacher', async () => {
  const f = fixture();
  f.tx.course.findUnique = async () => ({ id: 4n, primaryInstructorUserId: 99n });
  await assert.rejects(ensureTeacherCourseDemo(f.db), /nothing was overwritten/);
  assert.equal(f.rows.assets.length, 0);
});

test('does not create subjects or use a missing demo account', async () => {
  const f = fixture();
  f.tx.user.findFirst = async () => null;
  await assert.rejects(ensureTeacherCourseDemo(f.db), /demo teacher required/);
  assert.equal(f.rows.modules.length, 0);
});
