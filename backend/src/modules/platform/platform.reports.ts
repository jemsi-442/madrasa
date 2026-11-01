import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import { tabularReportPdf } from '../../shared/utils/tabular-report-pdf';
import { assertPlatformPermission } from './platform.permissions';
import type { PlatformContext } from './platform.service';

export const institutionReportInput = z.object({
  month: z.string().regex(/^20\d{2}-(0[1-9]|1[0-2])$/),
  organizationId: z.string().regex(/^[1-9]\d{0,18}$/).nullable().default(null),
  sections: z.array(z.enum(['attendance', 'learning', 'donations', 'followups'])).min(1).max(4)
    .refine(value => new Set(value).size === value.length, 'Duplicate section'),
}).strict();
type Input = z.infer<typeof institutionReportInput>;
type Snapshot = Input & { generatedAt: string; scope: string; items: {
  id: string; name: string; code: string; attendance: number | null;
  lessons: number | null; quran: number | null; followups: number | null;
  receipts: { currency: string; amount: string }[] | null; hasData: boolean;
}[] };

export class InstitutionalReportsService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const account = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!account || account.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
    assertPlatformPermission(account.role, 'institution.reports.manage');
  }
  async options(actor: PlatformContext) {
    await this.authorize(this.db, actor);
    const items = await this.db.organization.findMany({ orderBy: [{ name: 'asc' }, { id: 'asc' }],
      select: { id: true, name: true, code: true } });
    return { items: items.map(row => ({ ...row, id: String(row.id) })) };
  }
  private async snapshot(tx: Prisma.TransactionClient, input: Input): Promise<Snapshot> {
    const start = new Date(`${input.month}-01T00:00:00Z`);
    const end = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
    const organizations = await tx.organization.findMany({
      where: { ...(input.organizationId ? { id: BigInt(input.organizationId) } : {}), createdAt: { lt: end } },
      orderBy: [{ name: 'asc' }, { id: 'asc' }], select: { id: true, name: true, code: true },
    });
    if (input.organizationId && !organizations.length) throw new HttpError(404, 'Madrasa not available in this period');
    const orgId = { in: organizations.map(row => row.id) };
    const period = { gte: start, lt: end };
    const has = (section: Input['sections'][number]) => input.sections.includes(section);
    const attendance = has('attendance') ? await tx.attendanceRecord.groupBy({ by: ['orgId'],
      where: { orgId, date: period }, _count: { _all: true } }) : [];
    const lessons = has('learning') ? await tx.curriculumLessonDelivery.groupBy({ by: ['orgId'],
      where: { orgId, taughtAt: period }, _count: { _all: true } }) : [];
    const quran = has('learning') ? await tx.quranSession.groupBy({ by: ['orgId'],
      where: { orgId, learnedOn: period, voidedAt: null }, _count: { _all: true } }) : [];
    // Historical open-at-month-end state, excluding notes resolved before that boundary.
    const followups = has('followups') ? await tx.studentSupportNote.groupBy({ by: ['orgId'],
      where: { orgId, createdAt: { lt: end }, OR: [{ resolvedAt: null }, { resolvedAt: { gte: end } }] },
      _count: { _all: true } }) : [];
    const receipts = has('donations') ? await tx.donation.groupBy({ by: ['orgId', 'currency'],
      where: { orgId, status: 'RECEIVED', receivedAt: period }, _sum: { amount: true } }) : [];
    const counts = (rows: { orgId: bigint; _count: { _all: number } }[], id: bigint) =>
      rows.find(row => row.orgId === id)?._count._all ?? 0;
    return { ...input, generatedAt: new Date().toISOString(),
      scope: input.organizationId ? organizations[0]!.name : 'All registered madrasas',
      items: organizations.map(org => {
        const a = counts(attendance, org.id), l = counts(lessons, org.id), q = counts(quran, org.id), f = counts(followups, org.id);
        const r = receipts.filter(row => row.orgId === org.id);
        return { id: String(org.id), name: org.name, code: org.code,
          attendance: has('attendance') ? a : null, lessons: has('learning') ? l : null,
          quran: has('learning') ? q : null, followups: has('followups') ? f : null,
          receipts: has('donations') ? r.map(row => ({ currency: row.currency, amount: (row._sum.amount ?? new Prisma.Decimal(0)).toFixed(2) })) : null,
          hasData: a + l + q + f > 0 || r.length > 0 };
      }) };
  }
  async preview(actor: PlatformContext, raw: unknown) {
    const input = institutionReportInput.parse(raw);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      return this.snapshot(tx, input);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }
  async generate(actor: PlatformContext, raw: unknown) {
    const { requestId, ...input } = institutionReportInput.extend({ requestId: z.string().uuid() }).parse(raw);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const key = { createdById_requestId: { createdById: actor.accountId, requestId } };
      const previous = await tx.institutionalReport.findUnique({ where: key });
      if (previous) {
        const stored = previous.snapshot as unknown as Snapshot;
        if (stored.month !== input.month || stored.organizationId !== input.organizationId ||
          [...stored.sections].sort().join() !== [...input.sections].sort().join()) {
          throw new HttpError(409, 'Request already used for a different report');
        }
        return { id: previous.id };
      }
      const snapshot = await this.snapshot(tx, input);
      if (!snapshot.items.length) throw new HttpError(422, 'No madrasas available for this period');
      const record = await tx.institutionalReport.create({ data: {
        createdById: actor.accountId, requestId, month: input.month,
        snapshot: snapshot as unknown as Prisma.InputJsonValue,
      } });
      await tx.platformAuditEvent.create({ data: {
        actorId: actor.accountId, actorRole: 'SUPER_ADMIN', action: 'institution.report.generated',
        entityType: 'InstitutionalReport', entityId: record.id,
        metadata: { month: input.month, organizationId: input.organizationId, sections: input.sections },
      } });
      return { id: record.id };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
  async list(actor: PlatformContext, raw: unknown) {
    await this.authorize(this.db, actor);
    const { page } = z.object({ page: z.coerce.number().int().min(1).max(10000).default(1) }).strict().parse(raw);
    const rows = await this.db.institutionalReport.findMany({ orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * 10, take: 11 });
    return { page, hasMore: rows.length > 10, items: rows.slice(0, 10).map(row => ({ id: row.id, month: row.month,
      scope: (row.snapshot as unknown as Snapshot).scope, createdAt: row.createdAt.toISOString(), status: 'Draft' })) };
  }
  async pdf(actor: PlatformContext, id: string) {
    await this.authorize(this.db, actor);
    const row = await this.db.institutionalReport.findUnique({ where: { id: z.string().cuid().parse(id) } });
    if (!row) throw new HttpError(404, 'Report not found');
    const snapshot = row.snapshot as unknown as Snapshot;
    const columns = ['Madrasa', 'Data availability'];
    if (snapshot.sections.includes('attendance')) columns.push('Attendance records');
    if (snapshot.sections.includes('learning')) columns.push('Lessons taught', 'Quran observations');
    if (snapshot.sections.includes('donations')) columns.push('Confirmed receipts');
    if (snapshot.sections.includes('followups')) columns.push('Open support notes');
    const rows = snapshot.items.map(item => {
      const cells = [`${item.name}\n${item.code}`, item.hasData ? 'Records available' : 'No records'];
      if (item.attendance !== null) cells.push(String(item.attendance));
      if (item.lessons !== null) cells.push(String(item.lessons), String(item.quran));
      if (item.receipts !== null) cells.push(item.receipts.map(r => `${r.currency} ${r.amount}`).join('\n') || 'No receipts');
      if (item.followups !== null) cells.push(String(item.followups));
      return cells;
    });
    const weights = [28, 15];
    if (snapshot.sections.includes('attendance')) weights.push(12);
    if (snapshot.sections.includes('learning')) weights.push(10, 12);
    if (snapshot.sections.includes('donations')) weights.push(15);
    if (snapshot.sections.includes('followups')) weights.push(12);
    const period = new Intl.DateTimeFormat('en-GB', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${snapshot.month}-01T00:00:00Z`));
    const generated = new Intl.DateTimeFormat('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'UTC' }).format(new Date(snapshot.generatedAt));
    const pdf = await tabularReportPdf('Institutional report', 'DRAFT  /  Monthly summary', columns, rows, {
      columnWeights: weights,
      metadata: [{ label: 'Reporting period', value: period }, { label: 'Madrasa scope', value: snapshot.scope }, { label: 'Snapshot created', value: `${generated} UTC` }],
      notes: [
        'Data availability shows source records, not formal submission. No records does not mean no activity.',
        'Counts represent records, not unique learners or learning attainment.',
        ...(snapshot.sections.includes('followups') ? ['Support notes are those open at the end of the reporting month.'] : []),
      ],
    });
    return { fileName: `afaq-institution-${snapshot.month}-${row.id}.pdf`, base64: pdf.toString('base64') };
  }
}
