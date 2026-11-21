import { PrismaClient } from '@prisma/client';
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';

// Fixed loopback origin prevents accidentally sending saved credentials elsewhere.
const origin = 'http://127.0.0.1:4000/api';
class CheckFailure extends Error {}
export async function checkErpDemoApi(db, saved, request = fetch) {
  const sessions = [];
  const checks = [];
  const expect = (condition, label) => {
    if (!condition) throw new CheckFailure(label);
    checks.push(label);
  };
  async function call(path, token, body) {
    const response = await request(`${origin}${path}`, {
      method: body ? 'POST' : 'GET', redirect: 'error',
      headers: { 'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(15000),
    });
    const payload = await response.json();
    return { status: response.status, data: payload.data };
  }
  try {
    const org = await db.organization.findUnique({ where: { code: 'demo-madrasa' },
      select: { id: true, status: true } });
    expect(org?.status === 'ACTIVE', 'Active demo madrasa');
    const active = role => ({ orgId: org.id, status: 'ACTIVE', role });
    const identity = { id: true, email: true, familyLoginId: true, phone: true, role: true };
    const student = await db.student.findFirst({ where: {
      orgId: org.id, status: 'ACTIVE',
      learnerUser: { is: { ...active('LEARNER'), email: { endsWith: '.test' } } },
      currentClass: { is: { orgId: org.id, teacher: { is: active('TEACHER') } } },
      guardians: { some: { orgId: org.id,
        guardian: { is: { orgId: org.id, user: { is: active('PARENT') } } } } },
    }, orderBy: { id: 'asc' }, select: {
      id: true, learnerUser: { select: identity },
      currentClass: { select: { teacher: { select: identity } } },
      guardians: { where: { orgId: org.id,
        guardian: { is: { orgId: org.id, user: { is: active('PARENT') } } } },
        select: { guardian: { select: { user: { select: identity } } } } },
    } });
    expect(Boolean(student), 'Shared synthetic learner found');
    const actors = [student.learnerUser, student.currentClass.teacher,
      student.guardians[0].guardian.user];
    for (const role of ['ADMIN', 'ACCOUNTANT']) {
      actors.push(await db.user.findFirst({ where: active(role), orderBy: { id: 'asc' }, select: identity }));
    }
    // Validate every saved identity before starting any login attempts.
    const accounts = actors.map(actor => {
      const row = actor && saved.find(item => item.role === actor.role &&
        [actor.email, actor.familyLoginId, actor.phone].filter(Boolean)
          .some(login => login === (item.login || item.email)));
      if (!row?.password) throw new CheckFailure('Saved role credentials missing');
      return { actor, row };
    });
    const sid = String(student.id);
    for (const { actor, row } of accounts) {
      const login = await call('/auth/login', null, { login: row.login || row.email, password: row.password });
      if (login.data?.refreshToken) sessions.push(login.data.refreshToken);
      expect(login.status === 200 && Boolean(login.data?.accessToken), `${actor.role}: login`);
      const token = login.data.accessToken;
      const me = await call('/auth/me', token);
      expect(me.status === 200 && String(me.data?.orgId) === String(org.id) &&
        String(me.data?.userId) === String(actor.id) && me.data?.role === actor.role,
      `${actor.role}: correct identity and madrasa`);
      if (actor.role === 'LEARNER') {
        const profile = await call('/learner/me', token);
        expect(profile.status === 200 && profile.data?.student?.id === sid, 'Learner sees own student');
        const denied = await call('/invoices', token);
        expect(denied.status === 403, 'Learner denied accounting invoice list');
      } else if (actor.role === 'TEACHER' || actor.role === 'ADMIN') {
        const path = actor.role === 'TEACHER' ? `/teacher-workspace/students/${sid}` : `/admin/students/${sid}/course-progress`;
        const profile = await call(path, token);
        expect(profile.status === 200 && profile.data?.student?.id === sid, `${actor.role}: same student profile`);
      } else if (actor.role === 'PARENT') {
        const children = await call('/parent-portal/students', token);
        expect(children.status === 200 && children.data?.some(child => child.id === sid), 'Parent sees linked student');
        for (const area of ['attendance', 'finance', 'hifdh']) {
          const result = await call(`/parent-portal/students/${sid}/${area}`, token);
          expect(result.status === 200, `Parent: ${area} accessible`);
        }
      } else {
        const invoices = await call(`/invoices?studentId=${sid}`, token);
        expect(invoices.status === 200, 'Accountant: student invoice endpoint accessible');
        const denied = await call(`/teacher-workspace/students/${sid}`, token);
        expect(denied.status === 403, 'Accountant denied teacher workspace');
      }
    }
  } finally {
    let failed = false;
    for (const refreshToken of sessions) {
      try { if ((await call('/auth/logout', null, { refreshToken })).status !== 200) failed = true; }
      catch { failed = true; }
    }
    if (failed) throw new CheckFailure('Check-session cleanup failed');
  }
  return { checks, sessionsClosed: sessions.length,
    note: 'Read-only API smoke check. Login/logout create session and audit records. No teaching, payment or message writes.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let db;
  try {
    const env = await developmentEnvironment(new URL('../.env', import.meta.url));
    const saved = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/credentials.json'), 'utf8'));
    db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
    console.log(JSON.stringify(await checkErpDemoApi(db, saved), null, 2));
  } catch (error) {
    // Only our fixed checkpoint labels are safe; provider/database errors can contain secrets.
    console.error('ERP API check stopped. No teaching, finance or credential changes were requested.');
    if (error instanceof CheckFailure) console.error(error.message);
    process.exitCode = 1;
  } finally { await db?.$disconnect(); }
}
