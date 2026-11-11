import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { prisma } from '../src/shared/db/prisma';
import { madrasaCourseActivity } from '../src/modules/learner/madrasa-course-activity';

it('aggregates real SQL without counting previous accounts or hidden teaching content', async () => {
  const rollback = new Error('Rollback synthetic course activity fixtures');
  await expect(prisma.$transaction(async tx => {
    const org = await tx.organization.create({ data: { name: 'Synthetic tracking test', code: randomUUID() } });
    const other = await tx.organization.create({ data: { name: 'Synthetic other scope', code: randomUUID() } });
    const orgId = org.id;
    const branch = await tx.branch.create({ data: { orgId, name: 'Synthetic branch' } });
    const user = await tx.user.create({ data: { orgId, fullName: 'Synthetic learner', role: 'LEARNER', passwordHash: 'not-a-login' } });
    const former = await tx.user.create({ data: { orgId, fullName: 'Synthetic former account', role: 'LEARNER', passwordHash: 'not-a-login' } });
    const student = await tx.student.create({ data: {
      orgId, branchId: branch.id, fullName: 'Synthetic student', admissionNo: 'SYNTHETIC', learnerUserId: user.id,
    } });
    const subject = await tx.subject.create({ data: { orgId, name: 'Synthetic subject', code: 'SYNTHETIC' } });
    const course = await tx.course.create({ data: {
      orgId, subjectId: subject.id, slug: 'synthetic', title: 'Synthetic course', summary: 'Test only',
      createdByUserId: user.id, publicationStatus: 'PUBLISHED', programCategory: 'MADRASA_CHILD',
    } });
    const module = await tx.courseModule.create({ data: { orgId, courseId: course.id, title: 'Synthetic module', position: 1 } });
    const lessons = [];
    for (let i = 0; i < 4; i++) {
      const lesson = await tx.courseLesson.create({ data: {
        orgId, courseId: course.id, moduleId: module.id, title: `Synthetic lesson ${i}`, slug: `synthetic-${i}`, position: i,
        publicationStatus: i === 2 ? 'DRAFT' : 'PUBLISHED', visibility: i === 3 ? 'UNLISTED' : 'LOCKED',
      } });
      lessons.push(lesson);
      await tx.courseLessonProgress.create({ data: {
        orgId, courseId: course.id, lessonId: lesson.id, studentId: student.id, learnerUserId: user.id,
        progressPercent: i === 1 ? 40 : 100,
      } });
    }
    await tx.courseLessonProgress.create({ data: {
      orgId, courseId: course.id, lessonId: lessons[0]!.id, studentId: student.id, learnerUserId: former.id, progressPercent: 100,
    } });
    const expected = [{ orgId, learners: 1, trackedLessons: 2, completedLessons: 1 }];
    expect(await madrasaCourseActivity(tx, [orgId])).toEqual(expected);
    expect(await madrasaCourseActivity(tx, [other.id])).toEqual([]);
    await tx.student.update({ where: { id: student.id }, data: { status: 'INACTIVE' } });
    expect(await madrasaCourseActivity(tx, [orgId])).toEqual([]);
    await tx.student.update({ where: { id: student.id }, data: { status: 'ACTIVE', programCategory: 'COURSE_STUDENT' } });
    expect(await madrasaCourseActivity(tx, [orgId])).toEqual([]);
    await tx.student.update({ where: { id: student.id }, data: { programCategory: 'MADRASA_CHILD' } });
    await tx.course.update({ where: { id: course.id }, data: { publicationStatus: 'DRAFT' } });
    expect(await madrasaCourseActivity(tx, [orgId])).toEqual([]);
    await tx.course.update({ where: { id: course.id }, data: { publicationStatus: 'PUBLISHED', visibility: 'UNLISTED' } });
    expect(await madrasaCourseActivity(tx, [orgId])).toEqual([]);
    throw rollback;
  }, { timeout: 20000 })).rejects.toBe(rollback);
}, 25000);
