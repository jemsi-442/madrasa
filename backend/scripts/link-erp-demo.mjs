import { PrismaClient } from '@prisma/client';
import { pathToFileURL } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';

export async function linkErpDemo(db) {
  return db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('Active demo madrasa required');
    const students = await tx.student.findMany({ where: { orgId: org.id, status: 'ACTIVE',
      learnerUser: { is: { orgId: org.id, role: 'LEARNER', status: 'ACTIVE', email: { endsWith: '.test' } } } },
      select: { id: true, branchId: true, classId: true }, take: 2 });
    if (students.length !== 1) throw new Error('Exactly one test learner required');
    const student = students[0];
    const group = await tx.class.findFirst({ where: { orgId: org.id, branchId: student.branchId,
      name: { startsWith: 'Demo teaching group' },
      ...(student.classId ? { id: student.classId } : {}),
      teacher: { is: { orgId: org.id, role: 'TEACHER', status: 'ACTIVE', email: 'quran.teacher@afaq.test' } } },
      orderBy: { id: 'asc' }, select: { id: true } });
    const guardian = await tx.guardian.findFirst({ where: { orgId: org.id,
      user: { is: { orgId: org.id, role: 'PARENT', status: 'ACTIVE', email: 'parent@afaq.test' } } },
      select: { id: true } });
    if (!group || !guardian) throw new Error('Compatible existing demo class and parent required');
    if (!student.classId) {
      const result = await tx.student.updateMany({ where: { id: student.id, orgId: org.id,
        branchId: student.branchId, classId: null }, data: { classId: group.id } });
      if (result.count !== 1) throw new Error('Class changed concurrently; retry after checking');
    }
    await tx.studentGuardian.upsert({
      where: { studentId_guardianId: { studentId: student.id, guardianId: guardian.id } },
      create: { orgId: org.id, studentId: student.id, guardianId: guardian.id, isPrimary: false },
      update: {},
    });
    return { classLinked: true, parentLinked: true, credentialsChanged: false,
      note: 'Existing class and parent reused. No history, primary guardian or passwords replaced.' };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let db;
  try {
    if (process.argv.slice(2).join(' ') !== '--confirm-local-development') throw new Error('Confirmation required');
    const env = await developmentEnvironment(new URL('../.env', import.meta.url));
    db = new PrismaClient({ datasourceUrl: env.DATABASE_URL, log: [] });
    console.log(JSON.stringify(await linkErpDemo(db), null, 2));
  } catch {
    console.error('Demo linking stopped. Verify the unique test learner and compatible existing demo class/parent.');
    process.exitCode = 1;
  } finally { await db?.$disconnect(); }
}
