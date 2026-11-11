import { randomBytes } from 'node:crypto';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { HttpError } from '../../shared/errors/http-error';
import { assertPlatformPermission } from './platform.permissions';
import type { PlatformContext } from './platform.service';
import { madrasaCourseActivity } from '../learner/madrasa-course-activity';

import { topicInput, publicationContent, curriculumLessonInput } from './curriculum-content';

export const curriculumInput = z.object({
  level: z.string().trim().min(1).max(80).optional(),
  subject: z.string().trim().min(2).max(120),
  version: z.string().trim().regex(/^\d+\.\d+(?:\.\d+)?$/).max(30),
  description: z.string().trim().min(2).max(500),
  objectives: z.array(z.string().trim().min(2).max(1000)).min(1).max(50),
}).strict();
const idSchema = z.string().min(1).max(30);
const oversightMonth = z.string().regex(/^[1-9]\d{3}-(0[1-9]|1[0-2])$/);
const monthRange = (month: string) => ({
  gte: new Date(`${month}-01T00:00:00.000Z`),
  ...(month === '9999-12'
    ? { lte: new Date('9999-12-31T00:00:00.000Z') }
    : { lt: new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5)), 1)) }),
});
const organizationIdSchema = z.string().regex(/^[1-9]\d{0,18}$/)
  .refine(value => BigInt(value) <= 9_223_372_036_854_775_807n);
export const curriculumDecisionInput = z.object({
  action: z.literal('publish'),
  comment: z.string().trim().max(2000).optional(),
  expectedUpdatedAt: z.string().datetime().optional(),
}).strict();

