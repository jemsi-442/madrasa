import { randomBytes, randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, describe, expect, it } from "vitest";
import { SchoolCurriculumService } from "../src/modules/learning/school-curriculum";
import { PlatformCurriculumService } from "../src/modules/platform/platform.curriculum";
import { classManagementRecord, manageClass } from "../src/modules/admin-panel/class-management";

const enabled = process.env.PLATFORM_STAGING_RUN === "isolated";
if (enabled && !/^mysql:\/\/root@127\.0\.0\.1:\d+\/afaq_platform_staging_[a-f0-9]+$/.test(process.env.DATABASE_URL ?? "")) {
  throw new Error("Refusing curriculum integration tests outside the isolated runner database");
}

describe.skipIf(!enabled)("real isolated curriculum workflow", () => {
  const db = new PrismaClient({ log: [] });
  afterAll(async () => { await db.$disconnect(); });

  it("assigns, adopts, upgrades and retains the previous class version", async () => {
    const suffix = randomBytes(6).toString("hex");
    let organizationId: bigint | undefined;
    let accountId: string | undefined;
    let userId: bigint | undefined;
    const versionIds: string[] = [];

    try {
      const organization = await db.organization.create({ data: {
        name: `Curriculum staging ${suffix}`,
        code: `curriculum-${suffix}`,
      } });
      organizationId = organization.id;
      const branch = await db.branch.create({ data: {
        orgId: organization.id,
        name: "Main",
        isMain: true,
      } });
      const admin = await db.user.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        fullName: "Curriculum Staging Admin",
        passwordHash: "test-only-not-a-login-credential",
        role: "ADMIN",
      } });
      userId = admin.id;
      const subject = await db.subject.create({ data: {
        orgId: organization.id,
        code: `AR-${suffix}`,
        name: "Arabic language",
      } });
      const classroom = await db.class.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        name: "Level One",
        level: "Level 1",
        academicYear: "2026",
      } });
      const account = await db.platformAccount.create({ data: {
        email: `curriculum-${suffix}@example.test`,
        fullName: "Curriculum Staging Super Admin",
        passwordHash: "test-only-not-a-login-credential",
        role: "SUPER_ADMIN",
        status: "ACTIVE",
      } });
      accountId = account.id;

      const platform = new PlatformCurriculumService(db);
      const platformActor = { scope: "platform" as const, accountId: account.id, sessionId: `staging-${suffix}` };
      const incomplete = await platform.save(platformActor, {
        subject: "Arabic",
        level: "Level 1",
        version: "0.9",
        description: "Incomplete staging draft that must remain unpublished",
        objectives: ["Learner demonstrates the target skill"],
      });
      versionIds.push(incomplete.id);
      await expect(platform.transition(platformActor, incomplete.id, { action: "publish" }))
        .rejects.toMatchObject({ statusCode: 422 });
      expect((await db.curriculumVersion.findUniqueOrThrow({ where: { id: incomplete.id } })).status).toBe("DRAFT");

      const legacyDraft = await platform.save(platformActor, {
        subject: "Arabic",
        level: "Level 1",
        version: "0.8",
        description: "Legacy draft with invalid topic ordering",
        objectives: ["Learner demonstrates the target skill"],
      });
      versionIds.push(legacyDraft.id);
      await db.curriculumTopic.create({ data: {
        versionId: legacyDraft.id,
        title: "Legacy topic",
        position: 0,
        objectives: { create: {
          code: "LEGACY-1",
          description: "Identify the foundational Arabic letter sounds",
          assessmentMethod: "ORAL",
          criteria: "Correctly identify at least four of five sounds",
        } },
      } });
      await expect(platform.transition(platformActor, legacyDraft.id, { action: "publish" }))
        .rejects.toMatchObject({ statusCode: 422 });
      expect((await db.curriculumVersion.findUniqueOrThrow({ where: { id: legacyDraft.id } })).status).toBe("DRAFT");

      const concurrentDraft = await platform.save(platformActor, {
        subject: "Arabic",
        level: "Level 1",
        version: "0.7",
        description: "Disposable concurrent-edit integration fixture",
        objectives: ["Learner demonstrates the target skill"],
      });
      versionIds.push(concurrentDraft.id);
      const concurrentEdits = await Promise.allSettled([
        platform.edit(platformActor, concurrentDraft.id, {
          description: "First concurrent edit is saved",
          objectives: ["Learner demonstrates the target skill"],
        }),
        platform.edit(platformActor, concurrentDraft.id, {
          description: "Second concurrent edit must conflict",
          objectives: ["Learner demonstrates the target skill"],
        }),
      ]);
      expect(concurrentEdits.filter(result => result.status === "fulfilled")).toHaveLength(1);
      expect(concurrentEdits.filter(result => result.status === "rejected")).toHaveLength(1);
      const concurrentResult = await db.curriculumVersion.findUniqueOrThrow({ where: { id: concurrentDraft.id } });
      expect(concurrentResult.description).toMatch(/^(First|Second) concurrent edit/);

      const publishReadyVersion = async (version: string) => {
        const draft = await platform.save(platformActor, {
          subject: "Arabic",
          level: "Level 1",
          version,
          description: "Disposable curriculum integration fixture",
          objectives: ["Learner demonstrates the target skill"],
        });
        versionIds.push(draft.id);
        const firstTopic = await platform.addTopic(platformActor, draft.id, {
          title: "Foundations",
          position: 1,
          objectives: [{
            code: "FOUND-1",
            description: "Identify the foundational Arabic letter sounds",
            assessmentMethod: "ORAL",
            criteria: "Correctly identify at least four of five sounds",
          }],
        });
        const secondTopic = await platform.addTopic(platformActor, draft.id, {
          title: "Practice",
          position: 2,
          objectives: [{
            code: "PRACT-1",
            description: "Read a short Arabic word with correct pronunciation",
            assessmentMethod: "PRACTICAL",
            criteria: "Read four of five words with correct pronunciation",
          }],
        });
        if (!firstTopic.topic || !secondTopic.topic) {
          throw new Error("New staging topics were not returned");
        }
        const objectiveIds = [
          firstTopic.topic.objectives[0]!.id,
          secondTopic.topic.objectives[0]!.id,
        ];
        const removableTopic = await platform.addTopic(platformActor, draft.id, {
          title: "Temporary topic",
          position: 3,
          objectives: [{
            code: "TEMP-1",
            description: "Demonstrate a temporary skill before removal",
            assessmentMethod: "OBSERVATION",
            criteria: "Complete the temporary practice task correctly",
          }],
        });
        const removableObjectiveId = removableTopic.topic!.objectives[0]!.id;
        const removableLesson = await platform.saveLesson(platformActor, draft.id, {
          title: "Temporary lesson",
          position: 2,
          durationMinutes: 15,
          activities: "Practise the temporary skill before removing the draft topic.",
          objectiveIds: [removableObjectiveId],
        });
        const temporaryLesson = await db.curriculumLesson.findFirstOrThrow({
          where: { versionId: draft.id, title: "Temporary lesson" },
          select: { id: true },
        });
        await expect(platform.deleteTopic(platformActor, draft.id, removableTopic.topic!.id))
          .rejects.toMatchObject({ statusCode: 409 });
        await platform.deleteLesson(platformActor, draft.id, temporaryLesson.id);
        await platform.deleteTopic(platformActor, draft.id, removableTopic.topic!.id);
        expect(removableLesson.id).toBe(draft.id);
        await platform.saveLesson(platformActor, draft.id, {
          title: "Listen and practise",
          position: 1,
          durationMinutes: 30,
          activities: "Listen to the teacher, then practise reading in pairs.",
          objectiveIds,
        });
        const originalObjective = firstTopic.topic.objectives[0]!;
        await platform.addTopic(platformActor, draft.id, {
          title: "Foundations",
          position: 1,
          objectives: [{
            code: originalObjective.code,
            description: "Identify foundational Arabic sounds accurately",
            assessmentMethod: "ORAL",
            criteria: "Correctly identify at least four of five sounds",
          }],
        }, firstTopic.topic.id);
        const retainedObjective = await db.curriculumObjective.findUniqueOrThrow({
          where: { id: originalObjective.id },
        });
        expect(retainedObjective.description).toBe("Identify foundational Arabic sounds accurately");
        const linkedLesson = await db.curriculumLesson.findFirstOrThrow({
          where: { versionId: draft.id, title: "Listen and practise" },
          include: { objectives: true },
        });
        expect(linkedLesson.objectives.map(link => link.objectiveId)).toEqual(objectiveIds);
        const beforeRejectedEdit = await db.curriculumVersion.findUniqueOrThrow({
          where: { id: draft.id },
        });
        await expect(platform.addTopic(platformActor, draft.id, {
          title: "Rejected replacement title",
          expectedUpdatedAt: beforeRejectedEdit.updatedAt.toISOString(),
          position: 1,
          objectives: [{
            code: "FOUND-RENAMED",
            description: "Identify foundational Arabic sounds accurately",
            assessmentMethod: "ORAL",
            criteria: "Correctly identify at least four of five sounds",
          }],
        }, firstTopic.topic.id))
          .rejects.toMatchObject({ statusCode: 409 });
        expect((await db.curriculumVersion.findUniqueOrThrow({
          where: { id: draft.id },
        })).updatedAt).toEqual(beforeRejectedEdit.updatedAt);
        expect((await db.curriculumTopic.findUniqueOrThrow({
          where: { id: firstTopic.topic.id },
        })).title).toBe("Foundations");
        expect(await db.curriculumLessonObjective.findMany({
          where: { lessonId: linkedLesson.id }, orderBy: { objectiveId: "asc" },
        })).toEqual([...linkedLesson.objectives].sort((a, b) => a.objectiveId.localeCompare(b.objectiveId)));
        expect((await db.curriculumObjective.findUniqueOrThrow({
          where: { id: originalObjective.id },
        })).code).toBe(originalObjective.code);
        // A rolled-back failure must not invalidate the retained form's token.
        await platform.addTopic(platformActor, draft.id, {
          expectedUpdatedAt: beforeRejectedEdit.updatedAt.toISOString(),
          title: "Foundations",
          position: 1,
          objectives: [{
            code: originalObjective.code,
            description: retainedObjective.description,
            assessmentMethod: "ORAL",
            criteria: "Correctly identify at least four of five sounds",
          }],
        }, firstTopic.topic.id);
        const beforeLessonEdit = await db.curriculumVersion.findUniqueOrThrow({
          where: { id: draft.id },
        });
        const foreignObjective = await db.curriculumObjective.findFirstOrThrow({
          where: { topic: { versionId: legacyDraft.id } },
        });
        const lessonSnapshot = await db.curriculumLesson.findUniqueOrThrow({
          where: { id: linkedLesson.id },
          include: { objectives: { orderBy: { objectiveId: "asc" } } },
        });
        const auditFilter = { entityId: draft.id, action: "curriculum.lesson.updated" };
        const auditCount = await db.platformAuditEvent.count({ where: auditFilter });
        const lessonEdit = {
          expectedUpdatedAt: beforeLessonEdit.updatedAt.toISOString(),
          title: "Listen and practise",
          position: 1,
          durationMinutes: 35,
          activities: "Listen to the teacher, then practise reading in pairs.",
          objectiveIds,
        };
        await expect(platform.saveLesson(platformActor, draft.id, {
          ...lessonEdit,
          title: "Rejected lesson replacement",
          objectiveIds: [objectiveIds[0], foreignObjective.id],
        }, linkedLesson.id)).rejects.toMatchObject({ statusCode: 422 });
        expect(await db.curriculumLesson.findUniqueOrThrow({
          where: { id: linkedLesson.id },
          include: { objectives: { orderBy: { objectiveId: "asc" } } },
        })).toEqual(lessonSnapshot);
        expect((await db.curriculumVersion.findUniqueOrThrow({
          where: { id: draft.id },
        })).updatedAt).toEqual(beforeLessonEdit.updatedAt);
        expect(await db.platformAuditEvent.count({ where: auditFilter })).toBe(auditCount);
        await platform.saveLesson(platformActor, draft.id, lessonEdit, linkedLesson.id);
        expect((await db.curriculumLesson.findUniqueOrThrow({
          where: { id: linkedLesson.id },
        })).durationMinutes).toBe(35);
        expect(await db.platformAuditEvent.count({ where: auditFilter })).toBe(auditCount + 1);
        await db.curriculumVersion.update({
          where: { id: draft.id },
          data: { status: "IN_REVIEW" },
        });
        const legacyReview = await db.curriculumReview.create({ data: {
          versionId: draft.id,
          actorId: account.id,
          action: "submit",
          fromStatus: "DRAFT",
          toStatus: "IN_REVIEW",
          comment: "Legacy review history retained for compatibility.",
        } });
        const published = await platform.transition(platformActor, draft.id, { action: "publish" });
        expect(published.status).toBe("PUBLISHED");
        const publicationHistory = await db.curriculumReview.findMany({
          where: { versionId: draft.id },
          orderBy: { createdAt: "asc" },
        });
        expect(publicationHistory).toEqual(expect.arrayContaining([
          expect.objectContaining({
            id: legacyReview.id,
            action: "submit",
            fromStatus: "DRAFT",
            toStatus: "IN_REVIEW",
          }),
          expect.objectContaining({
            action: "publish",
            fromStatus: "IN_REVIEW",
            toStatus: "PUBLISHED",
          }),
        ]));
        const content = await db.curriculumVersion.findUniqueOrThrow({
          where: { id: draft.id },
          include: { lessons: { include: { objectives: true } } },
        });
        expect(content.status).toBe("PUBLISHED");
        expect(content.lessons[0]!.objectives.map(link => link.objectiveId).sort()).toEqual([...objectiveIds].sort());
        return draft;
      };
      const first = await publishReadyVersion("1.0");
      const next = await platform.clone(platformActor, first.id, {
        version: "2.0",
        reason: "Add a revised practice sequence for the next release",
      });
      versionIds.push(next.id);
      const versionDetail = await platform.list(platformActor, { id: next.id });
      expect(versionDetail.cloneInfo).toMatchObject({
        sourceVersionId: first.id,
        reason: "Add a revised practice sequence for the next release",
        sourceVersion: { subject: "Arabic", version: "1.0" },
      });
      const [sourceContent, clonedDraft] = await Promise.all([
        db.curriculumVersion.findUniqueOrThrow({
          where: { id: first.id },
          include: { topics: { include: { objectives: true } }, lessons: { include: { objectives: true } } },
        }),
        db.curriculumVersion.findUniqueOrThrow({
          where: { id: next.id },
          include: { topics: { include: { objectives: true } }, lessons: { include: { objectives: true } } },
        }),
      ]);
      const sourceObjectiveIds = sourceContent.topics.flatMap(topic => topic.objectives.map(objective => objective.id));
      const clonedObjectiveIds = clonedDraft.topics.flatMap(topic => topic.objectives.map(objective => objective.id));
      expect(clonedDraft.status).toBe("DRAFT");
      expect(clonedObjectiveIds).toHaveLength(sourceObjectiveIds.length);
      expect(clonedObjectiveIds.some(id => sourceObjectiveIds.includes(id))).toBe(false);
      expect(clonedDraft.lessons[0]!.objectives.map(link => link.objectiveId).sort()).toEqual([...clonedObjectiveIds].sort());
      await expect(platform.saveLesson(platformActor, next.id, {
        title: "Cross-version objective link",
        position: 99,
        durationMinutes: 20,
        activities: "This lesson must not reference an objective from another version.",
        objectiveIds: [sourceObjectiveIds[0]!],
      })).rejects.toMatchObject({ statusCode: 422 });
      expect(await db.curriculumLesson.findFirst({ where: {
        versionId: next.id,
        title: "Cross-version objective link",
      } })).toBeNull();
      await expect(platform.edit(platformActor, first.id, {
        level: "Level 1",
        description: "Attempted post-publication edit",
        objectives: ["Learner demonstrates the target skill"],
      })).rejects.toMatchObject({ statusCode: 409 });
      await expect(platform.addTopic(platformActor, first.id, {
        title: "Late topic",
        position: 3,
        objectives: [{
          code: "LATE-1",
          description: "A topic that must not be added after publication",
          assessmentMethod: "ORAL",
          criteria: "Correctly demonstrate the required skill",
        }],
      })).rejects.toMatchObject({ statusCode: 409 });
      await expect(platform.saveLesson(platformActor, first.id, {
        title: "Late lesson",
        position: 2,
        durationMinutes: 20,
        activities: "This lesson must not change a published version.",
        objectiveIds: [sourceObjectiveIds[0]!],
      })).rejects.toMatchObject({ statusCode: 409 });
      const unchanged = await db.curriculumVersion.findUniqueOrThrow({
        where: { id: first.id },
        include: { topics: true, lessons: true },
      });
      expect(unchanged.description).toBe("Disposable curriculum integration fixture");
      expect(unchanged.topics).toHaveLength(2);
      expect(unchanged.lessons).toHaveLength(1);
      const publishedClone = await platform.transition(platformActor, next.id, { action: "publish" });
      expect(publishedClone.status).toBe("PUBLISHED");
      const topicSearch = await platform.list(platformActor, { q: "Foundations" });
      expect(topicSearch.items.map(row => row.id)).toEqual(expect.arrayContaining([first.id, next.id]));
      const objectiveSearch = await platform.list(platformActor, { q: "four of five sounds" });
      expect(objectiveSearch.items.map(row => row.id)).toEqual(expect.arrayContaining([first.id, next.id]));
      const lessonSearch = await platform.list(platformActor, { q: "practise reading in pairs" });
      expect(lessonSearch.items.map(row => row.id)).toContain(first.id);
      const firstAssignment = await platform.assign(platformActor, first.id, {
        organizationId: organization.id.toString(),
      });
      const school = new SchoolCurriculumService(db);
      const assignedTeacher = await db.user.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        fullName: "Assigned Curriculum Teacher",
        passwordHash: "test-only-not-a-login-credential",
        role: "TEACHER",
      } });
      await db.class.update({ where: { id: classroom.id }, data: { teacherId: assignedTeacher.id } });
      const teacherActor = {
        userId: assignedTeacher.id.toString(),
        orgId: organization.id.toString(),
        role: "TEACHER" as const,
        branchId: branch.id.toString(),
      };
      // Availability to the madrasa alone must not imply classroom adoption.
      expect((await school.list(teacherActor)).assignments).toEqual([]);
      const schoolActor = {
        userId: admin.id.toString(),
        orgId: organization.id.toString(),
        role: "ADMIN" as const,
        branchId: branch.id.toString(),
      };
      await school.adopt(schoolActor, {
        assignmentId: firstAssignment.assignments[0]!.id,
        classId: classroom.id.toString(),
        subjectId: subject.id.toString(),
      });
      const firstTeacherView = await school.list(teacherActor);
      expect(firstTeacherView.assignments).toHaveLength(1);
      expect(firstTeacherView.assignments[0].version).toMatchObject({ version: "1.0" });
      expect(firstTeacherView.assignments[0].version.lessons).toHaveLength(1);
      expect(firstTeacherView.assignments[0].version.topics).toHaveLength(2);
      const deliveryInput = {
        classCurriculumId: firstTeacherView.assignments[0].adoptions[0].id,
        assignmentId: firstAssignment.assignments[0]!.id,
        lessonId: sourceContent.lessons[0]!.id,
        clientEventId: randomUUID(),
      };
      await expect(school.recordDelivery(schoolActor, deliveryInput)).rejects.toMatchObject({ statusCode: 403 });
      await expect(school.recordDelivery(teacherActor, {
        ...deliveryInput, lessonId: clonedDraft.lessons[0]!.id,
      })).rejects.toMatchObject({ statusCode: 422 });
      expect(await db.curriculumLessonDelivery.count({ where: { orgId: organization.id } })).toBe(0);
      const delivery = await school.recordDelivery(teacherActor, deliveryInput);
      expect(await school.recordDelivery(teacherActor, deliveryInput)).toEqual(delivery);
      expect(await db.curriculumLessonDelivery.count({ where: { orgId: organization.id } })).toBe(1);
      await expect(school.recordDelivery(teacherActor, {
        ...deliveryInput, lessonId: clonedDraft.lessons[0]!.id,
      })).rejects.toMatchObject({ statusCode: 409 });
      expect(await db.auditLog.count({ where: {
        orgId: organization.id, action: "curriculum.lesson.taught",
      } })).toBe(1);

      const assignmentPreview = await platform.assignmentPreview(
        platformActor,
        next.id,
        organization.id.toString(),
      );
      expect(assignmentPreview).toMatchObject({
        framework: { subject: "Arabic", level: "Level 1", version: "2.0" },
        madrasa: {
          id: organization.id.toString(),
          status: "ACTIVE",
          classCount: 1,
          classLevels: [{ level: "Level 1", academicYear: "2026", classCount: 1 }],
          activeSubjects: [{ name: "Arabic language", nameMatchesFramework: false }],
        },
        existingAssignment: null,
      });
      expect(await db.curriculumAssignment.count({ where: {
        versionId: next.id,
        organizationId,
      } })).toBe(0);

      const nextAssignment = await platform.assign(platformActor, next.id, {
        organizationId: organization.id.toString(),
      });
      expect((await school.list(teacherActor)).assignments.map((row: { id: string }) => row.id))
        .toEqual([firstAssignment.assignments[0]!.id]);
      await expect(school.adopt(teacherActor, {
        assignmentId: nextAssignment.assignments[0]!.id,
        classId: classroom.id.toString(),
        subjectId: subject.id.toString(),
      })).rejects.toMatchObject({ statusCode: 403 });
      await school.adopt(schoolActor, {
        assignmentId: nextAssignment.assignments[0]!.id,
        classId: classroom.id.toString(),
        subjectId: subject.id.toString(),
      });

      const alternativeSubject = await db.subject.create({ data: {
        orgId: organization.id,
        code: `ALT-${suffix}`,
        name: "Arabic studies",
      } });
      const raceClass = await db.class.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        name: "Concurrent mapping level",
        level: "Level 3",
        academicYear: "2026",
      } });
      const raceVersion = await publishReadyVersion("3.0");
      const raceAssignment = await platform.assign(platformActor, raceVersion.id, {
        organizationId: organization.id.toString(),
      });
      const competingAdoptions = await Promise.allSettled([
        school.adopt(schoolActor, {
          assignmentId: raceAssignment.assignments[0]!.id,
          classId: raceClass.id.toString(),
          subjectId: subject.id.toString(),
        }),
        school.adopt(schoolActor, {
          assignmentId: raceAssignment.assignments[0]!.id,
          classId: raceClass.id.toString(),
          subjectId: alternativeSubject.id.toString(),
        }),
      ]);
      expect(competingAdoptions.filter(result => result.status === "fulfilled")).toHaveLength(1);
      expect(competingAdoptions.filter(result => result.status === "rejected")).toHaveLength(1);
      const mappedRaceAssignment = await db.curriculumAssignment.findUniqueOrThrow({
        where: { id: raceAssignment.assignments[0]!.id },
      });
      expect([subject.id, alternativeSubject.id]).toContain(mappedRaceAssignment.subjectId);
      expect(await db.classCurriculum.count({ where: {
        assignmentId: raceAssignment.assignments[0]!.id,
      } })).toBe(1);

      const otherTeacher = await db.user.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        fullName: "Unassigned Curriculum Teacher",
        passwordHash: "test-only-not-a-login-credential",
        role: "TEACHER",
      } });
      await db.class.update({ where: { id: classroom.id }, data: { teacherId: assignedTeacher.id } });
      await db.class.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        name: "Other Teacher Level",
        level: "Level 2",
        academicYear: "2026",
        teacherId: otherTeacher.id,
      } });
      const assignedTeacherView = await school.list({
        userId: assignedTeacher.id.toString(),
        orgId: organization.id.toString(),
        role: "TEACHER",
        branchId: branch.id.toString(),
      });
      expect(assignedTeacherView.classes.map((row: { name: string }) => row.name)).toEqual(["Level One"]);
      expect(assignedTeacherView.assignments.map((row: { id: string }) => row.id)).toEqual([nextAssignment.assignments[0]!.id]);
      expect(assignedTeacherView.assignments[0].adoptions[0].history[0].previousAssignment.version.version).toBe("1.0");
      expect(await school.recordDelivery(teacherActor, deliveryInput)).toEqual(delivery);
      await expect(school.recordDelivery(teacherActor, {
        ...deliveryInput, clientEventId: randomUUID(),
      })).rejects.toMatchObject({ statusCode: 409 });
      const savedDelivery = await db.curriculumLessonDelivery.findUniqueOrThrow({ where: { id: delivery.id } });
      expect(savedDelivery.assignmentId).toBe(firstAssignment.assignments[0]!.id);
      expect(savedDelivery.lessonId).toBe(sourceContent.lessons[0]!.id);
      for (const actor of [schoolActor, teacherActor]) {
        const teachingHistory = await school.deliveryHistory(actor, { classCurriculumId: deliveryInput.classCurriculumId });
        expect(teachingHistory.items).toHaveLength(1);
        expect(teachingHistory.items[0]).toMatchObject({
          id: delivery.id,
          assignment: { version: { version: '1.0' } },
          teacher: { fullName: 'Assigned Curriculum Teacher' },
        });
        expect(teachingHistory.items[0]).not.toHaveProperty('clientEventId');
        expect(teachingHistory.hasMore).toBe(false);
        expect(teachingHistory.teachingCoverage).toEqual({ version: '2.0', taughtLessons: 0, totalLessons: 1 });
        expect(teachingHistory.pendingLessons).toEqual([{ id: clonedDraft.lessons[0]!.id, title: clonedDraft.lessons[0]!.title }]);
        expect(teachingHistory).toMatchObject({ pendingPage: 1, pendingHasMore: false });
        const emptyPendingPage = await school.deliveryHistory(actor, { classCurriculumId: deliveryInput.classCurriculumId, pendingPage: 2 });
        expect(emptyPendingPage.pendingLessons).toEqual([]);
        expect(emptyPendingPage.items).toEqual(teachingHistory.items);
      }
      await expect(school.deliveryHistory({ ...teacherActor, userId: otherTeacher.id.toString() }, {
        classCurriculumId: deliveryInput.classCurriculumId,
      })).rejects.toMatchObject({ statusCode: 404 });
      for (let repetition = 0; repetition < 2; repetition++) {
        await school.recordDelivery(teacherActor, {
          ...deliveryInput,
          assignmentId: nextAssignment.assignments[0]!.id,
          lessonId: clonedDraft.lessons[0]!.id,
          clientEventId: randomUUID(),
        });
      }
      const repeatedTeaching = await school.deliveryHistory(teacherActor, { classCurriculumId: deliveryInput.classCurriculumId });
      expect(repeatedTeaching.items).toHaveLength(3);
      expect(repeatedTeaching.teachingCoverage).toEqual({ version: '2.0', taughtLessons: 1, totalLessons: 1 });
      expect(repeatedTeaching.pendingLessons).toEqual([]);
      const teachingList = await school.list(teacherActor);
      expect(teachingList.assignments[0].adoptions[0].teachingCoverage).toEqual(repeatedTeaching.teachingCoverage);
      const assessmentLearners = await Promise.all([1, 2, 3].map(index =>
        db.student.create({ data: {
          orgId: organization.id, branchId: branch.id, classId: classroom.id,
          admissionNo: `SYN-ASSESS-${index}-${suffix}`,
          fullName: `Synthetic Assessment Learner ${index}`,
        } }),
      ));
      for (const kind of ['draft', 'published', 'published-again', 'retracted', 'other-subject']) {
        const assessment = await db.assessment.create({ data: {
          orgId: organization.id, classId: classroom.id,
          subjectId: kind === 'other-subject' ? alternativeSubject.id : subject.id,
          createdById: assignedTeacher.id, clientId: randomUUID(),
          title: `Synthetic oversight ${kind}`, assessedOn: new Date('2026-10-01'),
          maxScore: 10,
          status: kind === 'draft' ? 'DRAFT' : 'PUBLISHED',
        } });
        const roster = kind.startsWith('published')
          ? assessmentLearners.slice(0, 2) : assessmentLearners.slice(2);
        await db.assessmentResult.createMany({ data: roster.map((student, index) => ({
          orgId: organization.id, assessmentId: assessment.id,
          studentId: student.id, score: index === 0 ? 0 : 5, feedback: '',
        })) });
        if (kind !== 'draft') {
          for (const revision of [1, 2]) {
            await db.assessmentRelease.create({ data: {
              orgId: organization.id, assessmentId: assessment.id, revision,
              publishedById: admin.id, snapshot: { synthetic: true },
              retractedAt: kind === 'retracted' ? new Date() : null,
            } });
          }
        }
      }
      const oversight = await platform.oversight(platformActor, { madrasa: organization.name, subject: 'Arabic' });
      expect(oversight.assessments).toEqual({
        classSubjectScopes: 2, publishedAssessments: 2, learnersWithPublishedScores: 2,
      });
      expect(JSON.stringify(oversight)).not.toContain('Synthetic Assessment Learner');
      expect(JSON.stringify(oversight)).not.toContain('studentId');
      expect(oversight.items.find(row => row.id === nextAssignment.assignments[0]!.id)).toMatchObject({
        adoptedClasses: 1, plannedClassLessons: 1, taughtClassLessons: 1, pendingClassLessons: 0,
      });
      expect(oversight.items.find(row => row.id === firstAssignment.assignments[0]!.id)).toMatchObject({
        adoptedClasses: 0, plannedClassLessons: 0, taughtClassLessons: 0,
      });
      const adoptedReport = await platform.oversight(platformActor, { madrasa: organization.name, adoption: 'with' });
      expect(adoptedReport.items.map(row => row.id)).toContain(nextAssignment.assignments[0]!.id);
      expect(adoptedReport.items.map(row => row.id)).not.toContain(firstAssignment.assignments[0]!.id);
      const unadoptedReport = await platform.oversight(platformActor, { madrasa: organization.name, adoption: 'without' });
      expect(unadoptedReport.items.map(row => row.id)).toContain(firstAssignment.assignments[0]!.id);
      expect(unadoptedReport.items.map(row => row.id)).not.toContain(nextAssignment.assignments[0]!.id);
      const statusReport = await platform.oversight(platformActor, { madrasa: organization.name, status: organization.status, adoption: 'with' });
      expect(statusReport.items.map(row => row.id)).toContain(nextAssignment.assignments[0]!.id);
      const otherStatusReport = await platform.oversight(platformActor, { madrasa: organization.name, status: 'SUSPENDED' });
      expect(otherStatusReport.items).toEqual([]);
      await expect(school.recordDelivery({ ...teacherActor, userId: otherTeacher.id.toString() }, {
        ...deliveryInput, clientEventId: randomUUID(),
      })).rejects.toMatchObject({ statusCode: 404 });
      expect(await db.curriculumVersion.findUniqueOrThrow({
        where: { id: first.id },
        include: { topics: { include: { objectives: true } }, lessons: { include: { objectives: true } } },
      })).toEqual(sourceContent);
      const otherTeacherView = await school.list({
        userId: otherTeacher.id.toString(),
        orgId: organization.id.toString(),
        role: "TEACHER",
        branchId: branch.id.toString(),
      });
      expect(otherTeacherView.classes.map((row: { name: string }) => row.name)).toEqual(["Other Teacher Level"]);
      expect(otherTeacherView.assignments).toEqual([]);

      const current = await db.classCurriculum.findUniqueOrThrow({
        where: { classId_subjectId: { classId: classroom.id, subjectId: subject.id } },
        include: { history: { include: { previousAssignment: { include: { version: true } } } } },
      });
      const mapped = await db.curriculumAssignment.findUniqueOrThrow({ where: {
        versionId_organizationId: { versionId: next.id, organizationId: organization.id },
      } });

      expect(current.assignmentId).toBe(nextAssignment.assignments[0]!.id);
      expect(current.history).toHaveLength(1);
      expect(current.history[0]!.previousAssignment.version.version).toBe("1.0");
      expect(mapped.subjectId).toBe(subject.id);
      const classActor = {
        userId: admin.id.toString(),
        orgId: organization.id.toString(),
        role: "ADMIN" as const,
        branchId: branch.id.toString(),
      };
      const classRecord = await classManagementRecord(classActor, classroom.id.toString());
      expect(classRecord._count).toMatchObject({ curricula: 1, curriculumHistory: 1 });
      expect(classRecord.canRemove).toBe(false);
      await expect(manageClass(classActor, classroom.id.toString(), "remove", {
        revision: classRecord.revision,
        reason: "Preserve curriculum adoption history",
      })).rejects.toMatchObject({ statusCode: 409 });
      expect(await db.platformAuditEvent.count({ where: {
        actorId: account.id,
        action: "curriculum.assigned",
      } })).toBe(3);
      expect(await db.auditLog.count({ where: {
        orgId: organization.id,
        actorUserId: admin.id,
        action: "curriculum.class.version_changed",
      } })).toBe(1);

      const activeMadrasaCount = (await platform.list(platformActor, {
        id: next.id,
      })).madrasaCount;
      await db.organization.update({
        where: { id: organization.id },
        data: { status: "TRIAL" },
      });
      const trialView = await school.list(schoolActor);
      const trialAssignment = trialView.assignments.find(
        (row: { id: string }) => row.id === nextAssignment.assignments[0]!.id,
      );
      expect(trialAssignment?.adoptions).toHaveLength(1);
      const trialClass = await db.class.create({ data: {
        orgId: organization.id,
        branchId: branch.id,
        name: "Trial Curriculum Level",
        level: "Level 3",
        academicYear: "2026",
      } });
      await expect(school.adopt(schoolActor, {
        assignmentId: nextAssignment.assignments[0]!.id,
        classId: trialClass.id.toString(),
        subjectId: subject.id.toString(),
      })).resolves.toMatchObject({ assignmentId: nextAssignment.assignments[0]!.id });
      await expect(platform.assign(platformActor, next.id, {
        organizationId: organization.id.toString(),
      })).rejects.toMatchObject({ statusCode: 422 });

      await db.organization.update({
        where: { id: organization.id },
        data: { status: "SUSPENDED" },
      });
      const platformView = await platform.list(platformActor, { id: next.id });
      expect(platformView.items[0]!.assignments[0]!.organization.status).toBe("SUSPENDED");
      expect(platformView.madrasaCount).toBe(activeMadrasaCount - 1);
      await expect(school.list(schoolActor)).rejects.toMatchObject({ statusCode: 403 });
      await expect(school.adopt(schoolActor, {
        assignmentId: nextAssignment.assignments[0]!.id,
        classId: classroom.id.toString(),
        subjectId: subject.id.toString(),
      })).rejects.toMatchObject({ statusCode: 403 });
      await expect(platform.assign(platformActor, next.id, {
        organizationId: organization.id.toString(),
      })).rejects.toMatchObject({ statusCode: 422 });
      expect(await db.curriculumAssignment.count({ where: { versionId: next.id } })).toBe(1);
      await db.organization.update({
        where: { id: organization.id },
        data: { status: "ACTIVE" },
      });
      const restoredView = await school.list(schoolActor);
      const restoredAssignment = restoredView.assignments.find(
        (row: { id: string }) => row.id === nextAssignment.assignments[0]!.id,
      );
      expect(restoredAssignment?.adoptions).toHaveLength(2);
      const restoredOriginalClass = restoredAssignment?.adoptions.find(
        (adoption: { class: { name: string } }) => adoption.class.name === "Level One",
      );
      expect(restoredOriginalClass?.history).toHaveLength(1);
      await expect(school.adopt(schoolActor, {
        assignmentId: nextAssignment.assignments[0]!.id,
        classId: classroom.id.toString(),
        subjectId: subject.id.toString(),
      })).resolves.toMatchObject({ assignmentId: nextAssignment.assignments[0]!.id });
    } finally {
      if (organizationId !== undefined) {
        await db.assessmentRelease.deleteMany({ where: { orgId: organizationId } });
        await db.assessmentResult.deleteMany({ where: { orgId: organizationId } });
        await db.assessment.deleteMany({ where: { orgId: organizationId } });
        await db.student.deleteMany({ where: { orgId: organizationId } });
        await db.curriculumLessonDelivery.deleteMany({ where: { orgId: organizationId } });
        await db.classCurriculumHistory.deleteMany({ where: { orgId: organizationId } });
        await db.classCurriculum.deleteMany({ where: { orgId: organizationId } });
        await db.curriculumAssignment.deleteMany({ where: { organizationId } });
        await db.auditLog.deleteMany({ where: { orgId: organizationId } });
        await db.class.deleteMany({ where: { orgId: organizationId } });
        await db.subject.deleteMany({ where: { orgId: organizationId } });
        await db.user.deleteMany({ where: { orgId: organizationId } });
        await db.branch.deleteMany({ where: { orgId: organizationId } });
        await db.organization.delete({ where: { id: organizationId } });
      }
      if (accountId !== undefined) {
        await db.platformAuditEvent.deleteMany({ where: { actorId: accountId } });
      }
      if (versionIds.length) {
        const versions = { versionId: { in: versionIds } };
        await db.curriculumLessonObjective.deleteMany({ where: { lesson: versions } });
        await db.curriculumLesson.deleteMany({ where: versions });
        await db.curriculumObjective.deleteMany({ where: { topic: versions } });
        await db.curriculumTopic.deleteMany({ where: versions });
        await db.curriculumReview.deleteMany({ where: { versionId: { in: versionIds } } });
        await db.curriculumVersion.deleteMany({ where: { id: { in: versionIds } } });
      }
      if (accountId !== undefined) await db.platformAccount.delete({ where: { id: accountId } });
    }
  }, 20_000);
});
