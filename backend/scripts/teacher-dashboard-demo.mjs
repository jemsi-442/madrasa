import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { QuranActivity, LearningObservation } from '@prisma/client';

export function demoEventId(key) {
  const hash = createHash('sha256').update(`afaq-teacher-dashboard-v1:${key}`).digest('hex');
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-5${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
}

export async function ensureTeacherDashboardDemo(db, now = new Date()) {
  const date = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Dar_es_Salaam',
    year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
  const catalog = JSON.parse(await readFile(new URL('../src/modules/teacher-workspace/quran-catalog.json', import.meta.url), 'utf8'));
  const chapter = catalog.chapters.find(row => row.id === 1);
  if (!chapter || chapter.ayahCount !== 7) throw new Error('Verified Quran metadata required');
  return db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('Active demo organization required');
    const teacher = await tx.user.findFirst({ where: { orgId: org.id,
      email: 'quran.teacher@afaq.test', role: 'TEACHER', status: 'ACTIVE' } });
    const admin = await tx.user.findFirst({ where: { orgId: org.id,
      email: 'schooladmin@afaq.test', role: 'ADMIN', status: 'ACTIVE' } });
    if (!teacher?.branchId || !admin) throw new Error('Existing demo teacher and school admin required');
    const subject = await tx.subject.findFirst({ where: { orgId: org.id }, orderBy: { id: 'asc' } });
    if (!subject) throw new Error('Existing subject required');
    const created = { classes: 0, learners: 0, timetable: 0, attendance: 0, quran: 0, followUps: 0 };
    for (let group = 1; group <= 3; group++) {
      const name = `Demo teaching group ${group}`;
      const matches = await tx.class.findMany({ where: { orgId: org.id, name } });
      if (matches.length > 1) throw new Error('Ambiguous demo class');
      let schoolClass = matches[0];
      if (schoolClass && (schoolClass.teacherId !== teacher.id || schoolClass.branchId !== teacher.branchId)) {
        throw new Error('Demo class assignment changed; nothing overwritten');
      }
      if (!schoolClass) {
        schoolClass = await tx.class.create({ data: { orgId: org.id, branchId: teacher.branchId,
          teacherId: teacher.id, name, level: `Demo level ${group}`, academicYear: date.slice(0, 4), capacity: 12 } });
        created.classes++;
      }
      // Fixed slots are created once. Cancelled or edited schedules are not restored.
      for (let weekday = 1; weekday <= 5; weekday++) {
        const focus = `DEMO-DASHBOARD-${group}-${weekday}: synthetic practice only`;
        const existing = await tx.classTimetableSlot.findFirst({ where: {
          orgId: org.id, classId: schoolClass.id, weekday,
        } });
        if (!existing) {
          await tx.classTimetableSlot.create({ data: { orgId: org.id, classId: schoolClass.id,
            weekday, startsAt: `${8 + group}:00`.padStart(5, '0'), endsAt: `${8 + group}:45`.padStart(5, '0'),
            validFrom: new Date(`${date.slice(0, 4)}-01-01`), validUntil: new Date(`${Number(date.slice(0, 4)) + 1}-12-31`),
            subject: subject.name, focus, room: `Demo room ${group}`, createdById: admin.id } });
          created.timetable++;
        }
      }
      for (let index = 1; index <= 6; index++) {
        const admissionNo = `DEMO-DASH-${group}-${index}`;
        let learner = await tx.student.findUnique({ where: { orgId_admissionNo: { orgId: org.id, admissionNo } } });
        if (learner && (learner.classId !== schoolClass.id || learner.branchId !== teacher.branchId || learner.status !== 'ACTIVE')) {
          throw new Error('Demo learner scope/status changed; nothing overwritten');
        }
        if (!learner) {
          learner = await tx.student.create({ data: { orgId: org.id, branchId: teacher.branchId,
            classId: schoolClass.id, admissionNo, fullName: `Demo Learner ${group}-${index}`,
            notes: 'SYNTHETIC DEMO ONLY. Not a real child record.' } });
          created.learners++;
        }
        // One stable seed attendance entry per learner, not a new entry on every startup/day.
        const marker = `DEMO-DASHBOARD attendance ${admissionNo}`;
        const attendance = await tx.attendanceRecord.findFirst({ where: { orgId: org.id, studentId: learner.id } });
        if (!attendance) {
          await tx.attendanceRecord.create({ data: { orgId: org.id, branchId: teacher.branchId,
            classId: schoolClass.id, studentId: learner.id, date: new Date(date),
            status: index === 6 ? 'ABSENT' : 'PRESENT', reason: marker, markedById: teacher.id } });
          created.attendance++;
        }
        const clientId = demoEventId(`quran:${admissionNo}`);
        if (!await tx.quranSession.findUnique({ where: { orgId_teacherId_clientId: { orgId: org.id, teacherId: teacher.id, clientId } } })) {
          const input = { clientId, studentId: String(learner.id), classId: String(schoolClass.id),
            surahId: chapter.id, ayahFrom: 1, ayahTo: chapter.ayahCount,
            activity: QuranActivity.READING, observation: index <= 2 ? LearningObservation.NEEDS_PRACTICE : LearningObservation.INDEPENDENT,
            learnedOn: date, note: 'Synthetic demo observation, not an actual learner assessment.' };
          await tx.quranSession.create({ data: { ...input, orgId: org.id, teacherId: teacher.id,
            classId: schoolClass.id, studentId: learner.id, learnedOn: new Date(date),
            requestHash: createHash('sha256').update(JSON.stringify(input)).digest('hex') } });
          created.quran++;
        }
        if (index <= 2) {
          const clientId = demoEventId(`support:${admissionNo}`);
          if (!await tx.studentSupportNote.findUnique({ where: { orgId_createdById_clientId: { orgId: org.id, createdById: teacher.id, clientId } } })) {
            await tx.studentSupportNote.create({ data: { orgId: org.id, studentId: learner.id,
              classId: schoolClass.id, createdById: teacher.id, clientId,
              note: 'Demo follow-up: plan a short supported practice session. Synthetic learner only.' } });
            created.followUps++;
          }
        }
      }
    }
    if (Object.values(created).some(count => count > 0)) {
      await tx.auditLog.create({ data: { orgId: org.id, actorUserId: admin.id,
        action: 'demo.teacher-dashboard.prepared', entityType: 'User', entityId: String(teacher.id),
        metadata: { synthetic: true, created } } });
    }
    return { created };
  }, { isolationLevel: 'Serializable', timeout: 30000 });
}
