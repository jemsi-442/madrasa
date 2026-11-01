import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';
import { teacherDemoSlug } from './teacher-course-demo.mjs';

await developmentEnvironment(fileURLToPath(new URL('../.env', import.meta.url)));
const base = 'http://127.0.0.1:4000';
const account = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/teacher-credentials.json'), 'utf8'));
if (account.email !== 'quran.teacher@afaq.test') throw new Error('Synthetic teacher account required.');
const request = (path, options = {}) => fetch(base + path, { ...options, redirect: 'manual', signal: AbortSignal.timeout(10000) });
let session;
try {
  const login = await request('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ login: account.email, password: account.password }) });
  if (!login.ok) throw new Error('login');
  session = (await login.json()).data;
  const load = async path => {
    const response = await request(path, { headers: { Authorization: `Bearer ${session.accessToken}` } });
    if (!response.ok) throw new Error('authorized request');
    return (await response.json()).data;
  };
  const course = (await load('/api/teaching/courses')).find(row => row.slug === teacherDemoSlug);
  if (!course) throw new Error('demo assignment');
  let checked = 0;
  for (const module of await load(`/api/courses/${course.id}/modules`)) {
    for (const lesson of await load(`/api/courses/modules/${module.id}/lessons`)) {
      for (const asset of await load(`/api/courses/lessons/${lesson.id}/assets`)) {
        const opened = await load(`/api/courses/assets/${asset.id}/open`);
        if (opened.delivery.status !== 'READY') throw new Error('source');
        const url = new URL(opened.delivery.inlineUrl, base);
        if (url.origin !== base) throw new Error('origin');
        const response = await request(url.pathname + url.search, { headers: { Range: 'bytes=0-31' } });
        if (response.status !== 206 || response.headers.get('cache-control') !== 'no-store' ||
            (await response.arrayBuffer()).byteLength !== 32) throw new Error('range delivery');
        const denied = await request(url.pathname);
        if (denied.status !== 401) throw new Error('unsigned delivery');
        checked++;
      }
    }
  }
  if (checked !== 4) throw new Error('sample count');
  console.log('PASS: assigned demo course, 4 authorized resources, byte-range delivery and unsigned access denial.');
} catch {
  console.error('FAIL: teacher media check. Start the shared development API and prepare the teacher demo course first.');
  process.exitCode = 1;
} finally {
  if (session?.refreshToken) {
    const response = await request('/api/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: session.refreshToken }) });
    if (!response.ok) { console.error('Test session logout failed.'); process.exitCode = 1; }
  }
}
