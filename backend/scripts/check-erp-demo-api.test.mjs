import test from 'node:test';
import assert from 'node:assert/strict';
import { checkErpDemoApi } from './check-erp-demo-api.mjs';

function fixture() {
  const roles = ['LEARNER', 'TEACHER', 'PARENT', 'ADMIN', 'ACCOUNTANT'];
  const actors = roles.map((role, i) => ({ id: BigInt(i + 1), role,
    email: `${role.toLowerCase()}@example.test` }));
  const saved = actors.map(actor => ({ ...actor, password: 'synthetic-test-only' }));
  const calls = [];
  const db = {
    organization: { findUnique: async () => ({ id: 9n, status: 'ACTIVE' }) },
    student: { findFirst: async query => {
      assert.equal(query.where.learnerUser.is.email.endsWith, '.test');
      assert.equal(query.where.orgId, 9n);
      return { id: 12n, learnerUser: actors[0], currentClass: { teacher: actors[1] },
        guardians: [{ guardian: { user: actors[2] } }] };
    } },
    user: { findFirst: async query => actors.find(actor => actor.role === query.where.role) },
  };
  const request = async (url, options) => {
    calls.push({ url, options });
    const path = new URL(url).pathname.replace('/api', '');
    const role = options.headers.Authorization?.replace('Bearer ', '');
    let status = 200, data = {};
    if (path === '/auth/login') {
      const actor = actors.find(item => item.email === JSON.parse(options.body).login);
      data = { accessToken: actor.role, refreshToken: `test-${actor.role}` };
    } else if (path === '/auth/me') {
      data = { orgId: '9', userId: String(actors.find(item => item.role === role).id), role };
    } else if (path === '/parent-portal/students') data = [{ id: '12' }];
    else if ((path === '/invoices' && role === 'LEARNER') ||
      (path.startsWith('/teacher-workspace') && role === 'ACCOUNTANT')) status = 403;
    else data = { student: { id: '12' } };
    return { status, json: async () => ({ data }) };
  };
  return { db, saved, request, calls };
}

test('checks five identities and closes only the sessions it creates', async () => {
  const f = fixture();
  const result = await checkErpDemoApi(f.db, f.saved, f.request);
  assert.equal(result.sessionsClosed, 5);
  assert.equal(f.calls.filter(call => call.url.endsWith('/auth/logout')).length, 5);
  for (const { url, options } of f.calls) {
    assert.equal(new URL(url).origin, 'http://127.0.0.1:4000');
    if (options.method === 'POST') assert.match(url, /\/auth\/(login|logout)$/);
  }
});

test('missing synthetic learner stops before any login', async () => {
  const f = fixture();
  f.db.student.findFirst = async () => null;
  await assert.rejects(checkErpDemoApi(f.db, f.saved, f.request), /Shared synthetic learner/);
  assert.equal(f.calls.length, 0);
});

test('failure after login still closes the created session', async () => {
  const f = fixture();
  const request = (url, options) => url.endsWith('/auth/me')
    ? Promise.resolve({ status: 403, json: async () => ({}) }) : f.request(url, options);
  await assert.rejects(checkErpDemoApi(f.db, f.saved, request), /correct identity/);
  assert.equal(f.calls.filter(call => call.url.endsWith('/auth/logout')).length, 1);
});

test('all credentials must exist before login attempts', async () => {
  const f = fixture();
  await assert.rejects(checkErpDemoApi(f.db, f.saved.slice(0, 2), f.request), /credentials missing/);
  assert.equal(f.calls.length, 0);
});
