import { PrismaClient } from '@prisma/client';
import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { developmentEnvironment } from './development-config.mjs';

// Only this local demonstration is provisioned; existing teaching drafts stay intact.
const slug = 'afaq-shared-video-demo';
const origin = 'http://127.0.0.1:4000';
const sessions = [];
let db;
let stage = 'Local preflight';
async function call(path, token, method = 'GET', body) {
  stage = `${method} ${path.split('?')[0]}`;
  const response = await fetch(`${origin}/api${path}`, {
    method, redirect: 'error', signal: AbortSignal.timeout(15000),
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!response.ok) throw new Error(`API ${method} failed (${response.status})`);
  return (await response.json()).data;
}
try {
  if (!process.argv.includes('--confirm-local-development')) throw new Error('Local confirmation required');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
  const org = await db.organization.findUnique({ where: { code: 'demo-madrasa' } });
  if (org?.status !== 'ACTIVE') throw new Error('Active demo required');
  const saved = JSON.parse(await readFile(join(homedir(), '.afaq/platform-demo/credentials.json'), 'utf8'));
  const tokens = {};
  const actors = {};
  for (const [role, email] of [['ADMIN', 'schooladmin@afaq.test'], ['TEACHER', 'quran.teacher@afaq.test'], ['LEARNER', 'learner@example.com']]) {
    const actor = await db.user.findFirst({ where: { orgId: org.id, role, email, status: 'ACTIVE' } });
    const credential = saved.find(row => row.role === role && (row.login || row.email) === email);
    if (!actor || !credential?.password) throw new Error('Required demo identity missing');
    const login = await call('/auth/login', null, 'POST', { login: email, password: credential.password });
    if (login.refreshToken) sessions.push(login.refreshToken);
    const me = await call('/auth/me', login.accessToken);
    if (String(me.orgId) !== String(org.id) || String(me.userId) !== String(actor.id) || me.role !== role) throw new Error('Identity mismatch');
    actors[role] = actor;
    tokens[role] = login.accessToken;
  }
  const student = await db.student.findFirst({ where: { orgId: org.id, learnerUserId: actors.LEARNER.id, status: 'ACTIVE' } });
  if (student?.programCategory !== 'MADRASA_CHILD') throw new Error('Expected madrasa learner');
  const source = await db.course.findUnique({ where: { orgId_slug: { orgId: org.id, slug: 'afaq-teacher-media-demo' } } });
  if (source?.primaryInstructorUserId !== actors.TEACHER.id) throw new Error('Demo instructor mismatch');
  let course = await db.course.findUnique({ where: { orgId_slug: { orgId: org.id, slug } } });
  if (!course) {
    course = await call('/courses', tokens.ADMIN, 'POST', {
      slug, subjectId: String(source.subjectId), title: 'Shared video lesson (Demo)',
      summary: 'Synthetic silent video for testing teacher-to-learner access. Not assessed learning.',
      programCategory: 'MADRASA_CHILD', visibility: 'FREE', publicationStatus: 'DRAFT',
      primaryInstructorUserId: String(actors.TEACHER.id), isReligious: false,
    });
  }
  if (String(course.primaryInstructorUserId) !== String(actors.TEACHER.id) || course.programCategory !== 'MADRASA_CHILD') throw new Error('Existing demo differs');
  const cid = String(course.id);
  let module = await db.courseModule.findFirst({ where: { orgId: org.id, courseId: BigInt(cid), title: 'Shared media practice' } });
  if (!module) module = await call(`/courses/${cid}/modules`, tokens.TEACHER, 'POST', { title: 'Shared media practice', position: 1 });
  let lesson = await db.courseLesson.findFirst({ where: { orgId: org.id, courseId: BigInt(cid), slug: 'shared-silent-video' } });
  if (!lesson) lesson = await call(`/courses/modules/${module.id}/lessons`, tokens.TEACHER, 'POST', {
    slug: 'shared-silent-video', title: 'Watch the sample video', position: 1,
    contentText: 'Synthetic silent sample only. Opening this video is not an assessment.',
    visibility: 'FREE', publicationStatus: 'DRAFT',
  });
  let asset = await db.mediaAsset.findFirst({ where: { orgId: org.id, lessonId: BigInt(lesson.id), storageKey: 'afaq-demo:video' } });
  if (!asset) asset = await call(`/courses/lessons/${lesson.id}/assets`, tokens.TEACHER, 'POST', {
    assetType: 'VIDEO', storageProvider: 'LOCAL', storageKey: 'afaq-demo:video',
    title: 'Silent sample video', mimeType: 'video/mp4', visibility: 'FREE',
  });
  // Repair only this script's initially locked sample; never change content or progress.
  if (asset.visibility === 'LOCKED') await call(`/courses/assets/${asset.id}`, tokens.ADMIN, 'PATCH', { visibility: 'FREE' });
  if (lesson.visibility === 'LOCKED') await call(`/courses/lessons/${lesson.id}`, tokens.ADMIN, 'PATCH', { visibility: 'FREE' });
  if (course.visibility === 'LOCKED') await call(`/courses/${cid}`, tokens.ADMIN, 'PATCH', { visibility: 'FREE' });
  if (lesson.publicationStatus === 'DRAFT') await call(`/courses/lessons/${lesson.id}`, tokens.ADMIN, 'PATCH', { publicationStatus: 'PUBLISHED' });
  if (course.publicationStatus === 'DRAFT') await call(`/courses/${cid}`, tokens.ADMIN, 'PATCH', { publicationStatus: 'PUBLISHED' });
  await call(`/learner/courses/${cid}`, tokens.LEARNER);
  await call(`/learner/lessons/${lesson.id}`, tokens.LEARNER);
  const opened = await call(`/learner/assets/${asset.id}/open`, tokens.LEARNER);
  const url = new URL(opened.delivery?.inlineUrl, origin);
  if (url.origin !== origin || !url.pathname.startsWith('/api/learner/assets/')) throw new Error('Unexpected delivery URL');
  const video = await fetch(url, { headers: { Range: 'bytes=0-1023' }, redirect: 'error', signal: AbortSignal.timeout(15000) });
  const valid = video.ok && video.headers.get('content-type')?.includes('video/mp4');
  await video.body?.cancel();
  if (!valid) throw new Error('Video delivery failed');
  console.log('PASS: teacher-created sample, admin publication, learner course, lesson and video delivery. FREE sample is available to this madrasa programme. Existing drafts and learner programme preserved.');
} catch {
  console.error(`Shared video demo stopped at ${stage}. No credentials printed. Completed demo steps remain available for retry.`);
  process.exitCode = 1;
} finally {
  for (const refreshToken of sessions) {
    try { await call('/auth/logout', null, 'POST', { refreshToken }); }
    catch { console.error('Demo session cleanup failed.'); process.exitCode = 1; }
  }
  await db?.$disconnect();
}
