import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ensureTeacherDashboardDemo, demoEventId } from './teacher-dashboard-demo.mjs';

function fixture() {
  let rows = {
    organization: [{ id: 1n, code: 'demo-madrasa', status: 'ACTIVE' }],
    user: [{ id: 2n, orgId: 1n, branchId: 3n, email: 'quran.teacher@afaq.test', role: 'TEACHER', status: 'ACTIVE' },
      { id: 4n, orgId: 1n, email: 'schooladmin@afaq.test', role: 'ADMIN', status: 'ACTIVE' }],
    subject: [{ id: 5n, orgId: 1n, name: 'Existing subject' }],
    class: [], student: [], classTimetableSlot: [], attendanceRecord: [], quranSession: [], studentSupportNote: [], auditLog: [],
  };
  const matches = (row, where) => Object.entries(where).every(([key, value]) =>
    value && typeof value === 'object' ? matches(row, value) : row[key] === value);
  const tx = Object.fromEntries(Object.keys(rows).map(model => [model, {
    findUnique: async ({ where }) => rows[model].find(row => matches(row, where)) ?? null,
    findFirst: async ({ where }) => rows[model].find(row => matches(row, where)) ?? null,
    findMany: async ({ where }) => rows[model].filter(row => matches(row, where)),
    create: async ({ data }) => {
      const row = { id: BigInt(rows[model].length + 10), ...(model === 'student' ? { status: 'ACTIVE' } : {}), ...data };
      rows[model].push(row); return row;
    },
  }]));
  return { get rows() { return rows; }, async $transaction(fn) {
    const snapshot = structuredClone(rows);
    try { return await fn(tx); } catch (error) { rows = snapshot; throw error; }
  } };
}

test('adds synthetic dashboard data once and preserves edits on later days', async () => {
  const db = fixture();
  const first = await ensureTeacherDashboardDemo(db, new Date('2026-10-27T08:00:00Z'));
  assert.deepEqual(first.created, { classes: 3, learners: 18, timetable: 15, attendance: 18, quran: 18, followUps: 6 });
  db.rows.studentSupportNote[0].resolvedAt = new Date();
  db.rows.quranSession[0].voidedAt = new Date();
  db.rows.classTimetableSlot[0].focus = 'Edited demo schedule';
  db.rows.classTimetableSlot[0].cancelledAt = new Date();
  db.rows.attendanceRecord[0].status = 'ABSENT';
  const snapshot = structuredClone(db.rows);
  const second = await ensureTeacherDashboardDemo(db, new Date('2026-10-28T08:00:00Z'));
  assert.ok(Object.values(second.created).every(count => count === 0));
  assert.deepEqual(db.rows, snapshot);
  assert.ok(db.rows.student.every(row => row.fullName.startsWith('Demo Learner')));
  assert.equal(new Set(db.rows.quranSession.map(row => row.clientId)).size, 18);
});

test('refuses changed class ownership and leaves existing records intact', async () => {
  const db = fixture();
  await ensureTeacherDashboardDemo(db);
  db.rows.class[1].teacherId = 999n;
  const snapshot = structuredClone(db.rows);
  await assert.rejects(ensureTeacherDashboardDemo(db), /assignment changed/);
  assert.deepEqual(db.rows, snapshot);
});

test('requires active demo accounts and stable UUID event identifiers', async () => {
  const db = fixture();
  db.rows.user[0].status = 'DISABLED';
  await assert.rejects(ensureTeacherDashboardDemo(db), /demo teacher/);
  assert.equal(db.rows.class.length, 0);
  assert.match(demoEventId('sample'), /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}$/);
});
