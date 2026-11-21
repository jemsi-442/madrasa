import { PrismaClient } from '@prisma/client';
import { pathToFileURL } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';

export async function prepareErpDemo(db) {
  return db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('Active demo madrasa required.');
    const name = 'Afaq Demo Madrasa';
    if (!['Demo Madrasa', name].includes(org.name)) {
      throw new Error('Existing madrasa name was customised; no changes made.');
    }
    const roles = await tx.user.groupBy({
      by: ['role'], where: { orgId: org.id, status: 'ACTIVE' }, _count: true,
    });
    const missingRoles = ['ADMIN', 'TEACHER', 'ACCOUNTANT', 'PARENT', 'LEARNER']
      .filter(role => !roles.some(row => row.role === role));
    if (missingRoles.length) throw new Error('Required active school roles are missing.');
    const counts = {};
    for (const model of ['class', 'student', 'course', 'classCurriculum',
      'attendanceRecord', 'assessment', 'invoice', 'payment']) {
      counts[model] = await tx[model].count({ where: { orgId: org.id } });
    }
    counts.curriculumAssignments = await tx.curriculumAssignment.count({
      where: { organizationId: org.id },
    });
    counts.linkedLearners = await tx.student.count({
      where: { orgId: org.id, learnerUserId: { not: null } },
    });
    counts.guardianLinks = await tx.studentGuardian.count({ where: { orgId: org.id } });
    const renamed = org.name !== name;
    if (renamed) await tx.organization.update({ where: { id: org.id }, data: { name } });
    return { name, code: org.code, renamed, roles, counts,
      credentialsChanged: false, recordsCreated: 0,
      note: 'Inventory only; validate role workflows in the browser. Counts are not proof of end-to-end readiness.' };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let db;
  try {
    if (process.argv.slice(2).join(' ') !== '--confirm-local-development') {
      throw new Error('Local confirmation required.');
    }
    const env = await developmentEnvironment(new URL('../.env', import.meta.url));
    db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
    console.log(JSON.stringify(await prepareErpDemo(db), null, 2));
  } catch {
    console.error('ERP demo preparation stopped. Check local configuration and existing demo scope; no data was reset.');
    process.exitCode = 1;
  } finally { await db?.$disconnect(); }
}