export class PlatformCurriculumService {
  constructor(private readonly db: PrismaClient) {}
  private async authorize(tx: Prisma.TransactionClient, actor: PlatformContext) {
    if (actor.scope !== 'platform') throw new HttpError(401, 'Platform authentication required');
    const user = await tx.platformAccount.findUnique({ where: { id: actor.accountId } });
    if (!user || user.status !== 'ACTIVE') throw new HttpError(403, 'Account is not active');
    assertPlatformPermission(user.role, 'curriculum.manage');
    return user;
  }
  async oversight(actor: PlatformContext, input: unknown) {
    const query = z.object({
      page: z.coerce.number().int().min(1).max(10000).default(1),
      madrasa: z.string().trim().min(1).max(120).optional(),
      subject: z.string().trim().min(1).max(120).optional(),
      level: z.string().trim().min(1).max(80).optional(),
      adoption: z.enum(['with', 'without']).optional(),
      status: z.enum(['ACTIVE', 'TRIAL', 'SUSPENDED', 'PENDING_ACTIVATION']).optional(),
      assessmentMonth: oversightMonth.optional(),
      quranMonth: oversightMonth.optional(),
    }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const rows = await tx.curriculumAssignment.findMany({
        where: {
          ...(query.madrasa || query.status ? { organization: {
            ...(query.madrasa ? { name: { contains: query.madrasa } } : {}),
            ...(query.status ? { status: query.status } : {}),
          } } : {}),
          ...(query.adoption ? { adoptions: query.adoption === 'with' ? { some: {} } : { none: {} } } : {}),
          version: { status: 'PUBLISHED',
            ...(query.subject ? { subject: { contains: query.subject } } : {}),
            ...(query.level ? { level: { contains: query.level } } : {}),
          },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (query.page - 1) * 20, take: 21,
        select: {
          id: true, organizationId: true, versionId: true,
          organization: { select: { name: true, status: true } },
          subject: { select: { isActive: true } },
          version: { select: { subject: true, level: true, version: true, _count: { select: { lessons: true } } } },
          adoptions: { select: { id: true, classId: true, subjectId: true } },
        },
      });
      const visible = rows.slice(0, 20);
      const scopes = visible.filter(row => row.adoptions.length > 0).map(row => ({
        orgId: row.organizationId, assignmentId: row.id,
        classCurriculumId: { in: row.adoptions.map(adoption => adoption.id) },
        lesson: { versionId: row.versionId },
      }));
      const deliveries = scopes.length ? await tx.curriculumLessonDelivery.groupBy({
        by: ['assignmentId', 'classCurriculumId', 'lessonId'], where: { OR: scopes },
      }) : [];
      // Assessments belong to class/subject, not curriculum versions or objectives.
      const assessmentScopes = [...new Map(visible.flatMap(row =>
        row.adoptions.map(adoption => [
          `${row.organizationId}:${adoption.classId}:${adoption.subjectId}`,
          { orgId: row.organizationId, classId: adoption.classId, subjectId: adoption.subjectId },
        ] as const),
      )).values()];
      const publishedScope: Prisma.AssessmentWhereInput = {
        OR: assessmentScopes,
        status: 'PUBLISHED',
        releases: { some: { retractedAt: null } },
        ...(query.assessmentMonth ? { assessedOn: monthRange(query.assessmentMonth) } : {}),
      };
      const publishedAssessments = assessmentScopes.length ? await tx.assessment.count({
        where: publishedScope,
      }) : 0;
      // Published results are locked until retraction; never read editable draft marks.
      // Group by tenant as well as learner and return only the aggregate count.
      const assessedLearners = assessmentScopes.length ? await tx.assessmentResult.groupBy({
        by: ['orgId', 'studentId'],
        where: {
          orgId: { in: [...new Set(assessmentScopes.map(scope => scope.orgId))] },
          score: { not: null },
          assessment: publishedScope,
        },
      }) : [];
      // Quran sessions are class-scoped, not linked to subjects or curriculum versions.
      const quranScopes = [...new Map(assessmentScopes.map(scope => [
        `${scope.orgId}:${scope.classId}`, { orgId: scope.orgId, classId: scope.classId },
      ])).values()];
      const quranGroups = quranScopes.length ? await tx.quranSession.groupBy({
        by: ['activity', 'observation'],
        where: {
          OR: quranScopes, voidedAt: null,
          ...(query.quranMonth ? { learnedOn: monthRange(query.quranMonth) } : {}),
        },
        _count: { _all: true },
      }) : [];
      const learnerScope: Prisma.StudentWhereInput = { status: 'ACTIVE', OR: quranScopes };
      const recordedScope: Prisma.StudentWhereInput = {
        status: 'ACTIVE',
        OR: quranScopes.map(scope => ({ ...scope, quranSessions: { some: {
          ...scope, voidedAt: null,
          ...(query.quranMonth ? { learnedOn: monthRange(query.quranMonth) } : {}),
        } } })),
      };
      const supportScope: Prisma.StudentWhereInput = {
        status: 'ACTIVE',
        OR: quranScopes.map(scope => ({ ...scope, quranSessions: { some: {
          ...scope, voidedAt: null, observation: { in: ['WITH_SUPPORT', 'NEEDS_PRACTICE'] },
          ...(query.quranMonth ? { learnedOn: monthRange(query.quranMonth) } : {}),
        } } })),
      };
      // Count current learners once, even when sessions or framework assignments repeat.
      const eligibleLearners = quranScopes.length ? await tx.student.count({ where: learnerScope }) : 0;
      const recordedLearners = quranScopes.length ? await tx.student.count({ where: recordedScope }) : 0;
      const learnersNeedingSupport = quranScopes.length ? await tx.student.count({ where: supportScope }) : 0;
      const organizationFilter: Prisma.OrganizationWhereInput = {
        ...(query.madrasa ? { name: { contains: query.madrasa } } : {}),
        ...(query.status ? { status: query.status } : {}),
      };
      const institutionLearners: Prisma.StudentWhereInput = {
        status: 'ACTIVE', organization: organizationFilter,
      };
      const institutionSessions: Prisma.QuranSessionWhereInput = {
        voidedAt: null,
        ...(query.quranMonth ? { learnedOn: monthRange(query.quranMonth) } : {}),
      };
      const madrasaCount = await tx.organization.count({ where: organizationFilter });
      const institutionEligible = await tx.student.count({ where: institutionLearners });
      const institutionRecorded = await tx.student.count({ where: {
        ...institutionLearners, quranSessions: { some: institutionSessions },
      } });
      const institutionSupport = await tx.student.count({ where: {
        ...institutionLearners, quranSessions: { some: {
          ...institutionSessions, observation: { in: ['WITH_SUPPORT', 'NEEDS_PRACTICE'] },
        } },
      } });
      return {
        generatedAt: new Date().toISOString(),
        institution: {
          month: query.quranMonth ?? null, madrasas: madrasaCount,
          eligible: institutionEligible, recorded: institutionRecorded,
          unrecorded: institutionEligible - institutionRecorded, needingSupport: institutionSupport,
        },
        quran: {
          month: query.quranMonth ?? null,
          classScopes: quranScopes.length,
          learners: {
            eligible: eligibleLearners, recorded: recordedLearners,
            unrecorded: eligibleLearners - recordedLearners, needingSupport: learnersNeedingSupport,
          },
          activities: ['READING', 'MEMORIZATION', 'REVISION', 'TAJWEED'].map(activity => {
            const groups = quranGroups.filter(group => group.activity === activity);
            const count = (observation: string) =>
              groups.find(group => group.observation === observation)?._count._all ?? 0;
            return {
              activity, sessions: groups.reduce((sum, group) => sum + group._count._all, 0),
              independent: count('INDEPENDENT'), withSupport: count('WITH_SUPPORT'),
              needsPractice: count('NEEDS_PRACTICE'),
            };
          }),
        },
        assessments: {
          month: query.assessmentMonth ?? null,
          classSubjectScopes: assessmentScopes.length,
          publishedAssessments,
          learnersWithPublishedScores: assessedLearners.length,
        },
        page: query.page, hasMore: rows.length > 20,
        items: visible.map(row => {
          const planned = row.adoptions.length * row.version._count.lessons;
          const taught = deliveries.filter(delivery => delivery.assignmentId === row.id).length;
          return {
            id: row.id, madrasa: row.organization.name, madrasaStatus: row.organization.status,
            subject: row.version.subject, level: row.version.level, version: row.version.version,
            subjectActive: row.subject?.isActive ?? null,
            adoptedClasses: row.adoptions.length, plannedClassLessons: planned,
            taughtClassLessons: taught, pendingClassLessons: planned - taught,
          };
        }),
      };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async madrasaOversight(actor: PlatformContext, input: unknown) {
    const query = z.object({
      page: z.coerce.number().int().min(1).max(10000).default(1),
      madrasa: z.string().trim().min(1).max(120).optional(),
      status: z.enum(['ACTIVE', 'TRIAL', 'SUSPENDED', 'PENDING_ACTIVATION']).optional(),
      quranMonth: oversightMonth.optional(),
    }).strict().parse(input);
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const organizations = await tx.organization.findMany({
        where: {
          ...(query.madrasa ? { name: { contains: query.madrasa } } : {}),
          ...(query.status ? { status: query.status } : {}),
        },
        select: { id: true, name: true, status: true },
        orderBy: [{ name: 'asc' }, { id: 'asc' }], skip: (query.page - 1) * 20, take: 21,
      });
      const visible = organizations.slice(0, 20);
      const where: Prisma.StudentWhereInput = { status: 'ACTIVE', orgId: { in: visible.map(row => row.id) } };
      const session: Prisma.QuranSessionWhereInput = {
        voidedAt: null, ...(query.quranMonth ? { learnedOn: monthRange(query.quranMonth) } : {}),
      };
      const count = (filter: Prisma.StudentWhereInput) => visible.length
        ? tx.student.groupBy({ by: ['orgId'], where: filter, _count: { _all: true } })
        : Promise.resolve([]);
      const eligible = await count(where);
      const courseActivity = await madrasaCourseActivity(tx, visible.map(row => row.id));
      const recorded = await count({ ...where, quranSessions: { some: session } });
      const support = await count({ ...where, quranSessions: { some: {
        ...session, observation: { in: ['WITH_SUPPORT', 'NEEDS_PRACTICE'] },
      } } });
      return {
        page: query.page, hasMore: organizations.length > 20, month: query.quranMonth ?? null,
        generatedAt: new Date().toISOString(),
        items: visible.map(org => {
          const total = eligible.find(row => row.orgId === org.id)?._count._all ?? 0;
          const reviewed = recorded.find(row => row.orgId === org.id)?._count._all ?? 0;
          return { id: String(org.id), name: org.name, status: org.status,
            eligible: total, recorded: reviewed, unrecorded: total - reviewed,
            needingSupport: support.find(row => row.orgId === org.id)?._count._all ?? 0,
            courseActivity: {
              period: 'ALL_TIME',
              learners: courseActivity.find(row => row.orgId === org.id)?.learners ?? 0,
              trackedLessons: courseActivity.find(row => row.orgId === org.id)?.trackedLessons ?? 0,
              completedLessons: courseActivity.find(row => row.orgId === org.id)?.completedLessons ?? 0,
            } };
        }),
      };
    }, { isolationLevel: 'RepeatableRead' });
  }

  private async beginDraftEdit(
    tx: Prisma.TransactionClient,
    versionId: string,
    changes: Prisma.CurriculumVersionUpdateManyMutationInput = {},
    expectedUpdatedAt?: string,
  ) {
    const current = await tx.curriculumVersion.findUnique({
      where: { id: versionId }, select: { status: true, updatedAt: true },
    });
    if (!current) throw new HttpError(404, 'Framework not found');
    if (current.status === 'PUBLISHED') throw new HttpError(409, 'Published frameworks cannot be edited; create a new version');
    if (expectedUpdatedAt && Date.parse(expectedUpdatedAt) !== current.updatedAt.getTime()) {
      throw new HttpError(409, 'Framework changed since it was loaded. Refresh and try again');
    }
    const nextUpdatedAt = new Date(Math.max(Date.now(), current.updatedAt.getTime() + 1));
    const changed = await tx.curriculumVersion.updateMany({
      where: { id: versionId, status: { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] }, updatedAt: current.updatedAt },
      data: { ...changes, status: 'DRAFT', reviewedBy: null, updatedAt: nextUpdatedAt },
    });
    if (changed.count !== 1) throw new HttpError(409, 'Framework changed while you were editing. Refresh and try again');
  }
  async list(actor: PlatformContext, input: unknown) {
    const query = z.object({
      page: z.coerce.number().int().min(1).max(100000).default(1),
      review: z.enum(['true']).optional(),
      id: idSchema.optional(),
      q: z.string().trim().min(1).max(120).optional(),
    }).strict().parse(input);
    const where: Prisma.CurriculumVersionWhereInput = {};
    if (query.review) where.status = { in: ['DRAFT', 'IN_REVIEW', 'APPROVED'] };
    if (query.id) where.id = query.id;
    if (query.q) {
      where.OR = [
        { subject: { contains: query.q } },
        { level: { contains: query.q } },
        { description: { contains: query.q } },
        { topics: { some: { title: { contains: query.q } } } },
        { topics: { some: { objectives: { some: { OR: [
          { code: { contains: query.q } },
          { description: { contains: query.q } },
          { criteria: { contains: query.q } },
        ] } } } } },
        { lessons: { some: { OR: [
          { title: { contains: query.q } },
          { activities: { contains: query.q } },
        ] } } },
      ];
    }
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const [items, total, madrasaCount] = await Promise.all([
        tx.curriculumVersion.findMany({
          where,
          take: 24,
          skip: (query.page - 1) * 24,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          include: {
            lessons: {
              orderBy: [{ position: 'asc' }, { id: 'asc' }],
              include: { objectives: { include: { objective: true } } },
            },
            topics: {
              orderBy: [{ position: 'asc' }, { id: 'asc' }],
              include: { objectives: { orderBy: { code: 'asc' } } },
            },
            reviews: {
              orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
              take: 30,
            },
            assignments: {
              select: {
                id: true,
                organizationId: true,
                subjectId: true,
                createdAt: true,
                organization: { select: { name: true, code: true, status: true } },
                subject: { select: { name: true, isActive: true } },
                _count: { select: { adoptions: true } },
              },
            },
            _count: { select: { assignments: true } },
          },
        }),
        tx.curriculumVersion.count({ where }), tx.organization.count({ where: { status: 'ACTIVE' } }),
      ]);
      const accountIds = [...new Set(items.flatMap(item => [
        ...(typeof item.createdBy === 'string' ? [item.createdBy] : []),
        ...(item.reviews ?? []).map(review => review.actorId),
      ]))];
      const accounts = accountIds.length > 0
        ? await tx.platformAccount.findMany({
          where: { id: { in: accountIds } },
          select: { id: true, fullName: true },
        })
        : [];
      const accountNames = new Map(accounts.map(account => [account.id, account.fullName]));
      const displayItems = items.map(item => {
        const { createdBy, reviews, ...version } = item;
        return {
          ...version,
          assignments: (item.assignments ?? []).map(assignment => ({
            ...assignment,
            organizationId: assignment.organizationId.toString(),
            subjectId: assignment.subjectId?.toString() ?? null,
          })),
          createdByName: typeof createdBy === 'string'
            ? accountNames.get(createdBy) ?? null
            : null,
          reviews: (reviews ?? []).map(({ actorId, ...review }) => ({
            ...review,
            actorName: accountNames.get(actorId) ?? null,
          })),
        };
      });
      let cloneInfo: { reason: string; sourceVersionId: string; sourceVersion: { subject: string; level: string; version: string } | null } | null = null;
      if (query.id && items.some(item => item.id === query.id)) {
        const event = await tx.platformAuditEvent.findFirst({ where: {
          entityType: 'CurriculumVersion', entityId: query.id, action: 'curriculum.draft.cloned',
        }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], select: { metadata: true } });
        const metadata = z.object({ sourceVersionId: idSchema, reason: z.string().min(1) })
          .passthrough().safeParse(event?.metadata);
        if (metadata.success) {
          const sourceVersion = await tx.curriculumVersion.findUnique({ where: { id: metadata.data.sourceVersionId },
            select: { subject: true, level: true, version: true } });
          cloneInfo = { ...metadata.data, sourceVersion };
        }
      }
      return { items: displayItems, total, madrasaCount, page: query.page, cloneInfo };
    });
  }
  async assignmentPreview(actor: PlatformContext, rawVersionId: unknown, rawOrganizationId: unknown) {
    const versionId = idSchema.parse(rawVersionId);
    const organizationId = BigInt(organizationIdSchema.parse(rawOrganizationId));
    return this.db.$transaction(async tx => {
      await this.authorize(tx, actor);
      const version = await tx.curriculumVersion.findUnique({
        where: { id: versionId },
        select: { id: true, subject: true, level: true, version: true, status: true },
      });
      if (!version) throw new HttpError(404, 'Framework not found');
      if (version.status !== 'PUBLISHED') throw new HttpError(409, 'Publish this framework before previewing an assignment');
      const school = await tx.organization.findUnique({
        where: { id: organizationId },
        select: {
          id: true, name: true, code: true, status: true,
          branches: { select: { name: true, location: true }, orderBy: { name: 'asc' } },
          subjects: {
            where: { isActive: true },
            select: { id: true, code: true, name: true },
            orderBy: { name: 'asc' },
          },
          _count: { select: { classes: true } },
        },
      });
      if (!school) throw new HttpError(404, 'Madrasa not found');
      if (school.status !== 'ACTIVE') throw new HttpError(422, 'Only active madrasas can receive new curriculum assignments');
      const classLevels = await tx.class.groupBy({
        by: ['level', 'academicYear'],
        where: { orgId: organizationId },
        _count: { _all: true },
        orderBy: [{ level: 'asc' }, { academicYear: 'asc' }],
      });
      const assignment = await tx.curriculumAssignment.findUnique({
        where: { versionId_organizationId: { versionId, organizationId } },
        select: { id: true, subjectId: true, _count: { select: { adoptions: true } } },
      });
      const expectedSubject = version.subject.trim().toLocaleLowerCase();
      return {
        framework: { subject: version.subject, level: version.level, version: version.version },
        madrasa: {
          id: school.id.toString(), name: school.name, code: school.code, status: school.status,
          branches: school.branches.map(branch => ({ name: branch.name, location: branch.location })),
          classCount: school._count.classes,
          classLevels: classLevels.map(group => ({
            level: group.level, academicYear: group.academicYear, classCount: group._count._all,
          })),
          activeSubjects: school.subjects.map(subject => ({
            id: subject.id.toString(), code: subject.code, name: subject.name,
            nameMatchesFramework: subject.name.trim().toLocaleLowerCase() === expectedSubject,
          })),
        },
        existingAssignment: assignment ? {
          id: assignment.id, subjectId: assignment.subjectId?.toString() ?? null,
          classAdoptionCount: assignment._count.adoptions,
        } : null,
        note: 'Subject name matches are suggestions only. A madrasa administrator confirms the local subject and class adoption.',
      };
    });
  }
  async save(actor: PlatformContext, input: unknown) {
    const data = curriculumInput.parse(input);
    try {
      return await this.db.$transaction(async tx => {
        const user = await this.authorize(tx, actor);
        const row = await tx.curriculumVersion.create({ data: { ...data, level: data.level ?? '', createdBy: user.id } });
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.draft.created', entityType: 'CurriculumVersion', entityId: row.id } });
        return row;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new HttpError(409, 'This subject version already exists');
      throw error;
    }
  }
  async transition(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const { action, comment, expectedUpdatedAt } = curriculumDecisionInput.parse(input);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const row = await tx.curriculumVersion.findUnique({ where: { id: versionId }, include: {
        topics: { include: { objectives: true } },
        lessons: {
          select: {
            position: true,
            title: true,
            durationMinutes: true,
            activities: true,
            objectives: {
              select: {
                objective: {
                  select: { topic: { select: { versionId: true } } },
                },
              },
            },
          },
        },
      } });
      if (!row) throw new HttpError(404, 'Framework not found');
      if (expectedUpdatedAt && Date.parse(expectedUpdatedAt) !== row.updatedAt.getTime()) {
        throw new HttpError(409, 'Framework changed since it was loaded. Refresh and try again');
      }
      // Legacy review states remain publishable without an approval step.
      const from = row.status;
      const to = 'PUBLISHED' as const;
      if (from === 'PUBLISHED') throw new HttpError(409, 'This version is already published');
      const lessonsMatchVersion = (row.lessons ?? []).every(lesson => (lesson.objectives ?? []).length > 0
        && lesson.objectives.every(link => link.objective.topic.versionId === versionId));
      if (!publicationContent.safeParse(row).success || !lessonsMatchVersion) {
        throw new HttpError(422, 'Add a level, topics and measurable objectives with assessment criteria; link every lesson to objectives in this framework before publishing');
      }
      curriculumInput.parse({ subject: row.subject, version: row.version,
        description: row.description, objectives: row.objectives });
      const updated = await tx.curriculumVersion.updateMany({ where: { id: versionId, status: from, updatedAt: row.updatedAt },
        data: { status: to,
          reviewedBy: null, publishedAt: new Date(),
        } });
      if (updated.count !== 1) throw new HttpError(409, 'Framework status has changed');
      await tx.curriculumReview.create({ data: {
        versionId, actorId: user.id, action, fromStatus: from, toStatus: to,
        comment: comment || null,
      } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: `curriculum.${action}`, entityType: 'CurriculumVersion', entityId: versionId } });
      return { id: versionId, status: to };
    });
  }
  async clone(actor: PlatformContext, id: unknown, input: unknown) {
    const sourceId = idSchema.parse(id);
    const data = curriculumInput.pick({ version: true }).extend({
      reason: z.string().trim().min(10).max(1000),
    }).strict().parse(input);
    try {
      return await this.db.$transaction(async tx => {
        const user = await this.authorize(tx, actor);
        const source = await tx.curriculumVersion.findUnique({ where: { id: sourceId }, include: { lessons: { include: { objectives: true } }, topics: { include: { objectives: true } } } });
        if (!source || source.status !== 'PUBLISHED') throw new HttpError(409, 'Choose a published version');
        if (data.version === source.version) throw new HttpError(422, 'Choose a different version number');
        const copied = curriculumInput.parse({ subject: source.subject, version: data.version,
          description: source.description, objectives: source.objectives });
        const objectiveIds = new Map(source.topics.flatMap(topic => topic.objectives.map(objective =>
          [objective.id, randomBytes(12).toString('hex')] as const)));
        const draft = await tx.curriculumVersion.create({ data: { ...copied, level: source.level, createdBy: user.id,
          topics: { create: source.topics.map(topic => ({
            title: topic.title, position: topic.position,
            objectives: { create: topic.objectives.map(objective => ({
              id: objectiveIds.get(objective.id)!, code: objective.code, description: objective.description,
              assessmentMethod: objective.assessmentMethod, criteria: objective.criteria,
            })) },
          })) },
        } });
        for (const lesson of source.lessons) {
          const ids = lesson.objectives.map(link => objectiveIds.get(link.objectiveId));
          if (ids.some(id => !id)) throw new HttpError(409, 'Source lesson has an invalid objective link');
          await tx.curriculumLesson.create({ data: {
            versionId: draft.id, title: lesson.title, position: lesson.position,
            durationMinutes: lesson.durationMinutes, activities: lesson.activities,
            objectives: { create: ids.map(id => ({ objectiveId: id! })) },
          } });
        }
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.draft.cloned', entityType: 'CurriculumVersion', entityId: draft.id,
          metadata: { sourceVersionId: sourceId, reason: data.reason } } });
        return draft;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new HttpError(409, 'This subject version already exists');
      throw error;
    }
  }
  async edit(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const { expectedUpdatedAt, ...values } = curriculumInput.omit({ subject: true, version: true })
      .extend({ expectedUpdatedAt: z.string().datetime().optional() }).parse(input);
    const { level, ...data } = values;
    try {
      return await this.db.$transaction(async tx => {
        const user = await this.authorize(tx, actor);
        await this.beginDraftEdit(tx, versionId, { ...data, ...(level === undefined ? {} : { level }) }, expectedUpdatedAt);
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role, action: 'curriculum.draft.updated', entityType: 'CurriculumVersion', entityId: versionId } });
        return { id: versionId };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new HttpError(409, 'This subject version already exists at the selected level');
      }
      throw error;
    }
  }
  async addTopic(actor: PlatformContext, id: unknown, input: unknown, existingId?: unknown) {
    const versionId = idSchema.parse(id);
    const topicId = existingId === undefined ? undefined : idSchema.parse(existingId);
    const parsedInput = z.object({
      expectedUpdatedAt: z.string().datetime().optional(),
    }).passthrough().parse(input);
    const { expectedUpdatedAt, ...topicData } = parsedInput;
    const data = topicInput.parse(topicData);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      // Lock the parent before changing its outline so publication cannot race a content write.
      await this.beginDraftEdit(tx, versionId, {}, expectedUpdatedAt);
      const positionConflict = await tx.curriculumTopic.findFirst({ where: {
        versionId, position: data.position, ...(topicId ? { id: { not: topicId } } : {}),
      }, select: { id: true } });
      if (positionConflict) throw new HttpError(409, 'Another topic already uses this position');
      if (topicId) {
        const existing = await tx.curriculumTopic.findFirst({ where: { id: topicId, versionId } });
        if (!existing) throw new HttpError(404, 'Topic not found in this version');
        await tx.curriculumTopic.update({ where: { id: topicId }, data: { title: data.title, position: data.position } });
        // Preserve IDs of retained objectives. Only unused draft objectives may be removed.
        const linked = await tx.curriculumObjective.count({ where: {
          topicId, code: { notIn: data.objectives.map(o => o.code) }, lessons: { some: {} },
        } });
        if (linked) throw new HttpError(409, 'Remove this objective from lesson plans before changing its code or removing it');
        await tx.curriculumObjective.deleteMany({ where: { topicId, code: { notIn: data.objectives.map(o => o.code) } } });
        for (const objective of data.objectives) {
          await tx.curriculumObjective.upsert({ where: { topicId_code: { topicId, code: objective.code } },
            create: { topicId, ...objective }, update: objective });
        }
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.topic.updated', entityType: 'CurriculumVersion', entityId: versionId,
          metadata: { topicId } } });
        return { id: versionId };
      }
      const topic = await tx.curriculumTopic.create({ data: {
        versionId, title: data.title, position: data.position,
        objectives: { create: data.objectives },
      }, include: { objectives: true } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: 'curriculum.topic.created', entityType: 'CurriculumVersion', entityId: versionId,
        metadata: { topicId: topic.id, objectiveCount: data.objectives.length } } });
      return { id: versionId, topic };
    });
  }
  async saveLesson(actor: PlatformContext, id: unknown, input: unknown, existingId?: unknown) {
    const versionId = idSchema.parse(id);
    const lessonId = existingId === undefined ? undefined : idSchema.parse(existingId);
    const parsedInput = z.object({
      expectedUpdatedAt: z.string().datetime().optional(),
    }).passthrough().parse(input);
    const { expectedUpdatedAt, ...lessonData } = parsedInput;
    const { objectiveIds, ...data } = curriculumLessonInput.parse(lessonData);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      await this.beginDraftEdit(tx, versionId, {}, expectedUpdatedAt);
      const positionConflict = await tx.curriculumLesson.findFirst({ where: {
        versionId, position: data.position, ...(lessonId ? { id: { not: lessonId } } : {}),
      }, select: { id: true } });
      if (positionConflict) throw new HttpError(409, 'Another lesson already uses this position');
      const count = await tx.curriculumObjective.count({ where: { id: { in: objectiveIds }, topic: { versionId } } });
      if (count !== objectiveIds.length) throw new HttpError(422, 'Choose objectives from this framework version');
      if (lessonId) {
        const existing = await tx.curriculumLesson.findFirst({ where: { id: lessonId, versionId } });
        if (!existing) throw new HttpError(404, 'Lesson not found in this version');
        await tx.curriculumLessonObjective.deleteMany({ where: { lessonId } });
        await tx.curriculumLesson.update({ where: { id: lessonId }, data: {
          ...data, objectives: { create: objectiveIds.map(objectiveId => ({ objectiveId })) },
        } });
      } else {
        await tx.curriculumLesson.create({ data: { ...data, versionId,
          objectives: { create: objectiveIds.map(objectiveId => ({ objectiveId })) },
        } });
      }
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: lessonId ? 'curriculum.lesson.updated' : 'curriculum.lesson.created',
        entityType: 'CurriculumVersion', entityId: versionId } });
      return { id: versionId };
    });
  }
  async deleteLesson(actor: PlatformContext, id: unknown, lessonId: unknown, expectedUpdatedAt?: unknown) {
    const versionId = idSchema.parse(id);
    const selectedLessonId = idSchema.parse(lessonId);
    const expected = z.string().datetime().optional().parse(expectedUpdatedAt);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      await this.beginDraftEdit(tx, versionId, {}, expected);
      const lesson = await tx.curriculumLesson.findFirst({ where: { id: selectedLessonId, versionId }, select: { id: true } });
      if (!lesson) throw new HttpError(404, 'Lesson not found in this version');
      await tx.curriculumLessonObjective.deleteMany({ where: { lessonId: lesson.id } });
      await tx.curriculumLesson.delete({ where: { id: lesson.id } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: 'curriculum.lesson.deleted', entityType: 'CurriculumVersion', entityId: versionId,
        metadata: { lessonId: lesson.id } } });
      return { id: versionId };
    });
  }
  async deleteTopic(actor: PlatformContext, id: unknown, topicId: unknown, expectedUpdatedAt?: unknown) {
    const versionId = idSchema.parse(id);
    const selectedTopicId = idSchema.parse(topicId);
    const expected = z.string().datetime().optional().parse(expectedUpdatedAt);
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      await this.beginDraftEdit(tx, versionId, {}, expected);
      const topic = await tx.curriculumTopic.findFirst({ where: { id: selectedTopicId, versionId }, select: { id: true } });
      if (!topic) throw new HttpError(404, 'Topic not found in this version');
      const linkedObjectives = await tx.curriculumLessonObjective.count({ where: { objective: { topicId: topic.id } } });
      if (linkedObjectives > 0) throw new HttpError(409, "Update lesson plans to remove this topic's objectives before deleting the topic");
      await tx.curriculumObjective.deleteMany({ where: { topicId: topic.id } });
      await tx.curriculumTopic.delete({ where: { id: topic.id } });
      await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
        action: 'curriculum.topic.deleted', entityType: 'CurriculumVersion', entityId: versionId,
        metadata: { topicId: topic.id } } });
      return { id: versionId };
    });
  }
  async assign(actor: PlatformContext, id: unknown, input: unknown) {
    const versionId = idSchema.parse(id);
    const parsed = z.union([
      z.object({ organizationId: organizationIdSchema }).strict(),
      z.object({ organizationIds: z.array(organizationIdSchema).min(1).max(100) }).strict()
        .refine(value => new Set(value.organizationIds).size === value.organizationIds.length),
    ]).parse(input);
    const organizationIds = 'organizationId' in parsed ? [parsed.organizationId] : parsed.organizationIds;
    return this.db.$transaction(async tx => {
      const user = await this.authorize(tx, actor);
      const row = await tx.curriculumVersion.findUnique({ where: { id: versionId }, include: { topics: { include: { objectives: true } } } });
      if (!row || row.status !== 'PUBLISHED') throw new HttpError(409, 'Only published versions can be assigned');
      const schoolIds = organizationIds.map(BigInt);
      const schools = await tx.organization.findMany({ where: { id: { in: schoolIds }, status: 'ACTIVE' }, select: { id: true } });
      if (schools.length !== schoolIds.length) throw new HttpError(422, 'Choose only active madrasas');
      const existing = await tx.curriculumAssignment.findMany({
        where: { versionId, organizationId: { in: schoolIds } },
        select: { organizationId: true },
      });
      const existingOrganizationIds = new Set(existing.map(assignment => assignment.organizationId.toString()));
      const assignments = await Promise.all(schools.map(school => tx.curriculumAssignment.upsert({
        where: { versionId_organizationId: { versionId, organizationId: school.id } }, update: {},
        create: { versionId, organizationId: school.id, assignedBy: user.id },
      })));
      const newlyAssignedOrganizationIds = schools
        .map(school => school.id.toString())
        .filter(organizationId => !existingOrganizationIds.has(organizationId));
      if (newlyAssignedOrganizationIds.length > 0) {
        await tx.platformAuditEvent.create({ data: { actorId: user.id, actorRole: user.role,
          action: 'curriculum.assigned', entityType: 'CurriculumVersion', entityId: versionId,
          metadata: { organizationIds: newlyAssignedOrganizationIds } } });
      }
      return { id: versionId, assignments: assignments.map(assignment => ({
        id: assignment.id,
        organizationId: assignment.organizationId.toString(),
      })) };
    });
  }
}
