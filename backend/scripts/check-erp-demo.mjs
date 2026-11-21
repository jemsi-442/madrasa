import { PrismaClient } from '@prisma/client';
import { pathToFileURL } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';

export async function checkErpDemo(db) {
  const org = await db.organization.findUnique({
    where: { code: 'demo-madrasa' }, select: { id: true, status: true },
  });
  if (!org || org.status !== 'ACTIVE') throw new Error('Active demo madrasa required.');
  const account = role => ({ orgId: org.id, role, status: 'ACTIVE' });
  const learner = { orgId: org.id, status: 'ACTIVE',
    learnerUser: { is: account('LEARNER') } };
  const teacher = { currentClass: { is: { orgId: org.id,
    teacher: { is: account('TEACHER') } } } };
  const parent = { guardians: { some: { orgId: org.id,
    guardian: { is: { orgId: org.id, user: { is: account('PARENT') } } } } } };
  const linkedLearners = await db.student.count({ where: learner });
  const withTeacher = await db.student.count({ where: { ...learner, ...teacher } });
  const withParent = await db.student.count({ where: { ...learner, ...parent } });
  const shared = { ...learner, ...teacher, ...parent };
  const sharedLearners = await db.student.count({ where: shared });
  const withInvoice = await db.student.count({ where: { ...shared,
    invoices: { some: { orgId: org.id } } } });
  const admins = await db.user.count({ where: account('ADMIN') });
  const accountants = await db.user.count({ where: account('ACCOUNTANT') });
  return { linkedLearners, withTeacher, withParent, sharedLearners, withInvoice,
    admins, accountants,
    relationshipReady: sharedLearners > 0 && admins > 0 && accountants > 0,
    note: 'Read-only relationship check, not proof of API permissions, published results or payment processing.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let db;
  try {
    const env = await developmentEnvironment(new URL('../.env', import.meta.url));
    db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
    const result = await checkErpDemo(db);
    console.log(JSON.stringify(result, null, 2));
    if (!result.relationshipReady) process.exitCode = 1;
  } catch {
    console.error('ERP relationship check could not complete. No records or credentials were changed.');
    process.exitCode = 1;
  } finally { await db?.$disconnect(); }
}
