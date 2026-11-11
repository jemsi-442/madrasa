import assert from 'node:assert/strict';
import type { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
import { SchoolCurriculumService } from '../src/modules/learning/school-curriculum';
import { curriculumDemoData } from './curriculum-demo-data';

// One persistent example, using the same authorization and validation as the API.
// Never generate teaching events, learner achievements or Quran passages.
export async function ensureTeacherCurriculumDemo(db: PrismaClient) {
  return db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    assert(org?.status === 'ACTIVE', 'Active demo madrasa required');
    const teacher = await tx.user.findFirst({ where: {
      orgId: org.id, email: 'quran.teacher@afaq.test', role: 'TEACHER', status: 'ACTIVE',
    } });
    const admin = await tx.user.findFirst({ where: {
      orgId: org.id, email: 'schooladmin@afaq.test', role: 'ADMIN', status: 'ACTIVE',
    } });
    assert(teacher?.branchId && admin?.branchId === teacher.branchId, 'Matching demo staff scopes required');
    const classes = await tx.class.findMany({ where: {
      orgId: org.id, name: 'Demo teaching group 1',
    } });
    assert(classes.length === 1, 'One existing demo teaching group required');
    const classroom = classes[0]!;
    assert(classroom.teacherId === teacher.id && classroom.branchId === teacher.branchId,
      'Demo class ownership changed; nothing overwritten');
    const superadmin = await tx.platformAccount.findFirst({ where: {
      email: 'superadmin@afaq.test', role: 'SUPER_ADMIN', status: 'ACTIVE',
    } });
    assert(superadmin, 'Active demo Superadmin required');
    const example = curriculumDemoData.find(row => row.prefix === 'QR1')!;
    const versions = await tx.curriculumVersion.findMany({ where: {
      subject: example.subject, level: example.level, version: '1.0',
    } });
    assert(versions.length <= 1, 'Ambiguous demo framework');
    let version = versions[0];
    if (version) {
      assert(version.status === 'PUBLISHED' && version.description?.includes('DEMO ONLY'),
        'Existing framework needs manual review; nothing overwritten');
    }
    // Keep all service operations in the same transaction as the seed guards.
    const serviceDb = { $transaction: (fn: (client: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
    const platform = new PlatformCurriculumService(serviceDb);
    const school = new SchoolCurriculumService(serviceDb);
    const actor = { scope: 'platform' as const, accountId: superadmin.id, sessionId: 'local-teacher-curriculum-demo' };
    const created = { framework: !version, subject: false, assignment: false, adoption: false };
    if (!version) {
      version = await platform.save(actor, {
        subject: example.subject, level: example.level, version: '1.0',
        description: 'DEMO ONLY: synthetic planning example. Use education-team-checked materials before teaching. No Quran text or assessment results are generated.',
        objectives: example.topics.flatMap(topic => [...topic.skills]),
      });
      for (const [index, topic] of example.topics.entries()) {
        const result = await platform.addTopic(actor, version.id, {
          title: topic.title, position: index + 1,
          objectives: topic.skills.map((description, skill) => ({
            code: `QR1-${index + 1}-${skill + 1}`, description,
            assessmentMethod: topic.method, criteria: topic.criteria[skill],
          })),
        });
        assert(result.topic, 'Demo topic required');
        await platform.saveLesson(actor, version.id, {
          title: `${topic.title} (demo)`, position: index + 1, durationMinutes: 30,
          activities: 'Synthetic plan: discuss the objective, practise with teacher-provided verified materials, then review feedback. Select passages from the verified Quran reader separately; record assessments separately.',
          objectiveIds: result.topic.objectives.map(objective => objective.id),
        });
      }
      await platform.transition(actor, version.id, {
        action: 'publish', comment: 'Publish synthetic demo workflow example, not approved religious teaching material.',
      });
    }
    let assignment = await tx.curriculumAssignment.findUnique({ where: {
      versionId_organizationId: { versionId: version.id, organizationId: org.id },
    } });
    const subjects = await tx.subject.findMany({ where: {
      orgId: org.id,
      ...(assignment?.subjectId ? { id: assignment.subjectId } : {
        OR: [{ name: example.subject }, { name: "Qur'an" }, { code: 'DEMO-QR' }],
      }),
    } });
    assert(subjects.length <= 1, 'Ambiguous subject mapping; choose it manually');
    let subject = subjects[0];
    if (subject) assert(subject.isActive, 'Existing subject is inactive; nothing overwritten');
    else {
      assert(!assignment?.subjectId, 'Mapped subject unavailable');
      subject = await tx.subject.create({ data: { orgId: org.id, name: example.subject, code: 'DEMO-QR' } });
      created.subject = true;
    }
    const adoption = await tx.classCurriculum.findUnique({ where: {
      classId_subjectId: { classId: classroom.id, subjectId: subject.id },
    } });
    assert(!adoption || adoption.assignmentId === assignment?.id,
      'Existing class curriculum differs; nothing overwritten');
    if (!assignment) {
      await platform.assign(actor, version.id, { organizationId: String(org.id) });
      assignment = await tx.curriculumAssignment.findUniqueOrThrow({ where: {
        versionId_organizationId: { versionId: version.id, organizationId: org.id },
      } });
      created.assignment = true;
    }
    if (!adoption) {
      await school.adopt({ userId: String(admin.id), orgId: String(org.id), branchId: String(admin.branchId), role: 'ADMIN' }, {
        assignmentId: assignment.id, classId: String(classroom.id), subjectId: String(subject.id),
      });
      created.adoption = true;
    }
    return { created, subject: example.subject, className: classroom.name };
  }, { isolationLevel: 'Serializable', timeout: 30000 });
}
