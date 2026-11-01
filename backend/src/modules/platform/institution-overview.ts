import type { Prisma } from '@prisma/client';

export async function institutionOverview(tx: Prisma.TransactionClient, now = new Date()) {
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  const period = { gte: start, lt: end };
  const [madrasas, learners, teachers, rows, lessons, quran, receipts, pledges, followups] = await Promise.all([
    tx.organization.count(), tx.student.count(),
    tx.user.count({ where: { role: 'TEACHER', status: 'ACTIVE' } }),
    tx.organization.findMany({ take: 6, orderBy: [{ name: 'asc' }, { id: 'asc' }],
      select: { id: true, name: true, code: true, status: true,
        _count: { select: { students: true, users: { where: { role: 'TEACHER', status: 'ACTIVE' } } } } } }),
    tx.curriculumLessonDelivery.groupBy({ by: ['orgId'], where: { taughtAt: period }, _count: { _all: true } }),
    tx.quranSession.groupBy({ by: ['orgId'], where: { learnedOn: period, voidedAt: null }, _count: { _all: true } }),
    tx.donation.groupBy({ by: ['currency'], where: { status: 'RECEIVED', receivedAt: period }, _sum: { amount: true } }),
    tx.donationPledge.groupBy({ by: ['currency'], where: { dueOn: period }, _sum: { amount: true } }),
    tx.studentSupportNote.count({ where: { resolvedAt: null } }),
  ]);
  const recorded = new Set([...lessons, ...quran].map(row => String(row.orgId)));
  return {
    month: start.toISOString().slice(0, 7),
    summary: { madrasas, learners, teachers, withLearningRecords: recorded.size, openSupportNotes: followups,
      lessonsTaught: lessons.reduce((sum, row) => sum + row._count._all, 0),
      quranObservations: quran.reduce((sum, row) => sum + row._count._all, 0) },
    madrasas: rows.map(row => ({ id: String(row.id), name: row.name, code: row.code, status: row.status,
      learners: row._count.students, teachers: row._count.users, hasLearningRecords: recorded.has(String(row.id)) })),
    receipts: receipts.map(row => ({ currency: row.currency, amount: row._sum.amount?.toString() ?? '0' })),
    pledges: pledges.map(row => ({ currency: row.currency, amount: row._sum.amount?.toString() ?? '0' })),
  };
}
