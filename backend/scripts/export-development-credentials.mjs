import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { readFile, writeFile, chmod, copyFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { developmentEnvironment } from './development-config.mjs';

let db;
try {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Confirmation required.');
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const directory = join(homedir(), '.afaq/platform-demo');
  const path = join(directory, 'credentials.json');
  const saved = JSON.parse(await readFile(path, 'utf8'));
  const password = saved.find(row => row.role === 'SUPER_ADMIN')?.password;
  if (!password) throw new Error('Saved password required.');
  db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
  const org = await db.organization.findUnique({ where: { code: 'demo-madrasa' } });
  if (!org || org.status !== 'ACTIVE') throw new Error('Active demo organization required.');
  const platforms = await db.platformAccount.findMany({ where: { status: 'ACTIVE' }, orderBy: { email: 'asc' } });
  const users = await db.user.findMany({ where: { orgId: org.id, status: 'ACTIVE' }, orderBy: [{ role: 'asc' }, { email: 'asc' }] });
  const rows = [];
  for (const account of [...platforms, ...users]) {
    if (!await bcrypt.compare(password, account.passwordHash)) throw new Error('Saved password does not match an account.');
    const login = account.familyLoginId || account.email || account.phone;
    if (!login) throw new Error('Login identity missing.');
    if (account.role === 'LEARNER' && !await db.student.count({ where: { orgId: org.id, learnerUserId: account.id } })) {
      throw new Error('Learner has no linked student.');
    }
    rows.push({ email: account.email, login, role: account.role, password,
      ...(account.orgId ? { orgCode: org.code } : {}) });
  }
  const roles = new Set(rows.map(row => row.role));
  if (!['SUPER_ADMIN', 'IT_SECURITY', 'ADMIN', 'ACCOUNTANT', 'TEACHER', 'PARENT', 'LEARNER'].every(role => roles.has(role))) {
    throw new Error('Not all roles have an active demo account.');
  }
  const markdown = new URL('../../LOCAL_CREDENTIALS.md', import.meta.url);
  const backup = join(homedir(), '.afaq/backups', `credentials-directory-${Date.now()}`);
  await mkdir(backup, { recursive: true, mode: 0o700 });
  for (const [source, name] of [[path, 'credentials.json'], [markdown, 'LOCAL_CREDENTIALS.md']]) {
    const target = join(backup, name);
    await copyFile(source, target);
    await chmod(target, 0o600);
  }
  const start = '<!-- DEMO_ACCOUNT_DIRECTORY_START -->';
  const end = '<!-- DEMO_ACCOUNT_DIRECTORY_END -->';
  let text = await readFile(markdown, 'utf8');
  const block = `${start}\n## All active local demo accounts\n\nWeb: http://127.0.0.1:8087/\n\nUse the Login column. School accounts belong to demo-madrasa. Local testing only.\n\n| Role | Login | Password |\n| --- | --- | --- |\n${rows.map(row => `| ${row.role} | ${row.login} | ${row.password} |`).join('\n')}\n${end}`;
  if (text.includes(start) && text.includes(end)) {
    text = text.slice(0, text.indexOf(start)) + block + text.slice(text.indexOf(end) + end.length);
  } else text += `\n\n${block}\n`;
  await writeFile(path, JSON.stringify(rows, null, 2) + '\n', { mode: 0o600 });
  await writeFile(markdown, text, { mode: 0o600 });
  await chmod(path, 0o600);
  await chmod(markdown, 0o600);
  console.log(JSON.stringify({ accounts: rows.length, roles: roles.size, learnerLinksVerified: true, databaseChanged: false }));
} catch {
  console.error('Credential directory export stopped. Check local account configuration; no database records were changed.');
  process.exitCode = 1;
} finally { await db?.$disconnect(); }
