import { readFile, lstat, realpath } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { z } from 'zod';

async function main() {
  if (process.argv[2] !== '--confirm-local-demo') throw Error('Explicit demo flag required');
  const file = resolve(process.argv[3] ?? '');
  if (!/^\/tmp\/afaq-local-demo-[A-Za-z0-9]+\/credentials\.json$/.test(file) || await realpath(file) !== file) throw Error('Not demo credentials');
  const stat = await lstat(file);
  if (!stat.isFile() || (stat.mode & 0o077) !== 0 || (process.getuid && stat.uid !== process.getuid())) throw Error('Unsafe credentials file');
  const accounts = z.array(z.object({ email: z.string().email(), password: z.string(), role: z.string() })).parse(JSON.parse(await readFile(file, 'utf8')));
  const request = (path: string, options: RequestInit = {}) => fetch(`http://127.0.0.1:4087/api${path}`, {
    ...options, redirect: 'error', signal: AbortSignal.timeout(10000),
  });
  assert.equal((await request('/platform/curriculum')).status, 401);
  console.log('PASS: unauthenticated curriculum access denied');
  for (const role of ['SUPER_ADMIN', 'IT_SECURITY']) {
    const account = accounts.find(a => a.role === role);
    assert(account);
    const response = await request('/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ login: account.email, password: account.password }) });
    assert(response.ok);
    const session = z.object({ data: z.object({ accessToken: z.string() }) }).parse(await response.json()).data;
    const headers = { Authorization: `Bearer ${session.accessToken}`, 'Content-Type': 'application/json' };
    try {
      const result = await request('/platform/curriculum', { headers });
      if (role === 'IT_SECURITY') {
        assert.equal(result.status, 403);
        const denied = await request('/platform/curriculum/not-a-record/lessons', { method: 'POST', headers,
          body: JSON.stringify({ title: 'Denied test', position: 1, durationMinutes: 30,
            activities: 'This test must not create a lesson', objectiveIds: ['not-an-objective'] }) });
        assert.equal(denied.status, 403);
        console.log('PASS: IT cannot read curriculum or create lesson plans');
      } else {
        assert(result.ok);
        const payload = await result.json() as { data: { items: Array<{ id: string; subject: string }> } };
        const example = payload.data.items.find(row => row.subject === 'Fiqh (Demo)');
        assert(example, 'Prepare the demo example first');
        const detail = await request(`/platform/curriculum?id=${encodeURIComponent(example.id)}`, { headers });
        assert(detail.ok);
        const data = await detail.json() as { data: { items: Array<{ status: string; level: string; topics: Array<{ objectives: Array<{ id: string }> }>; lessons: Array<{ objectives: Array<{ objectiveId: string }> }>; assignments: unknown[] }> } };
        const row = data.data.items[0]!;
        assert.equal(row.status, 'DRAFT'); assert.equal(row.level, 'Level 1');
        assert.equal(row.topics.length, 2); assert.equal(row.lessons.length, 2);
        const ids = new Set(row.topics.flatMap(t => t.objectives.map(o => o.id)));
        assert.equal(ids.size, 3);
        assert(row.lessons.every(l => l.objectives.length === 2 && l.objectives.every(o => ids.has(o.objectiveId))));
        assert.equal(row.assignments.length, 0);
        console.log('PASS: real HTTP readback of persisted Fiqh demo: 2 topics, 3 objectives, 2 correctly linked lessons; draft and unassigned');
      }
    } finally {
      assert((await request('/platform/logout', { method: 'POST', headers })).ok);
    }
  }
  console.log('PASS: test sessions logged out. No passwords or student information printed.');
}
main().catch(() => { console.error('Curriculum HTTP check failed; sensitive response details withheld.'); process.exitCode = 1; });
