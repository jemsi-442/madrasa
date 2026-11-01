import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { readFile, writeFile, mkdir, copyFile, chmod } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { developmentEnvironment, validateDevelopment } from './development-config.mjs';

export async function resetDevelopmentPasswords(db, env, password) {
  validateDevelopment(env);
  if (typeof password !== 'string' || password.length < 12 || Buffer.byteLength(password) > 72) {
    throw new Error('Provide a development password of 12 to 72 bytes.');
  }
  const passwordHash = await bcrypt.hash(password, 12);
  return db.$transaction(async tx => {
    const platform = await tx.platformAccount.updateMany({ data: { passwordHash } });
    const users = await tx.user.updateMany({ data: { passwordHash, authVersion: { increment: 1 } } });
    // Pending registrations must not later restore an older password.
    const applications = await tx.familyApplication.updateMany({
      where: { passwordHash: { not: null } }, data: { passwordHash },
    });
    const revokedAt = new Date();
    await tx.platformSession.updateMany({ where: { revokedAt: null }, data: { revokedAt } });
    await tx.refreshToken.updateMany({ where: { revokedAt: null }, data: { revokedAt } });
    return { platform: platform.count, users: users.count, applications: applications.count };
  });
}

async function main() {
  if (process.argv.slice(2).join(' ') !== '--confirm-local-development') {
    throw new Error('Explicit local development confirmation required.');
  }
  const env = await developmentEnvironment(new URL('../.env', import.meta.url));
  const password = process.env.DEVELOPMENT_LOGIN_PASSWORD;
  if (!password) throw new Error('DEVELOPMENT_LOGIN_PASSWORD is required.');
  const directory = join(homedir(), '.afaq/platform-demo');
  const files = ['credentials.json', 'teacher-credentials.json'];
  const oldPasswords = new Set();
  const updates = [];
  for (const name of files) {
    const path = join(directory, name);
    const data = JSON.parse(await readFile(path, 'utf8'));
    for (const row of Array.isArray(data) ? data : [data]) {
      if (typeof row.password !== 'string' || !row.password) throw new Error('Invalid credentials file.');
      oldPasswords.add(row.password);
      row.password = password;
    }
    updates.push({ path, name, content: JSON.stringify(data, null, 2) + '\n' });
  }
  const markdown = new URL('../../LOCAL_CREDENTIALS.md', import.meta.url);
  let content = await readFile(markdown, 'utf8');
  for (const old of oldPasswords) content = content.split(old).join(password);
  updates.push({ path: markdown, name: 'LOCAL_CREDENTIALS.md', content });
  const backup = join(homedir(), '.afaq/backups', `login-passwords-${Date.now()}`);
  await mkdir(backup, { recursive: true, mode: 0o700 });
  for (const file of updates) {
    const destination = join(backup, file.name);
    await copyFile(file.path, destination);
    await chmod(destination, 0o600);
  }
  const db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
  try {
    const counts = await resetDevelopmentPasswords(db, env, password);
    for (const file of updates) {
      await writeFile(file.path, file.content, { mode: 0o600 });
      await chmod(file.path, 0o600);
    }
    for (const model of [db.platformAccount, db.user]) {
      for (const row of await model.findMany({ select: { passwordHash: true } })) {
        if (!await bcrypt.compare(password, row.passwordHash)) throw new Error('Password verification failed.');
      }
    }
    console.log(JSON.stringify({ verified: true, ...counts, credentialsFilesUpdated: updates.length }));
  } finally { await db.$disconnect(); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => {
    console.error('Local password update did not finish. Check local configuration and credential files before retrying.');
    process.exitCode = 1;
  });
}
